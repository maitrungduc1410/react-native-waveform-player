---
description: "Every AudioWaveformView prop, its type and default: source, samples, bar geometry, colors, time label, speed pill, playback, background and controlled props."
---

# Props

`AudioWaveformView` accepts the props below plus the standard `View` props (`style`, `testID`, `pointerEvents`, ...), except `children`. Only `source` is required. Sizes are in points on iOS and dp on Android. Color props take any React Native color value, such as `'#22D3EE'`, `'rgba(34, 211, 238, 0.35)'` or `'white'`.

The generated [API reference](/api/type-aliases/AudioWaveformViewProps) has the same list with the TypeScript types.

## Source and waveform data

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `source` (required) | `{ uri: string }` | | Audio to play: `file://` or `https://` on both platforms, `content://` on Android. |
| `samples` | `number[]` | | Pre-computed amplitudes in `[0, 1]`. When non-empty, native waveform decoding is skipped. |

- Changing `source.uri` stops playback and loads the new file. On iOS the waveform goes back to placeholder bars until the new one is decoded. See [Platform notes](/guide/platform-notes#changing-the-source) for Android.
- `samples` is resampled to the number of bars, so its length does not have to match. Values above `1` are normalised against the largest value. A value of exactly `0` is drawn at placeholder height (20 % of the bar area), because the bars view treats `0` as "not decoded yet"; use a small positive value such as `0.01` for silence. Setting `samples` back to an empty array starts native decoding. More in [Pre-computed samples](/guide/playback#pre-computed-samples).

## Bars

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `playedBarColor` | `ColorValue` | `#FFFFFF` | Color of the bars left of the playhead. |
| `unplayedBarColor` | `ColorValue` | `rgba(255, 255, 255, 0.5)` | Color of the bars that have not been played yet. |
| `barWidth` | `number` | `3` | Width of each bar. |
| `barGap` | `number` | `2` | Space between bars. |
| `barRadius` | `number` | `barWidth / 2` | Corner radius of each bar. |
| `barCount` | `number` | as many as fit | Fixed number of bars. A value larger than what fits is capped. |

The bar under the playhead is split at the exact pixel: played color on the left, unplayed on the right. See [Styling](/guide/styling#bars) for how the bar area is laid out.

## Container

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `containerBackgroundColor` | `ColorValue` | `#3478F6` | Background of the rounded container. |
| `containerBorderRadius` | `number` | `16` | Corner radius of the container. |
| `showBackground` | `boolean` | `true` | Draw the container background. With `false`, the two props above have no effect. |

## Play button

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `showPlayButton` | `boolean` | `true` | Show the play / pause button. |
| `playButtonColor` | `ColorValue` | `#FFFFFF` | Tint of the play / pause icon and of the loading spinner. |

## Time label

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `showTime` | `boolean` | `true` | Show the time label. |
| `timeColor` | `ColorValue` | `#FFFFFF` | Text color of the time label. |
| `timeMode` | `'count-up' \| 'count-down'` | `'count-up'` | Elapsed time, or time remaining. |

The label uses the `m:ss` format, for example `0:07` or `12:30`. Minutes are not wrapped into hours.

## Speed pill

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `showSpeedControl` | `boolean` | `true` | Show the speed pill. |
| `speedColor` | `ColorValue` | `#FFFFFF` | Text color of the pill. |
| `speedBackgroundColor` | `ColorValue` | `rgba(255, 255, 255, 0.25)` | Background of the pill. |
| `speeds` | `number[]` | `[0.5, 1, 1.5, 2]` | Speeds the pill cycles through. An empty array falls back to the default. |
| `defaultSpeed` | `number` | `1` | Initial speed. |

How the pill picks the next speed, and how `defaultSpeed` interacts with `setSpeed()`, is explained in [Speed and playback](/guide/playback#speed).

## Playback

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `autoPlay` | `boolean` | `false` | Start playing as soon as the source is ready. Ignored when `playing` is set. |
| `initialPositionMs` | `number` | `0` | Seek to this position (milliseconds) when the source is ready. |
| `loop` | `boolean` | `false` | Start again from the beginning at the end. `onEnd` does not fire while looping. |

`autoPlay` and `initialPositionMs` are read when a source finishes loading. Changing them later affects the next source, not the current one.

## Background

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `playInBackground` | `boolean` | `false` | Keep playing when the app goes to the background. Needs setup on iOS. |
| `ignoreSilentSwitch` | `boolean` | `false` | iOS only. Play even when the Ring / Silent switch is on, by switching the audio session to `.playback` when playback starts. |
| `pauseUiUpdatesInBackground` | `boolean` | `true` | Skip bar and time label refreshes while in the background. `onTimeUpdate` keeps firing. |

See [Background playback](/guide/background-playback) for the required iOS capability, the optional Android `WAKE_LOCK` permission and Expo config.

## Controlled props

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `playing` | `boolean` | | When set, the component is controlled: taps on the play button only request a change through `onPlayerStateChange`. |
| `speed` | `number` | | When set, taps on the speed pill only request a change through `onPlayerStateChange`. |

Leaving them `undefined` keeps the component uncontrolled. The two are independent, so you can control `playing` and leave the speed to the pill. See [Controlled mode](/guide/playback#controlled-mode).

## Events

| Prop | Payload |
| --- | --- |
| `onLoad` | `{ durationMs }` |
| `onLoadError` | `{ message }` |
| `onPlayerStateChange` | `{ state, isPlaying, speed, error? }` |
| `onTimeUpdate` | `{ currentTimeMs, durationMs }` |
| `onSeek` | `{ positionMs }` |
| `onEnd` | none |

When each one fires is described in [Events](/guide/events).
