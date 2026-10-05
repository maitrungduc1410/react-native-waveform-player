---
description: "Control AudioWaveformView from code with play, pause, toggle, seekTo and setSpeed on a ref, and how each method behaves while loading and in controlled mode."
---

# Ref methods

Attach a ref typed as `AudioWaveformViewRef` to call the player from code:

```tsx
import { useRef } from 'react';
import {
  AudioWaveformView,
  type AudioWaveformViewRef,
} from 'react-native-waveform-player';

const ref = useRef<AudioWaveformViewRef>(null);

<AudioWaveformView ref={ref} source={{ uri }} style={{ height: 56 }} />;

ref.current?.play();
ref.current?.pause();
ref.current?.toggle();
ref.current?.seekTo(0);
ref.current?.setSpeed(2);
```

All methods return `void` and run on the native side right away. Watch [`onPlayerStateChange`](/guide/events#onplayerstatechange) and [`onSeek`](/guide/events#onseek) to see the result.

| Method | What it does | In controlled mode |
| --- | --- | --- |
| `play()` | Starts playback. | No effect when `playing` is set. |
| `pause()` | Pauses playback. | No effect when `playing` is set. |
| `toggle()` | Plays if paused, pauses if playing. | No effect when `playing` is set. |
| `seekTo(positionMs)` | Moves the playhead to a position in milliseconds. | Works. |
| `setSpeed(speed)` | Changes the playback speed. | No effect when `speed` is set. |

Try the methods on the web approximation:

<WaveformPlayground :controls="false" />

## play()

- **While loading**, the call is remembered: playback starts as soon as the source is ready. The button keeps showing the spinner until then. A `pause()` before that cancels it.
- **After the end** (`state` is `ended`), `play()` starts again from `0`. This also happens if you called `seekTo()` or the user dragged after the end. To continue from another position, call `play()` first and then `seekTo()`.
- With `playing` set, the method does nothing. Change the `playing` prop instead.

## pause() and toggle()

`pause()` does nothing if the player is already paused. `toggle()` calls `play()` or `pause()` depending on the current state, with the same rules as above.

## seekTo(positionMs)

- The value is rounded to whole milliseconds, negative values become `0`, and the player clamps the result to the duration.
- Fires `onSeek` with the requested position.
- Playback keeps its state: a playing note continues from the new position, a paused one stays paused.
- Before `onLoad` the duration is still unknown, so the position lands on `0`. To start somewhere else, use the [`initialPositionMs`](/guide/props#playback) prop.
- It works in controlled mode, because seeking does not conflict with the `playing` or `speed` props.

## setSpeed(speed)

- Changes the speed and updates the pill. You can call it while paused; the speed applies when playback resumes.
- The native players clamp the speed to the 0.25 to 4 range, but the pill and `onPlayerStateChange` show the value you passed. Keep values inside that range.
- The value does not have to be in `speeds`. The next tap on the pill then moves to the first value in `speeds` that is larger, or wraps to the first one.
- With `speed` set, the method does nothing. Change the `speed` prop instead.
