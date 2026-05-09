package com.audiowaveform

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.view.Gravity
import android.widget.TextView
import kotlin.math.floor

/**
 * Rounded "1.5x" speed-rate label. Tap-to-cycle is wired up via `onTap`;
 * the parent (`AudioWaveformView`) is responsible for applying the new rate.
 */
class SpeedPillView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : TextView(context, attrs, defStyleAttr) {

    private val pillBackground = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(Color.argb(64, 255, 255, 255))
    }

    var pillColor: Int = Color.argb(64, 255, 255, 255)
        set(value) {
            field = value
            pillBackground.setColor(value)
            invalidate()
        }

    var onTap: (() -> Unit)? = null

    init {
        gravity = Gravity.CENTER
        setTextColor(Color.WHITE)
        textSize = 12f
        setTypeface(typeface, Typeface.BOLD)
        background = pillBackground
        // Vertical padding stays small; the pill height is driven by intrinsic size.
        val hPadding = (8f * resources.displayMetrics.density).toInt()
        val vPadding = (2f * resources.displayMetrics.density).toInt()
        setPadding(hPadding, vPadding, hPadding, vPadding)
        isClickable = true
        isFocusable = true
        setOnClickListener {
            animate().alpha(0.6f).setDuration(80).withEndAction {
                animate().alpha(1.0f).setDuration(120).start()
            }.start()
            onTap?.invoke()
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // Make the corner radius track the height for a perfect pill shape.
        pillBackground.cornerRadius = h / 2f
    }

    fun setSpeed(speed: Float) {
        val rounded = (speed * 10f).toInt().toFloat() / 10f
        text = if (rounded == floor(rounded)) {
            "${rounded.toInt()}x"
        } else {
            String.format("%.1fx", rounded)
        }
    }
}
