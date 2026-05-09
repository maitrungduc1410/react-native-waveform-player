package com.audiowaveform

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ProgressBar

/**
 * Play/pause button backed by the bundled vector drawables
 * `R.drawable.play_fill` and `R.drawable.pause_fill`. Tintable via `iconColor`.
 *
 * While `isLoading` is `true`, the icon is hidden and a native
 * indeterminate `ProgressBar` is shown in its place. The view stays
 * clickable so callers can queue a "play once ready" intent.
 */
class PlayPauseButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    var isPlaying: Boolean = false
        set(value) {
            if (field == value) return
            field = value
            updateImage()
        }

    var isLoading: Boolean = false
        set(value) {
            if (field == value) return
            field = value
            updateLoadingState()
        }

    var iconColor: Int = Color.WHITE
        set(value) {
            field = value
            imageView.setColorFilter(value)
            applySpinnerTint(value)
        }

    private val imageView = ImageView(context).apply {
        scaleType = ImageView.ScaleType.FIT_CENTER
        setColorFilter(Color.WHITE)
    }

    private val spinner = ProgressBar(context).apply {
        isIndeterminate = true
        visibility = View.GONE
    }

    init {
        addView(
            imageView,
            LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
        )
        // Spinner sits on top of the icon (which is hidden while loading).
        // Wrap content + center so the OS-default size is preserved.
        addView(
            spinner,
            LayoutParams(
                LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        )
        isClickable = true
        isFocusable = true
        applySpinnerTint(iconColor)
        updateImage()
    }

    private fun updateImage() {
        val res = if (isPlaying) R.drawable.pause_fill else R.drawable.play_fill
        imageView.setImageResource(res)
        imageView.setColorFilter(iconColor)
    }

    private fun updateLoadingState() {
        if (isLoading) {
            imageView.visibility = View.INVISIBLE
            spinner.visibility = View.VISIBLE
        } else {
            imageView.visibility = View.VISIBLE
            spinner.visibility = View.GONE
        }
    }

    private fun applySpinnerTint(color: Int) {
        spinner.indeterminateTintList = ColorStateList.valueOf(color)
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }
}
