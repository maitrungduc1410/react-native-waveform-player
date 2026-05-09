package com.audiowaveform

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator

/**
 * Renders the audio waveform as a row of vertical rounded-rect bars with a
 * "played" / "unplayed" two-tone fill, and handles immediate touch-and-drag
 * scrubbing.
 *
 * Drawing model:
 *   1. Build a single cached `Path` containing every bar's rounded-rect when
 *      amplitudes / size / bar geometry change.
 *   2. On every `onDraw`:
 *        a. `canvas.drawPath(cachedPath, unplayedPaint)`.
 *        b. `canvas.save()` -> `clipRect(0, 0, progressX, height)` ->
 *           `canvas.drawPath(cachedPath, playedPaint)` -> `canvas.restore()`.
 *
 * Touch handling is **immediate** — scrub starts at `ACTION_DOWN`, with no
 * slop or long-press delay. The host view receives the proportional position
 * via the `onScrubBegan/Moved/Ended` callbacks.
 */
class WaveformBarsView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    // region Visual configuration ------------------------------------------------

    var amplitudes: FloatArray = FloatArray(0)
        private set

    /**
     * Update the bar amplitudes. Each call animates the existing displayed
     * heights toward the new target over [AMPLITUDE_ANIMATION_DURATION_MS]
     * (ease-out). Bars expand symmetrically from the centre because the bar
     * geometry is centre-aligned in [buildBarPath].
     */
    fun setAmplitudes(values: FloatArray) {
        amplitudes = values
        setTargetAmplitudes(values)
    }

    var playedBarColor: Int
        get() = playedPaint.color
        set(value) {
            playedPaint.color = value
            invalidate()
        }

    var unplayedBarColor: Int
        get() = unplayedPaint.color
        set(value) {
            unplayedPaint.color = value
            invalidate()
        }

    var barWidthPx: Float = 3f * resources.displayMetrics.density
        set(value) {
            field = value
            invalidatePath()
        }

    var barGapPx: Float = 2f * resources.displayMetrics.density
        set(value) {
            field = value
            invalidatePath()
        }

    /** `< 0` means "auto" = barWidth / 2. */
    var barRadiusPx: Float = -1f
        set(value) {
            field = value
            invalidatePath()
        }

    /** `<= 0` means "auto from view width". */
    var barCountOverride: Int = 0
        set(value) {
            field = value
            invalidatePath()
        }

    /** Fraction of the waveform that has been played, in [0, 1]. */
    var progressFraction: Float = 0f
        set(value) {
            val clamped = value.coerceIn(0f, 1f)
            if (clamped != field) {
                field = clamped
                invalidate()
            }
        }

    // endregion

    // region Touch / scrub callbacks ---------------------------------------------

    /** All callbacks pass a fraction in [0, 1] (touch x / view width). */
    var onScrubBegan: ((Float) -> Unit)? = null
    var onScrubMoved: ((Float) -> Unit)? = null
    var onScrubEnded: ((Float, Boolean /* cancelled */) -> Unit)? = null

    // endregion

    // region Private state -------------------------------------------------------

    private val playedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private val unplayedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(128, 255, 255, 255)
        style = Paint.Style.FILL
    }

    private var cachedPath: Path? = null
    private var cachedWidth: Int = 0
    private var cachedHeight: Int = 0
    private val tmpRect = RectF()

    /**
     * Values actually drawn this frame. While an amplitudes update is
     * animating, these are linearly interpolated between [startAmps] and
     * [targetAmps] by [amplitudeAnimator].
     */
    private var displayedAmps: FloatArray = FloatArray(0)
    private var startAmps: FloatArray = FloatArray(0)
    private var targetAmps: FloatArray = FloatArray(0)

    private val amplitudeAnimator: ValueAnimator =
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = AMPLITUDE_ANIMATION_DURATION_MS
            interpolator = DecelerateInterpolator(1.5f)
            addUpdateListener { va ->
                val t = va.animatedValue as Float
                val count = minOf(displayedAmps.size, startAmps.size, targetAmps.size)
                for (i in 0 until count) {
                    displayedAmps[i] = startAmps[i] + (targetAmps[i] - startAmps[i]) * t
                }
                invalidatePath()
            }
        }

    // endregion

    init {
        isClickable = true
        isFocusable = true
    }

    // region Layout / path caching -----------------------------------------------

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w != cachedWidth || h != cachedHeight) {
            invalidatePath()
        }
    }

    private fun invalidatePath() {
        cachedPath = null
        cachedWidth = 0
        cachedHeight = 0
        invalidate()
    }

    private fun ensureCachedPath(): Path? {
        val current = cachedPath
        if (current != null && cachedWidth == width && cachedHeight == height) {
            return current
        }
        val built = buildBarPath() ?: return null
        cachedPath = built
        cachedWidth = width
        cachedHeight = height
        return built
    }

    /**
     * Build the cached path. When [displayedAmps] is empty (decoding hasn't
     * produced anything yet) we render a uniform low-amplitude skeleton so
     * the user sees the bar pattern immediately instead of an empty card.
     *
     * `displayedAmps` already substitutes [PLACEHOLDER_AMPLITUDE] for any
     * not-yet-decoded bar in [setTargetAmplitudes], so trailing bars stay at
     * skeleton height instead of dropping to `minBarHeight` between partials.
     */
    private fun buildBarPath(): Path? {
        val totalWidth = width.toFloat()
        val totalHeight = height.toFloat()
        if (totalWidth <= 0 || totalHeight <= 0) return null

        val step = barWidthPx + barGapPx
        if (step <= 0f) return null

        val autoCount = (totalWidth / step).toInt()
        val barCount = if (barCountOverride > 0) {
            kotlin.math.min(barCountOverride, autoCount)
        } else {
            autoCount
        }
        if (barCount <= 0) return null

        val verticalPadding = barWidthPx * 1.5f
        val drawableHeight = totalHeight - verticalPadding * 2f
        if (drawableHeight <= 0f) return null
        val minBarHeight = barWidthPx
        val radius = if (barRadiusPx < 0f) barWidthPx / 2f else barRadiusPx
        val usePlaceholder = displayedAmps.isEmpty()

        val path = Path()
        for (i in 0 until barCount) {
            val amp = if (usePlaceholder) {
                PLACEHOLDER_AMPLITUDE
            } else {
                val ampIndex = (i * displayedAmps.size / barCount)
                    .coerceIn(0, displayedAmps.size - 1)
                displayedAmps[ampIndex].coerceIn(0f, 1f)
            }
            val barHeight = (amp * drawableHeight).coerceAtLeast(minBarHeight)
            val x = i * step
            val y = verticalPadding + (drawableHeight - barHeight) / 2f
            tmpRect.set(x, y, x + barWidthPx, y + barHeight)
            path.addRoundRect(tmpRect, radius, radius, Path.Direction.CW)
        }
        return path
    }

    /**
     * Update the animation targets when new amplitudes arrive. Each call
     * captures the current [displayedAmps] as the start, sets the new
     * `targetAmps`, and (re)starts the animator. Re-entrant — a new payload
     * mid-animation cancels the previous run and animates from the
     * mid-frame state to the new target.
     */
    private fun setTargetAmplitudes(values: FloatArray) {
        if (values.isEmpty()) {
            amplitudeAnimator.cancel()
            displayedAmps = FloatArray(0)
            startAmps = FloatArray(0)
            targetAmps = FloatArray(0)
            invalidatePath()
            return
        }

        // Treat zero amplitude as "not yet decoded" — keep those bars at the
        // skeleton placeholder height instead of letting them snap to
        // `minBarHeight` between partials.
        val processed = FloatArray(values.size) { i ->
            if (values[i] > 0f) values[i] else PLACEHOLDER_AMPLITUDE
        }

        if (displayedAmps.size != processed.size) {
            // First non-empty payload (or barCount changed). Seed the
            // current values with the placeholder skeleton so the animation
            // grows from skeleton -> real shape.
            displayedAmps = FloatArray(processed.size) { PLACEHOLDER_AMPLITUDE }
        }

        startAmps = displayedAmps.copyOf()
        targetAmps = processed
        amplitudeAnimator.cancel()
        amplitudeAnimator.start()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        amplitudeAnimator.cancel()
    }

    companion object {
        /**
         * Uniform amplitude used to render the "loading" skeleton when no
         * real amplitudes have been decoded yet.
         */
        private const val PLACEHOLDER_AMPLITUDE = 0.2f

        /** Duration (ms) of each amplitude-update animation. */
        private const val AMPLITUDE_ANIMATION_DURATION_MS = 200L
    }

    // endregion

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val path = ensureCachedPath() ?: return

        // Pass 1: all bars in the unplayed color.
        canvas.drawPath(path, unplayedPaint)

        // Pass 2: clip to [0, progressX] and re-fill in the played color.
        val progressX = (progressFraction.coerceIn(0f, 1f) * width.toFloat())
        if (progressX <= 0f) return
        val saveCount = canvas.save()
        canvas.clipRect(0f, 0f, progressX, height.toFloat())
        canvas.drawPath(path, playedPaint)
        canvas.restoreToCount(saveCount)
    }

    // region Touch handling — immediate scrub ------------------------------------

    @Suppress("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val w = width
        if (w <= 0) return super.onTouchEvent(event)

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // Don't let a parent ScrollView steal the drag.
                parent?.requestDisallowInterceptTouchEvent(true)
                val fraction = (event.x / w.toFloat()).coerceIn(0f, 1f)
                progressFraction = fraction
                invalidate()
                onScrubBegan?.invoke(fraction)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val fraction = (event.x / w.toFloat()).coerceIn(0f, 1f)
                progressFraction = fraction
                invalidate()
                onScrubMoved?.invoke(fraction)
                return true
            }
            MotionEvent.ACTION_UP -> {
                val fraction = (event.x / w.toFloat()).coerceIn(0f, 1f)
                progressFraction = fraction
                invalidate()
                onScrubEnded?.invoke(fraction, false)
                parent?.requestDisallowInterceptTouchEvent(false)
                performClick()
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                onScrubEnded?.invoke(progressFraction, true)
                parent?.requestDisallowInterceptTouchEvent(false)
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    // endregion
}
