---
description: "When AudioWaveformView fires onLoad, onPlayerStateChange, onTimeUpdate, onSeek, onEnd and onLoadError, what each payload holds and how to handle duplicates."
---

# Events

All events are props on `AudioWaveformView`. Payloads are plain objects; you do not need to read `nativeEvent`.

| Event | Payload | Fires when |
| --- | --- | --- |
| `onLoad` | `{ durationMs }` | The source is ready to play. |
| `onLoadError` | `{ message }` | The source cannot be loaded or played, or its waveform cannot be decoded. |
| `onPlayerStateChange` | `{ state, isPlaying, speed, error? }` | Anything about the playback state changes. Full snapshot. |
| `onTimeUpdate` | `{ currentTimeMs, durationMs }` | About 30 times per second while playing. |
| `onSeek` | `{ positionMs }` | A drag on the waveform ends, or after `seekTo()`. |
| `onEnd` | none | Playback reaches the end and `loop` is off. |

Play, drag and tap the speed pill below to watch the events. The demo is a web approximation: the native component sends the same events with the same payloads, though the number of repeated snapshots can differ.

<WaveformPlayground :controls="false" />

## onPlayerStateChange {#onplayerstatechange}

```ts
type AudioWaveformPlayerStateEvent = {
  state: 'idle' | 'loading' | 'ready' | 'ended' | 'error';
  isPlaying: boolean;
  speed: number;
  error?: string;
};
```

This is a **snapshot**, not a delta. It is sent on every transition: when loading starts, when the source becomes ready, on play and pause, on a speed change, at the end and on errors. The same snapshot can arrive two or three times in a row (for example around `onLoad`), so compare the values with your own state:

```tsx
onPlayerStateChange={(e) => {
  if (e.isPlaying !== playing) setPlaying(e.isPlaying);
  if (e.speed !== speed) setSpeed(e.speed);
}}
```

| `state` | Meaning |
| --- | --- |
| `idle` | No source loaded. |
| `loading` | The native player is opening and buffering the source. The play button shows a spinner. |
| `ready` | The source can play. Check `isPlaying` to know whether it is playing. |
| `ended` | Playback reached the end with `loop` off. Playing again starts from `0`. |
| `error` | The native player failed. |

`error` is filled on the snapshot sent together with `onLoadError` when the player fails. Other snapshots, including the first one in the `error` state, leave it out.

**In controlled mode** (when `playing` or `speed` is set), a tap on the play button or the speed pill does not change playback. Instead, the component sends a snapshot with the **requested** value: `isPlaying` flipped, or `speed` set to the next speed in `speeds`. You apply it by updating your prop. See [Controlled mode](/guide/playback#controlled-mode).

## onLoad {#onload}

Fires once per source, when the native player is ready to play. `durationMs` is the duration in milliseconds, or `0` if the player cannot tell. At this point the component also applies `initialPositionMs` and `autoPlay`, then starts decoding the waveform on iOS (Android starts decoding earlier, see [Platform notes](/guide/platform-notes#waveform-decoding)).

A typical load sends a `loading` snapshot, a `ready` snapshot, `onLoad`, then one or more `ready` snapshots.

## onTimeUpdate {#ontimeupdate}

Fires about 30 times per second while playing, with the position and the duration in milliseconds. It also fires once at the end with `currentTimeMs` equal to `durationMs`.

- It does **not** fire while the user is dragging on the waveform. Use `onSeek` for the final position.
- It **keeps firing in the background** when [background playback](/guide/background-playback) is on, even when `pauseUiUpdatesInBackground` skips the view refreshes. You can use it for your own progress UI or analytics.

The native view updates its own bars and time label, so you do not need this event to animate the component.

## onSeek {#onseek}

Fires with the position in milliseconds:

- when a drag on the waveform ends, including a drag the system cancels,
- after every `seekTo()` call, with the requested position (rounded and clamped to `0` or more). The player itself clamps it to the duration.

It does not fire for `initialPositionMs`.

## onEnd {#onend}

Fires when playback reaches the end and `loop` is off. Around it you also get a last `onTimeUpdate` and `ended` snapshots. With `loop` on, playback jumps back to `0` and keeps going without `onEnd`.

## onLoadError {#onloaderror}

Fires with a native message in two different situations:

1. **The player fails** to open or play the source. The state becomes `error` and the play button stops spinning. Messages come from the platform, for example `AVFoundation` errors on iOS, or `MediaPlayer error: what=1 extra=-1004` and `setDataSource failed: ...` on Android.
2. **The waveform decoder fails**, for example `Audio track not found` on iOS or `No audio track found` on Android. Playback can still work in this case; the bars stay as placeholders. Pass [`samples`](/guide/playback#pre-computed-samples) if your files cannot be decoded on the device.

On iOS, a URI that cannot be parsed as a URL fires `onLoadError` with the URI itself as the message, and nothing else happens.

Show a retry option for case 1. For case 2, logging is usually enough.
