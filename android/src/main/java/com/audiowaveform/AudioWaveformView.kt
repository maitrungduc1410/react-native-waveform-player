package com.audiowaveform

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReadableArray

/**
 * Composite native view rendered by the Fabric `AudioWaveformViewManager`.
 *
 * Layout (left -> right):
 *   [ rounded background (optional) ]
 *     [ play/pause button | waveform bars | stack(time, speed pill) ]
 *
 * The view manager owns this and routes Fabric prop updates / commands to
 * the public setters/methods below, then dispatches events through the
 * `onLoad/onLoadError/onPlayerStateChange/onTimeUpdate/onSeek/onEnd`
 * callbacks (set up in `AudioWaveformViewManager`).
 */
class AudioWaveformView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr), LifecycleEventListener {

    private val density = resources.displayMetrics.density

    // region Subviews ------------------------------------------------------------

    private val backgroundDrawable = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(Color.parseColor("#3478F6"))
        cornerRadius = 16f * density
    }

    private val rowContainer = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        val hPadding = (12f * density).toInt()
        setPadding(hPadding, 0, hPadding, 0)
    }

    private val playButton = PlayPauseButton(context).apply {
        iconColor = Color.WHITE
    }

    private val barsView = WaveformBarsView(context).apply {
        playedBarColor = Color.WHITE
        unplayedBarColor = Color.argb(128, 255, 255, 255)
        barWidthPx = 3f * density
        barGapPx = 2f * density
    }

    private val rightStack = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
    }

    private val timeLabel = TextView(context).apply {
        gravity = Gravity.END
        setTextColor(Color.WHITE)
        text = "0:00"
        textSize = 13f
        setTypeface(typeface, android.graphics.Typeface.BOLD)
    }

    private val speedPill = SpeedPillView(context).apply {
        setSpeed(1.0f)
    }

    // endregion

    // region Audio engine + decoder ---------------------------------------------

    private val engine = AudioPlayerEngine()
    private val decoder = WaveformDecoder()

    // endregion

    // region Internal state ------------------------------------------------------

    private var currentSourceUri: String? = null
    private var samplesProvided: Boolean = false

    private var internalSpeed: Float = 1.0f
    private var defaultSpeedApplied: Boolean = false

    private var initialPositionApplied: Boolean = false

    private var isScrubbing: Boolean = false
    private var resumeAfterScrub: Boolean = false

    private var isBackgrounded: Boolean = false

    // endregion

    // region Reactive props (set by the view manager) ---------------------------

    var playedBarColor: Int = Color.WHITE
        set(value) {
            field = value
            barsView.playedBarColor = value
        }

    var unplayedBarColor: Int = Color.argb(128, 255, 255, 255)
        set(value) {
            field = value
            barsView.unplayedBarColor = value
        }

    var barWidthDp: Float = 3f
        set(value) {
            field = value
            barsView.barWidthPx = value * density
        }

    var barGapDp: Float = 2f
        set(value) {
            field = value
            barsView.barGapPx = value * density
        }

    var barRadiusDp: Float = -1f
        set(value) {
            field = value
            barsView.barRadiusPx = if (value < 0f) -1f else value * density
        }

    var barCountOverride: Int = 0
        set(value) {
            field = value
            barsView.barCountOverride = value
        }

    var containerBackgroundColor: Int = Color.parseColor("#3478F6")
        set(value) {
            field = value
            backgroundDrawable.setColor(value)
            applyBackground()
        }

    var containerBorderRadiusDp: Float = 16f
        set(value) {
            field = value
            backgroundDrawable.cornerRadius = value * density
            applyBackground()
        }

    var showBackground: Boolean = true
        set(value) {
            field = value
            applyBackground()
        }

    var showPlayButton: Boolean = true
        set(value) {
            field = value
            playButton.visibility = if (value) View.VISIBLE else View.GONE
        }

    var playButtonColor: Int = Color.WHITE
        set(value) {
            field = value
            playButton.iconColor = value
        }

    var showTime: Boolean = true
        set(value) {
            field = value
            timeLabel.visibility = if (value) View.VISIBLE else View.GONE
            updateRightStackVisibility()
        }

    var timeColor: Int = Color.WHITE
        set(value) {
            field = value
            timeLabel.setTextColor(value)
        }

    var timeMode: String = "count-up"
        set(value) {
            field = value
            updateTimeLabel()
        }

    var showSpeedControl: Boolean = true
        set(value) {
            field = value
            speedPill.visibility = if (value) View.VISIBLE else View.GONE
            updateRightStackVisibility()
        }

    var speedColor: Int = Color.WHITE
        set(value) {
            field = value
            speedPill.setTextColor(value)
        }

    var speedBackgroundColor: Int = Color.argb(64, 255, 255, 255)
        set(value) {
            field = value
            speedPill.pillColor = value
        }

    var speeds: FloatArray = floatArrayOf(0.5f, 1.0f, 1.5f, 2.0f)
        set(value) {
            field = if (value.isEmpty()) floatArrayOf(0.5f, 1.0f, 1.5f, 2.0f) else value
        }

    var defaultSpeed: Float = 1.0f
        set(value) {
            field = value
            if (!defaultSpeedApplied) {
                applyEffectiveSpeed(value)
            }
        }

    var autoPlay: Boolean = false
    var initialPositionMs: Int = 0
    var loopPlayback: Boolean = false
        set(value) {
            field = value
            engine.loop = value
        }

    /**
     * Whether playback should continue when the host app is backgrounded.
     * Default `false` — we pause on `LifecycleEventListener.onHostPause`.
     * When `true`, we also opt into `MediaPlayer.setWakeMode` so playback
     * can survive device sleep (requires `WAKE_LOCK` permission in the host
     * app manifest; otherwise `setWakeMode` is silently skipped).
     */
    var playInBackground: Boolean = false
        set(value) {
            field = value
            engine.setBackgroundPlaybackEnabled(context, value)
        }

    /**
     * While the host app is backgrounded, skip the bars / time-label refreshes
     * that would otherwise piggy-back on every 30 Hz progress tick. The JS
     * `onTimeUpdate` event keeps firing regardless. Default `true`.
     */
    var pauseUiUpdatesInBackground: Boolean = true

    /** -1 = uncontrolled, 0 = paused, 1 = playing. */
    var controlledPlaying: Int = -1
        set(value) {
            field = value
            applyControlledState()
        }

    /** < 0 = uncontrolled, otherwise the rate to apply. */
    var controlledSpeed: Float = -1f
        set(value) {
            field = value
            applyControlledState()
        }

    var sourceUri: String = ""
        set(value) {
            if (field == value) return
            field = value
            applySource()
        }

    var providedSamples: FloatArray? = null
        set(value) {
            field = value
            applyProvidedSamples()
        }

    // endregion

    // region Event callbacks (wired by the view manager) ------------------------

    var onLoad: ((Int) -> Unit)? = null
    var onLoadError: ((String) -> Unit)? = null
    var onPlayerStateChange: ((String, Boolean, Float, String) -> Unit)? = null
    var onTimeUpdate: ((Int, Int) -> Unit)? = null
    var onSeek: ((Int) -> Unit)? = null
    var onEnd: (() -> Unit)? = null

    // endregion

    init {
        background = backgroundDrawable
        clipToOutline = true

        playButton.setOnClickListener { handlePlayButtonTap() }

        speedPill.onTap = { handleSpeedPillTap() }

        barsView.onScrubBegan = { fraction -> handleScrubBegan(fraction) }
        barsView.onScrubMoved = { fraction -> handleScrubMoved(fraction) }
        barsView.onScrubEnded = { fraction, cancelled -> handleScrubEnded(fraction, cancelled) }

        rightStack.addView(timeLabel, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.END
            bottomMargin = (4f * density).toInt()
        })
        rightStack.addView(speedPill, LinearLayout.LayoutParams(
            (44f * density).toInt(),
            (22f * density).toInt()
        ).apply {
            gravity = Gravity.END
        })

        rowContainer.addView(playButton, LinearLayout.LayoutParams(
            (32f * density).toInt(),
            (32f * density).toInt()
        ).apply {
            marginEnd = (8f * density).toInt()
        })
        rowContainer.addView(barsView, LinearLayout.LayoutParams(
            0,
            ViewGroup.LayoutParams.MATCH_PARENT,
            1f
        ))
        rowContainer.addView(rightStack, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            marginStart = (8f * density).toInt()
        })

        addView(rowContainer, LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))

        wireEngineCallbacks()
        (context as? ReactContext)?.addLifecycleEventListener(this)
    }

    // region Host lifecycle (React Native) --------------------------------------

    override fun onHostResume() {
        isBackgrounded = false
        // Snap UI to the engine's current state in case we skipped tick
        // updates while backgrounded.
        val dur = engine.durationMs
        val cur = engine.currentMs
        if (dur > 0) {
            barsView.progressFraction = cur.toFloat() / dur.toFloat()
        }
        updateTimeLabel(cur, dur)
        playButton.isPlaying = engine.isPlaying
    }

    override fun onHostPause() {
        isBackgrounded = true
        if (playInBackground) return
        if (engine.isPlaying) {
            engine.pause()
        }
    }

    override fun onHostDestroy() {
        engine.reset()
        decoder.cancel()
    }

    // endregion

    // region Source / samples ----------------------------------------------------

    private fun applySource() {
        val uri = sourceUri
        if (uri.isEmpty()) {
            currentSourceUri = null
            engine.reset()
            return
        }
        currentSourceUri = uri
        initialPositionApplied = false
        engine.setSource(context, uri)
        emitPlayerState()

        if (!samplesProvided) {
            decodeAmplitudesIfPossible()
        }
    }

    private fun applyProvidedSamples() {
        val provided = providedSamples
        if (provided == null || provided.isEmpty()) {
            samplesProvided = false
            decodeAmplitudesIfPossible()
            return
        }
        samplesProvided = true
        decoder.cancel()
        // Renormalise in case caller passed values >1.
        val maxV = provided.maxOrNull() ?: 0f
        val finalAmps = if (maxV <= 0f) {
            FloatArray(provided.size)
        } else if (maxV <= 1f) {
            provided.copyOf()
        } else {
            FloatArray(provided.size) { (provided[it] / maxV).coerceIn(0f, 1f) }
        }
        barsView.setAmplitudes(finalAmps)
    }

    private fun decodeAmplitudesIfPossible() {
        if (samplesProvided) return
        val uri = currentSourceUri ?: return
        // Use a sensible bar count; the bars view re-buckets to its own
        // count at draw time so this just needs to be reasonably granular.
        val provisional = if (barsView.width > 0) {
            ((barsView.width / (barsView.barWidthPx + barsView.barGapPx)).toInt()).coerceAtLeast(8)
        } else 80
        decoder.decode(uri, provisional, object : WaveformDecoder.Listener {
            override fun onProgress(amplitudes: FloatArray) {
                barsView.setAmplitudes(amplitudes)
            }
            override fun onComplete(amplitudes: FloatArray) {
                barsView.setAmplitudes(amplitudes)
            }
            override fun onFailure(message: String) {
                onLoadError?.invoke(message)
            }
        })
    }

    // endregion

    // region Background ----------------------------------------------------------

    private fun applyBackground() {
        background = if (showBackground) backgroundDrawable else null
    }

    // endregion

    // region Engine plumbing -----------------------------------------------------

    private fun wireEngineCallbacks() {
        engine.onLoad = { duration ->
            onLoad?.invoke(duration)
            if (!initialPositionApplied && initialPositionMs > 0) {
                engine.seekToMs(initialPositionMs)
            }
            initialPositionApplied = true
            // Honour autoplay / controlled state once the source is ready.
            if (controlledPlaying == 1) {
                engine.play()
            } else if (controlledPlaying == -1 && autoPlay) {
                engine.play()
            }
            emitPlayerState()
        }
        engine.onLoadError = { message ->
            onLoadError?.invoke(message)
            emitPlayerState(error = message)
        }
        engine.onStateChange = {
            // Order matters: update `isPlaying` *before* `isLoading`. While
            // the spinner is still showing the icon swap is invisible to
            // the user; then when we drop the spinner the imageView is
            // already pointing at the right icon (no crossfade flash if
            // a tap was queued during loading).
            playButton.isPlaying = engine.isPlaying
            playButton.isLoading = (engine.state == AudioPlayerEngine.State.LOADING)
            emitPlayerState()
        }
        engine.onTimeUpdate = { currentMs, durationMs ->
            if (!isScrubbing) {
                // JS event always fires (callers may want it for now-playing UI).
                onTimeUpdate?.invoke(currentMs, durationMs)
                // Skip the cheap-but-pointless UI work while backgrounded.
                if (!(isBackgrounded && pauseUiUpdatesInBackground)) {
                    barsView.progressFraction = if (durationMs > 0) {
                        currentMs.toFloat() / durationMs.toFloat()
                    } else 0f
                    updateTimeLabel(currentMs, durationMs)
                }
            }
        }
        engine.onEnded = {
            onEnd?.invoke()
            playButton.isPlaying = false
            emitPlayerState()
        }
    }

    private fun emitPlayerState(error: String? = null) {
        val stateString = when (engine.state) {
            AudioPlayerEngine.State.IDLE -> "idle"
            AudioPlayerEngine.State.LOADING -> "loading"
            AudioPlayerEngine.State.READY -> "ready"
            AudioPlayerEngine.State.ENDED -> "ended"
            AudioPlayerEngine.State.ERROR -> "error"
        }
        onPlayerStateChange?.invoke(
            stateString,
            engine.isPlaying,
            effectiveSpeed(),
            error ?: ""
        )
    }

    private fun updateRightStackVisibility() {
        rightStack.visibility = if (showTime || showSpeedControl) View.VISIBLE else View.GONE
    }

    // endregion

    // region Time / speed --------------------------------------------------------

    private fun updateTimeLabel(currentMs: Int = engine.currentMs, durationMs: Int = engine.durationMs) {
        val display = if (timeMode.equals("count-down", ignoreCase = true)) {
            (durationMs - currentMs).coerceAtLeast(0)
        } else currentMs
        val totalSeconds = display / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        timeLabel.text = String.format("%d:%02d", minutes, seconds)
    }

    private fun effectiveSpeed(): Float =
        if (controlledSpeed >= 0) controlledSpeed else internalSpeed

    private fun nextSpeed(current: Float): Float {
        if (speeds.isEmpty()) return 1.0f
        val next = speeds.firstOrNull { it > current + 0.001f }
        return next ?: speeds.first()
    }

    private fun applyEffectiveSpeed(rate: Float) {
        if (controlledSpeed < 0) {
            internalSpeed = rate
            defaultSpeedApplied = true
        }
        engine.setRate(rate)
        speedPill.setSpeed(rate)
        emitPlayerState()
    }

    private fun applyControlledState() {
        if (controlledSpeed >= 0) {
            engine.setRate(controlledSpeed)
            speedPill.setSpeed(controlledSpeed)
        }
        when (controlledPlaying) {
            0 -> if (engine.isPlaying) engine.pause()
            // The engine's `play()` understands `LOADING` and queues a
            // pending start, so we forward the intent regardless of
            // state and let the engine resume playback the moment
            // buffering finishes (or no-op if we're in IDLE / ERROR).
            1 -> engine.play()
        }
        emitPlayerState()
    }

    // endregion

    // region Action handlers -----------------------------------------------------

    private fun handlePlayButtonTap() {
        if (controlledPlaying != -1) {
            // Controlled — fire event with requested *new* state, but don't toggle.
            val newPlaying = !engine.isPlaying
            playButton.isPlaying = engine.isPlaying  // restore visual state
            onPlayerStateChange?.invoke(
                stateString(),
                newPlaying,
                effectiveSpeed(),
                ""
            )
            return
        }
        engine.toggle()
        playButton.isPlaying = engine.isPlaying
    }

    private fun handleSpeedPillTap() {
        val current = effectiveSpeed()
        val next = nextSpeed(current)
        if (controlledSpeed >= 0) {
            onPlayerStateChange?.invoke(
                stateString(),
                engine.isPlaying,
                next,
                ""
            )
            return
        }
        applyEffectiveSpeed(next)
    }

    private fun stateString(): String = when (engine.state) {
        AudioPlayerEngine.State.IDLE -> "idle"
        AudioPlayerEngine.State.LOADING -> "loading"
        AudioPlayerEngine.State.READY -> "ready"
        AudioPlayerEngine.State.ENDED -> "ended"
        AudioPlayerEngine.State.ERROR -> "error"
    }

    // endregion

    // region Scrub handlers ------------------------------------------------------

    private fun handleScrubBegan(fraction: Float) {
        isScrubbing = true
        resumeAfterScrub = engine.isPlaying
        if (engine.isPlaying) engine.pause()
        val pos = positionFromFraction(fraction)
        engine.seekToMs(pos)
        updateTimeLabel(pos, engine.durationMs)
    }

    private fun handleScrubMoved(fraction: Float) {
        val pos = positionFromFraction(fraction)
        engine.seekToMs(pos)
        updateTimeLabel(pos, engine.durationMs)
    }

    private fun handleScrubEnded(fraction: Float, cancelled: Boolean) {
        isScrubbing = false
        val pos = positionFromFraction(fraction)
        engine.seekToMs(pos)
        updateTimeLabel(pos, engine.durationMs)
        onSeek?.invoke(pos)
        if (!cancelled && resumeAfterScrub && controlledPlaying != 0) {
            engine.play()
        }
    }

    private fun positionFromFraction(fraction: Float): Int {
        val dur = engine.durationMs
        if (dur <= 0) return 0
        return (fraction.coerceIn(0f, 1f) * dur).toInt()
    }

    // endregion

    // region Imperative commands (called by the view manager) -------------------

    fun play() {
        if (controlledPlaying != -1) return
        engine.play()
    }

    fun pause() {
        if (controlledPlaying != -1) return
        engine.pause()
    }

    fun toggle() {
        if (controlledPlaying != -1) return
        engine.toggle()
    }

    fun seekTo(ms: Int) {
        engine.seekToMs(ms)
        updateTimeLabel(ms, engine.durationMs)
        onSeek?.invoke(ms)
    }

    fun setSpeedValue(value: Float) {
        if (controlledSpeed >= 0) return
        applyEffectiveSpeed(value)
    }

    // endregion

    // region Bridge helpers -----------------------------------------------------

    fun setSpeedsFromArray(value: ReadableArray?) {
        if (value == null || value.size() == 0) {
            speeds = floatArrayOf(0.5f, 1.0f, 1.5f, 2.0f)
            return
        }
        val arr = FloatArray(value.size())
        for (i in 0 until value.size()) {
            arr[i] = value.getDouble(i).toFloat()
        }
        speeds = arr
    }

    fun setSamplesFromArray(value: ReadableArray?) {
        if (value == null || value.size() == 0) {
            providedSamples = null
            return
        }
        val arr = FloatArray(value.size())
        for (i in 0 until value.size()) {
            arr[i] = value.getDouble(i).toFloat()
        }
        providedSamples = arr
    }

    // endregion

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        (context as? ReactContext)?.removeLifecycleEventListener(this)
        engine.reset()
        decoder.cancel()
    }
}
