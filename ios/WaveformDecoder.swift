import AVFoundation
import Foundation

/// Decode an audio file into per-bar RMS amplitudes for waveform visualisation.
///
/// `AVAssetReader` cannot read remote URLs, so for `https://` sources this
/// class first downloads the file to a temporary location (with a codec-aware
/// extension — `AVURLAsset` identifies the codec by extension, not MIME).
///
/// All callbacks fire on the **main** thread.
final class WaveformDecoder {

    // MARK: - Public

    /// Begin decoding for `url`, computing exactly `barCount` RMS amplitudes.
    /// Re-entrant: a fresh `decode()` call cancels any in-flight one.
    ///
    /// `progress` is called periodically (~5% then every ~20%) on the main
    /// thread with a partial amplitudes array — this lets the bars view paint
    /// in as the decode runs instead of waiting for the full file. `completion`
    /// is called once with the final, fully-decoded amplitudes.
    /// All amplitudes are normalised to `[0, 1]`.
    func decode(
        url: URL,
        barCount: Int,
        progress: @escaping ([CGFloat]) -> Void = { _ in },
        completion: @escaping ([CGFloat]) -> Void,
        failure: @escaping (String) -> Void
    ) {
        cancel()

        guard barCount > 0 else {
            completion([])
            return
        }

        let token = UUID()
        currentToken = token

        if url.isFileURL {
            decodeLocalFile(
                url: url,
                barCount: barCount,
                token: token,
                progress: progress,
                completion: completion,
                failure: failure
            )
            return
        }

        // Remote URL — download first, then decode.
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            // If a newer decode was kicked off, drop this one silently.
            if self.currentToken != token { return }

            if let error = error {
                DispatchQueue.main.async { failure(error.localizedDescription) }
                return
            }
            guard let tempURL = tempURL else {
                DispatchQueue.main.async { failure("Download failed: empty response") }
                return
            }

            let ext = Self.audioFileExtension(from: response, originalURL: url)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("audiowaveform_\(UUID().uuidString).\(ext)")
            do {
                try FileManager.default.moveItem(at: tempURL, to: dest)
            } catch {
                DispatchQueue.main.async {
                    failure("Failed to stage downloaded audio: \(error.localizedDescription)")
                }
                return
            }
            self.tempLocalURL = dest

            self.decodeLocalFile(
                url: dest,
                barCount: barCount,
                token: token,
                progress: progress,
                completion: completion,
                failure: failure
            )
        }
        downloadTask = task
        task.resume()
    }

    /// Cancel any in-flight decode + download. Safe to call repeatedly.
    func cancel() {
        currentToken = UUID() // Bumping the token invalidates any in-flight closures.
        downloadTask?.cancel()
        downloadTask = nil
        currentReader?.cancelReading()
        currentReader = nil
    }

    /// Cleanup the on-disk temp file (if any). Call from `deinit` of the owner.
    func cleanupTempFile() {
        if let url = tempLocalURL {
            try? FileManager.default.removeItem(at: url)
            tempLocalURL = nil
        }
    }

    deinit {
        cancel()
        cleanupTempFile()
    }

    // MARK: - Private

    private var downloadTask: URLSessionDownloadTask?
    private var currentReader: AVAssetReader?
    private var tempLocalURL: URL?
    private var currentToken: UUID = UUID()

    /// Determine the correct audio file extension from the HTTP response.
    /// Priority: suggested filename -> MIME type -> URL path extension -> "m4a".
    /// Without this, `AVURLAsset` silently fails to identify the codec when
    /// the file lives at a generic URL like `download?id=...`.
    private static func audioFileExtension(from response: URLResponse?, originalURL: URL) -> String {
        if let suggested = response?.suggestedFilename, !suggested.isEmpty {
            let ext = (suggested as NSString).pathExtension
            if !ext.isEmpty { return ext }
        }
        if let mimeType = response?.mimeType?.lowercased() {
            switch mimeType {
            case "audio/mpeg", "audio/mp3": return "mp3"
            case "audio/mp4", "audio/x-m4a", "audio/aac": return "m4a"
            case "audio/wav", "audio/x-wav", "audio/wave": return "wav"
            case "audio/flac": return "flac"
            case "audio/ogg", "audio/vorbis": return "ogg"
            case "audio/aiff", "audio/x-aiff": return "aiff"
            default: break
            }
        }
        let urlExt = originalURL.pathExtension
        if !urlExt.isEmpty { return urlExt }
        return "m4a"
    }

    private func decodeLocalFile(
        url: URL,
        barCount: Int,
        token: UUID,
        progress: @escaping ([CGFloat]) -> Void,
        completion: @escaping ([CGFloat]) -> Void,
        failure: @escaping (String) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.currentToken != token { return }

            let asset = AVURLAsset(
                url: url,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            )

            // `tracks(withMediaType:)` blocks until tracks are loaded for local
            // file URLs, which is fine on a background queue.
            guard let track = asset.tracks(withMediaType: .audio).first else {
                DispatchQueue.main.async {
                    if self.currentToken == token { failure("Audio track not found") }
                }
                return
            }

            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: asset)
            } catch {
                DispatchQueue.main.async {
                    if self.currentToken == token {
                        failure("Failed to create reader: \(error.localizedDescription)")
                    }
                }
                return
            }

            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVNumberOfChannelsKey: 1
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            guard reader.canAdd(output) else {
                DispatchQueue.main.async {
                    if self.currentToken == token { failure("Cannot add reader output") }
                }
                return
            }
            reader.add(output)

            DispatchQueue.main.sync {
                if self.currentToken == token {
                    self.currentReader = reader
                }
            }

            guard reader.startReading() else {
                let msg = reader.error?.localizedDescription ?? "Failed to start reading"
                DispatchQueue.main.async {
                    if self.currentToken == token { failure(msg) }
                }
                return
            }

            // Bucket-by-time setup: with the asset duration we know each bar's
            // time window up-front, so we can fill bars as samples stream in
            // (and emit partial results periodically). Falls back to a 60 s
            // budget for assets that don't expose a duration — matches the
            // Android decoder's behaviour.
            let durationSeconds = CMTimeGetSeconds(track.timeRange.duration)
            let totalDurationUs: Double = (durationSeconds.isFinite && durationSeconds > 0)
                ? durationSeconds * 1_000_000
                : 60_000_000
            let barDurationUs = totalDurationUs / Double(barCount)

            var sumSquares = [Double](repeating: 0, count: barCount)
            var sampleCounts = [Int](repeating: 0, count: barCount)
            var sampleRate: Double = 0
            var highestFilledBar = -1
            let firstUpdateThreshold = max(1, barCount / 20)
            let regularUpdateInterval = max(1, barCount / 5)
            var lastUpdateBar = -1

            while reader.status == .reading {
                if self.currentToken != token { break }
                guard let buffer = output.copyNextSampleBuffer() else { break }
                guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
                let length = CMBlockBufferGetDataLength(block)
                let count = length / MemoryLayout<Float>.size
                guard count > 0 else { continue }

                // Cache sample rate from the first buffer's format description.
                if sampleRate == 0,
                   let fmt = CMSampleBufferGetFormatDescription(buffer),
                   let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee {
                    sampleRate = asbd.mSampleRate
                }
                let effectiveSampleRate = sampleRate > 0 ? sampleRate : 44100

                var data = [Float](repeating: 0, count: count)
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &data)

                let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                let bufferStartUs = CMTimeGetSeconds(pts) * 1_000_000
                let usPerSample = 1_000_000 / effectiveSampleRate

                for i in 0..<count {
                    let sampleTimeUs = bufferStartUs + Double(i) * usPerSample
                    var barIndex = Int(sampleTimeUs / barDurationUs)
                    if barIndex < 0 { barIndex = 0 }
                    if barIndex >= barCount { barIndex = barCount - 1 }
                    let s = Double(data[i])
                    sumSquares[barIndex] += s * s
                    sampleCounts[barIndex] += 1
                    if barIndex > highestFilledBar { highestFilledBar = barIndex }
                }

                let interval = lastUpdateBar < 0 ? firstUpdateThreshold : regularUpdateInterval
                if highestFilledBar - max(0, lastUpdateBar) >= interval {
                    lastUpdateBar = highestFilledBar
                    let partial = Self.normaliseAmplitudes(
                        sumSquares: sumSquares,
                        sampleCounts: sampleCounts,
                        barCount: barCount
                    )
                    DispatchQueue.main.async {
                        if self.currentToken == token { progress(partial) }
                    }
                }
            }

            if self.currentToken != token { return }

            let final = Self.normaliseAmplitudes(
                sumSquares: sumSquares,
                sampleCounts: sampleCounts,
                barCount: barCount
            )

            // Sanity check: did we actually decode anything?
            if highestFilledBar < 0 {
                DispatchQueue.main.async {
                    if self.currentToken == token { failure("No samples decoded") }
                }
                return
            }

            DispatchQueue.main.async {
                if self.currentToken == token {
                    self.currentReader = nil
                    completion(final)
                }
            }
        }
    }

    /// Compute per-bar RMS from accumulated `sumSquares` + `sampleCounts`,
    /// then normalise the result to `[0, 1]` using the loudest bar as the
    /// reference. Bars with zero samples (gaps in the time window) stay at 0.
    private static func normaliseAmplitudes(
        sumSquares: [Double],
        sampleCounts: [Int],
        barCount: Int
    ) -> [CGFloat] {
        var amps = [CGFloat](repeating: 0, count: barCount)
        var maxAmp: CGFloat = 0
        for i in 0..<barCount {
            let n = sampleCounts[i]
            if n > 0 {
                let rms = sqrt(sumSquares[i] / Double(n))
                let value = CGFloat(rms)
                amps[i] = value
                if value > maxAmp { maxAmp = value }
            }
        }
        if maxAmp > 0 {
            for i in 0..<barCount {
                amps[i] = max(0, min(1, amps[i] / maxAmp))
            }
        }
        return amps
    }
}
