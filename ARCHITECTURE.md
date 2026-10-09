# Architecture

This document explains how `react-native-waveform-player` is put together
internally — how a JS prop change ends up moving a bar on the screen, who owns
which piece of state, and why the design looks the way it does.

It's the doc you want to read before fixing a bug or adding a feature.

## Mental model in 30 seconds

The library is a Fabric component. JS hands the native side a `source` URI plus
a bunch of styling / playback props; the native side runs an audio engine and
draws the UI. There is **no JS in the playback or rendering hot path** — every
~30 Hz progress tick, every drag pixel, every speed change is handled in
Swift / Kotlin.

```
┌─────────────────────────────────────────────────────────────────┐
│  JS layer  (src/)                                               │
│                                                                 │
│   AudioWaveformView (forwardRef)                                │
│       │                                                         │
│       ▼                                                         │
│   AudioWaveformViewNativeComponent.ts   ← codegen spec          │
│       │                                                         │
└───────┼─────────────────────────────────────────────────────────┘
        │  Fabric props / commands / events
        ▼
┌──────────────────────────┐         ┌──────────────────────────┐
│  iOS  (ios/)             │         │  Android  (android/)     │
│                          │         │                          │
│  AudioWaveformView.mm    │         │  AudioWaveformViewManager│
│  (Obj-C++ Fabric shim)   │         │  (Fabric ViewManager)    │
│         │                │         │         │                │
│         ▼                │         │         ▼                │
│  AudioWaveformViewImpl   │         │  AudioWaveformView       │
│  (Swift composite view)  │         │  (Kotlin FrameLayout)    │
│         │                │         │         │                │
│         ├─ AudioPlayerEngine        ├─ AudioPlayerEngine       │
│         ├─ WaveformDecoder          ├─ WaveformDecoder         │
│         ├─ WaveformBarsView         ├─ WaveformBarsView        │
│         ├─ PlayPauseButton          ├─ PlayPauseButton         │
│         └─ SpeedPillView            └─ SpeedPillView           │
└──────────────────────────┘         └──────────────────────────┘
```

Both platforms ship the same five pieces in roughly the same shape: an
**audio engine** that wraps the platform player, a **decoder** that turns
audio samples into amplitude buckets, a **bars view** that draws those
buckets, a **play / pause button**, and a **speed pill**. The composite
view glues them together.

## File layout

### JS (`src/`)

| File | Role |
|---|---|
| `AudioWaveformViewNativeComponent.ts` | Codegen spec — declares props, events, commands. **Source of truth** for the JS↔native interface. |
| `AudioWaveformView.native.tsx` | Public component (`.native.tsx` resolution → loaded on iOS/Android). `forwardRef`, controlled-prop translation, ref imperative API, JS-side event unwrapping. |
| `AudioWaveformView.tsx` | Web/Node fallback that throws on render. Exists so importing the package on non-native platforms doesn't break type-checking. |
| `types.ts` | Public types (props, events, ref) with their TSDoc. Both component files import from here; the API reference is generated from it. |
| `index.tsx` | Public exports. |

### iOS (`ios/`)

| File | Role |
|---|---|
| `AudioWaveformView.h` / `.mm` | Obj-C++ Fabric component view. Bridges C++ codegen types ↔ Swift impl. Owns `prepareForRecycle`. |
| `AudioWaveformViewImpl.swift` | The composite Swift view. Owns subviews, engine, decoder, lifecycle observers, gesture state. ~830 lines, the "main" file. |
| `AudioPlayerEngine.swift` | Wraps `AVPlayer`. State machine (`idle / loading / ready / ended / error`), pending-start queue, KVO + time observer + end-of-item listener. |
| `WaveformDecoder.swift` | URL → amplitudes. Downloads remote URLs first (AVAssetReader can't read them), then decodes with bucket-by-time accumulation. Emits progressive partial arrays. |
| `WaveformBarsView.swift` | UIView that draws the bars + the partial-fill playhead. Animated bar growth via `CADisplayLink`. Hosts the scrub gesture recogniser. |
| `PlayPauseButton.swift` | UIControl with SF Symbols (`play.fill` / `pause.fill`) and a `UIActivityIndicatorView` for the loading state. |
| `SpeedPillView.swift` | Tap-to-cycle speed pill. |

### Android (`android/src/main/java/com/audiowaveform/`)

| File | Role |
|---|---|
| `AudioWaveformPackage.kt` | RN package entry — registers the view manager. |
| `AudioWaveformViewManager.kt` | Fabric `SimpleViewManager`. Implements the codegen interface (prop setters + commands). Wires the view's callback closures up to `EventDispatcher`. |
| `AudioWaveformEvent.kt` | Generic Fabric `Event` subclass for dispatching custom events. |
| `AudioWaveformView.kt` | Composite `FrameLayout`. Same role as `AudioWaveformViewImpl.swift`. ~700 lines. |
| `AudioPlayerEngine.kt` | Wraps `android.media.MediaPlayer`. Same state machine + pending-start logic as iOS. |
| `WaveformDecoder.kt` | URL → amplitudes via `MediaExtractor` + `MediaCodec`. `MediaExtractor` natively handles HTTP, so no separate download step. |
| `WaveformBarsView.kt` | Custom `View` mirroring the iOS bars view. `ValueAnimator` for bar growth. |
| `PlayPauseButton.kt` | `FrameLayout` wrapping an `ImageView` (vector drawable) and a `ProgressBar` for the loading state. |
| `SpeedPillView.kt` | Custom `TextView` with a `GradientDrawable` rounded background. |

## How a prop / event / command flows

This is the most useful diagram in the doc — keep it open when adding new
ones.

### Prop (e.g. `barWidth`)

```
TS spec (AudioWaveformViewNativeComponent.ts)
        │  declared as `barWidth?: WithDefault<Float, 3.0>`
        ▼
codegen output (auto, in the build)
   ├─ iOS:    AudioWaveformViewProps with `Float barWidth`
   └─ Android: ViewManagerInterface with `setBarWidth(view, value: Float)`
        │
        ▼
iOS: AudioWaveformView.mm  updateProps → _impl.barWidth = …
Android: ViewManager.setBarWidth(view, value) → view.barWidthDp = …
        │
        ▼
Composite view (Swift / Kotlin):
   stores the value, forwards to barsView, calls setNeedsLayout()
```

Sources of truth: codegen TS spec + `updateProps` in the iOS shim + the
`set*` overrides in the Android view manager. Add a prop = touch all three.

### Command (e.g. `play()`)

```
JS:    ref.current.play()
        ▼
AudioWaveformView.native.tsx → Commands.play(nativeRef.current)
        ▼
codegen routes to platform:
   iOS:    AudioWaveformView.mm → handleCommand:@"play" → [_impl play]
   Android: AudioWaveformViewManager.play(view) → view.play()
        ▼
Composite view → engine.play()
```

### Event (e.g. `onTimeUpdate`)

Events flow the other way:

```
engine.onTimeUpdate?.(currentMs, durationMs)
        ▼
Composite view forwards to its `onTimeUpdate` closure
        ▼
iOS: closure stored on _impl, called by .mm → typedEventEmitter()->onTimeUpdate(...)
Android: closure stored on view, called via UIManagerHelper.getEventDispatcherForReactTag(...).dispatchEvent(...)
        ▼
JS: NativeSyntheticEvent → unwrapped in AudioWaveformView.native.tsx → public callback
```

Sources of truth: codegen TS spec (declares the payload shape) +
`AudioWaveformView.mm` (`emitOn*` helpers) + `AudioWaveformViewManager.kt`
(`dispatchEvent`) + `AudioWaveformView.native.tsx` (unwraps `nativeEvent`).

## Subsystems

### AudioPlayerEngine

A thin wrapper that turns the platform player (`AVPlayer` / `MediaPlayer`)
into the API the rest of the component wants: a state machine plus
callbacks. Nothing in the engine knows about React, view hierarchy, or
gestures.

State machine:

```
       setSource()
idle ─────────────► loading
                      │
       readyToPlay /  │  failure
       prepared       │
                      ▼
                    ready ◄──┐
                      │      │
                play()│      │seek to 0 + play()
                      ▼      │
                  (playing)  │
                      │      │
                end-of-item  │loop=true
                      ▼      │
                    ended ───┘
```

Public surface:

- **State**: `state`, `durationMs`, `currentMs`, `isPlaying`, `rate`.
- **Config**: `loop`, `configuresPlaybackSession` (set by the view from
  `playInBackground || ignoreSilentSwitch`; the session itself is
  configured in `startPlaybackInternal()`).
- **Mutation**: `setSource`, `play`, `pause`, `toggle`, `seek(toMs:)`, `setRate`, `reset`.
- **Callbacks**: `onLoad`, `onLoadError`, `onStateChange`, `onTimeUpdate`, `onEnded`.

Two design decisions worth knowing:

1. **`pendingStart` queue.** `play()` called while `state == .loading` does
   not actually start playback — it sets `pendingStart = true` and returns
   without firing any callbacks. The state setter then resumes playback
   *atomically* the moment it transitions to `.ready`, so a single
   `onStateChange` notification reflects the final state (`ready` +
   `isPlaying = true`). This is what eliminates the brief play-icon flash
   you'd otherwise see when a tap-during-loading "comes through".

2. **`isPlaying` is set after the platform call succeeds.** On Android,
   `MediaPlayer.start()` can throw `SecurityException` (e.g. wake-lock
   acquisition) — we don't want to leave the play/pause icon stuck on
   "pause" with no audio. iOS does the equivalent.

### WaveformDecoder

Turns a URL into a normalised array of per-bar RMS amplitudes in `[0, 1]`.
Both platforms emit progressive partial results (see "loading UX" below)
so the bars view can paint as the decode runs.

The two implementations diverge in one important place:

| | iOS | Android |
|---|---|---|
| Local file | `AVAssetReader` reads PCM samples | `MediaExtractor` + `MediaCodec` decodes to PCM |
| Remote URL | **Pre-download via `URLSession.downloadTask`**, then decode the local file | `MediaExtractor` natively streams HTTP — no separate download |

The iOS pre-download is forced because `AVAssetReader` can't read remote
URLs. The library also makes the download wait until `engine.onLoad` fires
(see [Sequencing](#sequencing--loading-ux) below).

Bucket-by-time accumulation:

- Each bar represents a fixed time window (`totalDurationUs / barCount`).
- For every PCM sample we compute its presentation time, find the bar it
  falls into, and accumulate `sumSquares[bar] += sample²` and
  `sampleCounts[bar] += 1`.
- At the end (and periodically along the way) we compute
  `rms = sqrt(sumSquares / sampleCount)` per bar and normalise the whole
  array to `[0, 1]` against the loudest bar.

This is more accurate than the sample-count-bucketing approach (which
biases short clips when the bar count doesn't divide evenly into total
samples).

Cancellation is token-based (a `UUID`/counter): the next `decode()` call
just bumps the token, so any in-flight closures from the old decode become
no-ops on completion.

### WaveformBarsView

Draws the bars and the partial-fill playhead. Owns the scrub gesture too.

Key state:

```
amplitudes:        the latest target amplitude array
displayedAmps:     what's currently being drawn (interpolated)
startAmps          ┐ animation source/target — fed into a
targetAmps         ┘ CADisplayLink (iOS) / ValueAnimator (Android)
progressFraction:  0..1, set by the composite view from engine.currentMs / durationMs
```

Two-pass render with clipping, so the bar straddling the playhead is
filled "played" up to the exact pixel and "unplayed" after that:

1. Set fill = `unplayedBarColor`, draw the full bar path.
2. Clip to `(0, 0, progressFraction × width, height)`, set fill = `playedBarColor`, draw the same path.

When `displayedAmps` is empty (no decode result yet) the view paints
**uniform placeholder bars** at a `placeholderAmplitude` constant. Once
the first amplitude payload arrives we animate from placeholder → real
amplitudes over ~200ms with an ease-out curve.

Gesture handling:

- **iOS**: a `UILongPressGestureRecognizer` with `minimumPressDuration = 0`. Subclassed only because `touchesBegan/Moved/Ended` get cancelled the moment a parent `UIScrollView` decides the user is doing a horizontal scroll. The gesture recogniser claims the touch first.
- **Android**: a `MotionEvent`-based handler that calls `parent.requestDisallowInterceptTouchEvent(true)` on `ACTION_DOWN`.

Both forward `onScrubBegan` / `onScrubMoved` / `onScrubEnded(cancelled)`
closures back to the composite view, which performs the actual seek and
restores the play state.

### PlayPauseButton

A `UIControl` (iOS) / `FrameLayout` (Android) with three observable
properties:

- `isPlaying: Bool` — chooses the icon (`play.fill` vs `pause.fill` on iOS,
  `R.drawable.play_fill` vs `pause_fill` on Android).
- `isLoading: Bool` — when true, hide the icon and show a native
  `UIActivityIndicatorView` / `ProgressBar`.
- `iconColor` — tints both the icon and the spinner.

The composite view sets `isPlaying` *before* `isLoading` on every state
change so that during a loading→ready transition with a queued tap, the
imageView is already pointing at the pause icon under the spinner — when
the spinner clears you go straight to the right icon, no crossfade flash.

### SpeedPillView

Cosmetic only. Renders a rounded background + the speed text (e.g.
`"1.5x"`). Tap → `onTap` closure → composite view picks the next speed
from the `speeds` array and applies it.

## Sequencing & loading UX

The trickiest part of the library is the order things happen during load.
Two key constraints drove the current design:

1. **AVPlayer should get the network undivided** during its initial
   buffer fetch — bandwidth contention with the waveform decoder was
   leaving the spinner on screen for many seconds even after the
   waveform itself had appeared.
2. **The user should be able to tap "play" before the engine is ready**
   without their tap getting silently dropped.

Resulting flow on `applySource(url)`:

```
applySource(url):
   1. clear stale amplitudes  →  bars view falls back to placeholder bars
   2. cancel any in-flight decode
   3. engine.setSource(url)   →  state = .loading, KVO/listeners attached
   4. emitPlayerState()
   5. (intentionally do NOT start the waveform decoder here)

… user might tap play here …
   handlePlayButtonTap → engine.toggle() → engine.play()
       sees state = .loading → pendingStart = true, return without callback

… AVPlayer finishes its initial buffer …
   item.status → .readyToPlay (iOS) / onPrepared (Android)
        ▼
   engine.state = .ready
        │  (state setter checks pendingStart, runs startPlaybackInternal
        │   atomically before firing onStateChange)
        ▼
   handleEngineStateChange:
        playButton.isPlaying = engine.isPlaying   ← already true if pendingStart
        playButton.isLoading = false
        ▼
   engine.onLoad fires:
        apply initialPositionMs
        autoPlay / controlled-state fallback
        kick off decoder.decode(url)               ← finally
        ▼
   decoder progressively emits amplitudes → bars view animates them in
```

Side effects of this design you should be aware of when modifying:

- `applySource` does **not** call `decodeAmplitudesIfPossible` anymore.
  The decode kick-off lives in `engine.onLoad`. Don't move it back without
  reading the comments in `applySource`.
- `applyProvidedSamples` (the `samples` prop path) bypasses the decoder
  entirely.
- For local files (`file://`) the engine becomes ready in a few ms, so
  the deferral has zero perceptible cost.

## Controlled vs uncontrolled

The `playing?: boolean` and `speed?: number` props translate into native
sentinel ints/floats:

- `controlledPlaying: -1` = uncontrolled (default), `0` = paused, `1` = playing.
- `controlledSpeed: -1` = uncontrolled, otherwise the actual rate.

Native code branches on the sentinel:

- **Uncontrolled** — taps mutate internal state and call into the engine.
- **Controlled** — taps fire `onPlayerStateChange` with the *requested*
  new value but don't mutate state. The parent app updates its prop and
  the change comes back in via `applyControlledState`.

Sentinels live in the codegen spec
(`AudioWaveformViewNativeComponent.ts`). The conversion happens once in
`AudioWaveformView.native.tsx` (`useMemo`). Keep that one place as the
single point where TS optionality becomes a sentinel — don't translate
in the native layer.

## Threading

- All callbacks (engine + decoder) fire on the **main thread**. The
  decoder does its sample-crunching on a background queue and dispatches
  progress updates back to main.
- The 30 Hz progress tick comes from `AVPlayer.addPeriodicTimeObserver`
  on iOS and a `Handler.postDelayed` loop on Android. Both run on main.
- The waveform repaint that piggy-backs on the progress tick is gated
  by `pauseUiUpdatesInBackground` — the JS `onTimeUpdate` event still
  fires either way (so callers can drive Now Playing / analytics /
  Lock Screen).

## Background lifecycle

Both platforms register lifecycle observers in `commonInit`.

- **App foregrounded → backgrounded**:
  - If `playInBackground == false`, pause the engine.
  - If `playInBackground == true`, leave it alone (and on iOS the engine
    has already activated the playback `AVAudioSession`).
  - Set `isBackgrounded = true`.
- **App backgrounded → foregrounded**:
  - Set `isBackgrounded = false`.
  - **Snap** the bars view + time label + play button icon to
    `engine.currentMs / durationMs / isPlaying` — important because if
    `pauseUiUpdatesInBackground == true` we skipped tick refreshes
    while offscreen.

`pauseUiUpdatesInBackground` only gates the bars/time-label refresh
inside `engine.onTimeUpdate`. It never gates `onTimeUpdate` to JS.

## iOS view recycling

Fabric pools component views and reuses them. Without help, an unmounted
`AudioWaveformView` would keep its `AVPlayer` alive inside the pool and
keep playing audio.

Fix: `AudioWaveformView.mm` overrides `prepareForRecycle` and calls
`AudioWaveformViewImpl.tearDown()`, which:

- Sets `sourceURI = ""` (runs through `applySource` → cancels decoder, resets engine, stops display link).
- Resets `internalPlaying`, `internalSpeed`, `defaultSpeedApplied`,
  `initialPositionApplied`, gesture state, amplitudes, bars view, time
  label, play button, speed pill.

`tearDown()` is idempotent so it's also safe from `deinit`. Android's
`SimpleViewManager` doesn't pool, so the equivalent isn't needed —
`onDetachedFromWindow` already runs the engine reset.

## Where state lives (cheat sheet)

| State | Owner | Notes |
|---|---|---|
| Audio (current/duration ms, isPlaying, rate) | `AudioPlayerEngine` | Single source of truth. Every other piece reads from here. |
| Decoded amplitudes | Composite view (`amplitudes`) | Mirrored into `barsView.amplitudes` for rendering. |
| Internal play / speed (uncontrolled) | Composite view (`internalPlaying`, `internalSpeed`) | Only consulted when `controlledPlaying / controlledSpeed == -1`. |
| `pendingStart` ("queued tap during loading") | `AudioPlayerEngine` | Cleared on pause / reset / source change. |
| Scrub state (`isScrubbing`, `resumeAfterScrub`, `pendingScrubMs`) | Composite view | Set/cleared in the scrub callbacks. |
| `isBackgrounded` | Composite view | Set by lifecycle observers. |
| Loading icon state (`playButton.isLoading`) | `PlayPauseButton`, driven by composite view | `isLoading = (engine.state == .loading)`. |

## Adding things — quick checklists

### A new prop

1. Add it to `src/AudioWaveformViewNativeComponent.ts` (use `WithDefault<...>` if it has a default).
2. Add it to `AudioWaveformViewProps` in `src/types.ts`, with TSDoc.
3. **iOS**: add a stored property on `AudioWaveformViewImpl` (with `didSet` if it triggers UI work), then wire it in `AudioWaveformView.mm`'s `updateProps`.
4. **Android**: add a property on `AudioWaveformView.kt` (with the appropriate setter behaviour), then add `override fun set<Name>(...)` on `AudioWaveformViewManager.kt`.
5. Document it in `docs/guide/props.md` (and the `vi` / `zh` copies).

### A new event

1. Add the payload type + `DirectEventHandler<...>` in the codegen spec.
2. Add the payload type and the callback prop, with TSDoc, in `src/types.ts`, then unwrap `nativeEvent` in `AudioWaveformViewInner` (`AudioWaveformView.native.tsx`).
3. **iOS**: add an `@objc` callback property on `AudioWaveformViewImpl` and an `emitOn<Name>` helper in `AudioWaveformView.mm` that calls `typedEventEmitter()->onWhatever(...)`.
4. **Android**: add a callback closure on `AudioWaveformView.kt` and dispatch via `UIManagerHelper.getEventDispatcherForReactTag(...)` in `AudioWaveformViewManager.wireEvents`.
5. Document it in `docs/guide/events.md` (and the `vi` / `zh` copies).

### A new command

1. Add it to `NativeCommands` + the `supportedCommands` list in the codegen spec.
2. Add a method, with TSDoc, on `AudioWaveformViewRef` in `src/types.ts` and wire it in the `useImperativeHandle` hook.
3. **iOS**: add a `public func` on `AudioWaveformViewImpl` and dispatch from `handleCommand:` in the `.mm`.
4. **Android**: add a `fun` on `AudioWaveformView.kt` and an `override` on `AudioWaveformViewManager`.
5. Document it in `docs/guide/ref-methods.md` (and the `vi` / `zh` copies).

## Out-of-scope, for the avoidance of doubt

- Recording (we play + visualise; we do not record).
- Live / streaming waveforms — we visualise a fixed audio file.
- Hooking into `react-native-gesture-handler` / Reanimated — gestures
  are handled natively for zero JS overhead and we don't want a runtime
  dependency on those libraries.
