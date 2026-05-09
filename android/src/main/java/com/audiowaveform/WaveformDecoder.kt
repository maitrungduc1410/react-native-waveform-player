package com.audiowaveform

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

/**
 * Decode an audio file into per-bar RMS amplitudes for waveform visualisation.
 *
 * Uses `MediaExtractor` + `MediaCodec` for hardware-accelerated PCM decode.
 * `MediaExtractor` handles `http(s)://` URLs natively (it follows redirects),
 * so no manual download is needed.
 *
 * Bucket-by-presentation-time (rather than sequential) for time-accurate bars
 * even with VBR audio. Emits intermediate progress (5% then every 20%) so
 * the waveform paints in as it decodes.
 *
 * All callbacks fire on the main thread.
 */
class WaveformDecoder {

    interface Listener {
        fun onProgress(amplitudes: FloatArray) {}
        fun onComplete(amplitudes: FloatArray)
        fun onFailure(message: String)
    }

    private val cancelFlag = AtomicBoolean(false)
    private var workerThread: Thread? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun decode(uri: String, barCount: Int, listener: Listener) {
        cancel()
        if (barCount <= 0) {
            mainHandler.post { listener.onComplete(FloatArray(0)) }
            return
        }
        cancelFlag.set(false)
        val token = cancelFlag
        val thread = Thread({
            try {
                runDecode(uri, barCount, token, listener)
            } catch (e: Exception) {
                Log.e(TAG, "decode crashed", e)
                if (!token.get()) {
                    mainHandler.post { listener.onFailure(e.message ?: "Decode failed") }
                }
            }
        }, "audiowaveform-decode")
        workerThread = thread
        thread.isDaemon = true
        thread.start()
    }

    /** Cancel any in-flight decode. Safe to call repeatedly. */
    fun cancel() {
        cancelFlag.set(true)
        workerThread = null
    }

    private fun runDecode(
        uri: String,
        barCount: Int,
        cancelled: AtomicBoolean,
        listener: Listener
    ) {
        val extractor = MediaExtractor()
        try {
            try {
                if (uri.startsWith("http://") || uri.startsWith("https://")) {
                    extractor.setDataSource(uri, HashMap())
                } else {
                    extractor.setDataSource(uri)
                }
            } catch (e: Exception) {
                if (!cancelled.get()) {
                    mainHandler.post {
                        listener.onFailure("setDataSource failed: ${e.message}")
                    }
                }
                return
            }

            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }
            if (audioTrackIndex < 0 || audioFormat == null) {
                if (!cancelled.get()) {
                    mainHandler.post { listener.onFailure("No audio track found") }
                }
                return
            }

            extractor.selectTrack(audioTrackIndex)
            extractor.seekTo(0L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: run {
                mainHandler.post { listener.onFailure("Audio mime type missing") }
                return
            }
            val codec: MediaCodec = try {
                MediaCodec.createDecoderByType(mime)
            } catch (e: Exception) {
                mainHandler.post { listener.onFailure("Codec creation failed: ${e.message}") }
                return
            }

            try {
                codec.configure(audioFormat, null, null, 0)
                codec.start()

                val durationUs = if (audioFormat.containsKey(MediaFormat.KEY_DURATION)) {
                    audioFormat.getLong(MediaFormat.KEY_DURATION)
                } else 0L
                val totalDurationUs = if (durationUs > 0) durationUs else 60_000_000L
                val barDurationUs = totalDurationUs.toDouble() / barCount

                val sumSquares = DoubleArray(barCount)
                val sampleCounts = IntArray(barCount)
                val bufferInfo = MediaCodec.BufferInfo()
                var inputDone = false
                var outputDone = false
                val timeoutUs = 10_000L
                var highestFilledBar = -1
                val firstUpdateThreshold = (barCount / 20).coerceAtLeast(1)
                val regularUpdateInterval = (barCount / 5).coerceAtLeast(1)
                var lastUpdateBar = -1

                while (!outputDone) {
                    if (cancelled.get()) {
                        return
                    }
                    if (!inputDone) {
                        val inputIndex = codec.dequeueInputBuffer(timeoutUs)
                        if (inputIndex >= 0) {
                            val inputBuffer = codec.getInputBuffer(inputIndex) ?: continue
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(
                                    inputIndex, 0, sampleSize, extractor.sampleTime, 0
                                )
                                extractor.advance()
                            }
                        }
                    }

                    val outputIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                    if (outputIndex >= 0) {
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                        val outputBuffer = codec.getOutputBuffer(outputIndex)
                        if (outputBuffer != null && bufferInfo.size > 0) {
                            val barIndex = ((bufferInfo.presentationTimeUs / barDurationUs).toInt())
                                .coerceIn(0, barCount - 1)

                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            val shortCount = bufferInfo.size / 2
                            for (i in 0 until shortCount) {
                                val sample = outputBuffer.short.toFloat() / Short.MAX_VALUE.toFloat()
                                sumSquares[barIndex] += (sample * sample).toDouble()
                                sampleCounts[barIndex]++
                            }

                            if (barIndex > highestFilledBar) highestFilledBar = barIndex

                            val interval = if (lastUpdateBar < 0) firstUpdateThreshold else regularUpdateInterval
                            if (highestFilledBar - kotlin.math.max(0, lastUpdateBar) >= interval) {
                                lastUpdateBar = highestFilledBar
                                val partial = normaliseAmplitudes(sumSquares, sampleCounts, barCount)
                                if (!cancelled.get()) {
                                    mainHandler.post {
                                        if (!cancelled.get()) listener.onProgress(partial)
                                    }
                                }
                            }
                        }
                        codec.releaseOutputBuffer(outputIndex, false)
                    }
                }

                val finalAmps = normaliseAmplitudes(sumSquares, sampleCounts, barCount)
                if (!cancelled.get()) {
                    mainHandler.post {
                        if (!cancelled.get()) listener.onComplete(finalAmps)
                    }
                }
            } finally {
                try { codec.stop() } catch (_: Exception) {}
                codec.release()
            }
        } finally {
            extractor.release()
        }
    }

    private fun normaliseAmplitudes(
        sumSquares: DoubleArray,
        sampleCounts: IntArray,
        barCount: Int
    ): FloatArray {
        val amplitudes = FloatArray(barCount)
        var maxAmp = 0f
        for (i in 0 until barCount) {
            if (sampleCounts[i] > 0) {
                amplitudes[i] = sqrt(sumSquares[i] / sampleCounts[i]).toFloat()
                if (amplitudes[i] > maxAmp) maxAmp = amplitudes[i]
            }
        }
        if (maxAmp > 0f) {
            for (i in amplitudes.indices) {
                amplitudes[i] = (amplitudes[i] / maxAmp).coerceIn(0f, 1f)
            }
        }
        return amplitudes
    }

    companion object {
        private const val TAG = "WaveformDecoder"
    }
}
