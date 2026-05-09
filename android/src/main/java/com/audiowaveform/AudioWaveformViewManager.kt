package com.audiowaveform

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.events.EventDispatcher
import com.facebook.react.viewmanagers.AudioWaveformViewManagerDelegate
import com.facebook.react.viewmanagers.AudioWaveformViewManagerInterface

@ReactModule(name = AudioWaveformViewManager.NAME)
class AudioWaveformViewManager(@Suppress("UNUSED_PARAMETER") context: ReactApplicationContext) :
    SimpleViewManager<AudioWaveformView>(),
    AudioWaveformViewManagerInterface<AudioWaveformView> {

    private val mDelegate: ViewManagerDelegate<AudioWaveformView> =
        AudioWaveformViewManagerDelegate(this)

    override fun getDelegate(): ViewManagerDelegate<AudioWaveformView> = mDelegate

    override fun getName(): String = NAME

    public override fun createViewInstance(context: ThemedReactContext): AudioWaveformView {
        val view = AudioWaveformView(context)
        wireEvents(view)
        return view
    }

    /** Hook the AudioWaveformView's callback closures up to the Fabric event dispatcher. */
    private fun wireEvents(view: AudioWaveformView) {
        view.onLoad = { durationMs ->
            dispatchEvent(view, "topLoad") { putInt("durationMs", durationMs) }
        }
        view.onLoadError = { message ->
            dispatchEvent(view, "topLoadError") { putString("message", message) }
        }
        view.onPlayerStateChange = { state, isPlaying, speed, error ->
            dispatchEvent(view, "topPlayerStateChange") {
                putString("state", state)
                putBoolean("isPlaying", isPlaying)
                putDouble("speed", speed.toDouble())
                putString("error", error)
            }
        }
        view.onTimeUpdate = { currentMs, durationMs ->
            dispatchEvent(view, "topTimeUpdate") {
                putInt("currentTimeMs", currentMs)
                putInt("durationMs", durationMs)
            }
        }
        view.onSeek = { positionMs ->
            dispatchEvent(view, "topSeek") { putInt("positionMs", positionMs) }
        }
        view.onEnd = {
            dispatchEvent(view, "topEnd") {}
        }
    }

    private inline fun dispatchEvent(
        view: AudioWaveformView,
        eventName: String,
        builder: WritableMap.() -> Unit
    ) {
        val context = view.context as? ThemedReactContext ?: return
        val dispatcher: EventDispatcher? = UIManagerHelper.getEventDispatcherForReactTag(
            context,
            view.id
        )
        val surfaceId = UIManagerHelper.getSurfaceId(context)
        val payload = Arguments.createMap()
        payload.builder()
        dispatcher?.dispatchEvent(
            AudioWaveformEvent(surfaceId, view.id, eventName, payload)
        )
    }

    // region Fabric prop setters (codegen interface) ----------------------------

    override fun setSource(view: AudioWaveformView, value: ReadableMap?) {
        val uri = value?.getString("uri") ?: ""
        view.sourceUri = uri
    }

    override fun setSamples(view: AudioWaveformView, value: ReadableArray?) {
        view.setSamplesFromArray(value)
    }

    override fun setPlayedBarColor(view: AudioWaveformView, value: Int?) {
        view.playedBarColor = value ?: android.graphics.Color.WHITE
    }

    override fun setUnplayedBarColor(view: AudioWaveformView, value: Int?) {
        view.unplayedBarColor =
            value ?: android.graphics.Color.argb(128, 255, 255, 255)
    }

    override fun setBarWidth(view: AudioWaveformView, value: Float) {
        view.barWidthDp = if (value > 0) value else 3f
    }

    override fun setBarGap(view: AudioWaveformView, value: Float) {
        view.barGapDp = if (value >= 0) value else 2f
    }

    override fun setBarRadius(view: AudioWaveformView, value: Float) {
        view.barRadiusDp = value  // -1 (or any negative) means "auto" = barWidth / 2
    }

    override fun setBarCount(view: AudioWaveformView, value: Int) {
        view.barCountOverride = value.coerceAtLeast(0)
    }

    override fun setContainerBackgroundColor(view: AudioWaveformView, value: Int?) {
        view.containerBackgroundColor =
            value ?: android.graphics.Color.parseColor("#3478F6")
    }

    override fun setContainerBorderRadius(view: AudioWaveformView, value: Float) {
        view.containerBorderRadiusDp = if (value >= 0) value else 16f
    }

    override fun setShowBackground(view: AudioWaveformView, value: Boolean) {
        view.showBackground = value
    }

    override fun setShowPlayButton(view: AudioWaveformView, value: Boolean) {
        view.showPlayButton = value
    }

    override fun setPlayButtonColor(view: AudioWaveformView, value: Int?) {
        view.playButtonColor = value ?: android.graphics.Color.WHITE
    }

    override fun setShowTime(view: AudioWaveformView, value: Boolean) {
        view.showTime = value
    }

    override fun setTimeColor(view: AudioWaveformView, value: Int?) {
        view.timeColor = value ?: android.graphics.Color.WHITE
    }

    override fun setTimeMode(view: AudioWaveformView, value: String?) {
        view.timeMode = value ?: "count-up"
    }

    override fun setShowSpeedControl(view: AudioWaveformView, value: Boolean) {
        view.showSpeedControl = value
    }

    override fun setSpeedColor(view: AudioWaveformView, value: Int?) {
        view.speedColor = value ?: android.graphics.Color.WHITE
    }

    override fun setSpeedBackgroundColor(view: AudioWaveformView, value: Int?) {
        view.speedBackgroundColor =
            value ?: android.graphics.Color.argb(64, 255, 255, 255)
    }

    override fun setSpeeds(view: AudioWaveformView, value: ReadableArray?) {
        view.setSpeedsFromArray(value)
    }

    override fun setDefaultSpeed(view: AudioWaveformView, value: Float) {
        view.defaultSpeed = if (value > 0) value else 1f
    }

    override fun setAutoPlay(view: AudioWaveformView, value: Boolean) {
        view.autoPlay = value
    }

    override fun setInitialPositionMs(view: AudioWaveformView, value: Int) {
        view.initialPositionMs = value.coerceAtLeast(0)
    }

    override fun setLoop(view: AudioWaveformView, value: Boolean) {
        view.loopPlayback = value
    }

    override fun setPlayInBackground(view: AudioWaveformView, value: Boolean) {
        view.playInBackground = value
    }

    override fun setPauseUiUpdatesInBackground(view: AudioWaveformView, value: Boolean) {
        view.pauseUiUpdatesInBackground = value
    }

    override fun setControlledPlaying(view: AudioWaveformView, value: Int) {
        view.controlledPlaying = value
    }

    override fun setControlledSpeed(view: AudioWaveformView, value: Float) {
        view.controlledSpeed = value
    }

    // endregion

    // region Commands -----------------------------------------------------------

    override fun play(view: AudioWaveformView) {
        view.play()
    }

    override fun pause(view: AudioWaveformView) {
        view.pause()
    }

    override fun toggle(view: AudioWaveformView) {
        view.toggle()
    }

    override fun seekTo(view: AudioWaveformView, positionMs: Int) {
        view.seekTo(positionMs)
    }

    override fun setSpeed(view: AudioWaveformView, speed: Float) {
        view.setSpeedValue(speed)
    }

    // endregion

    override fun onDropViewInstance(view: AudioWaveformView) {
        super.onDropViewInstance(view)
    }

    companion object {
        const val NAME = "AudioWaveformView"
    }
}
