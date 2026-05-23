# Lessons learned

A field journal of the bugs, surprises, and design dead-ends we hit while
building this library — and what we'd do differently next time. Skim it
before the next round of changes; most of these will save you a half-day.

Each entry follows the same shape:

- **Symptom** — what we saw / how the bug surfaced.
- **Root cause** — what was actually going on.
- **Fix** — what we changed.
- **Takeaway** — the rule we'd write on the whiteboard.

## Codegen / TypeScript / RN tooling

### 1. `TS2307: Cannot find module '…/CodegenTypesNamespace'`

**Symptom.** Codegen failed at iOS pod install with
`Unable to determine event arguments for "onLoad"`, and TypeScript blew
up importing `DirectEventHandler` / `WithDefault` types.

**Root cause.** The library's `tsconfig.json` sets
`customConditions: ["react-native-strict-api"]`. Codegen's TS resolver
respects those conditions, and the strict-api entry point doesn't
re-export the codegen type namespace under its old paths.

**Fix.** In `AudioWaveformViewNativeComponent.ts`, import `CodegenTypes`
as a namespace from `react-native` and use qualified names everywhere:

```ts
import { type CodegenTypes } from 'react-native';

durationMs: CodegenTypes.Int32;
onLoad?: CodegenTypes.DirectEventHandler<OnLoadEvent>;
barWidth?: CodegenTypes.WithDefault<CodegenTypes.Float, 3.0>;
```

**Takeaway.** When you set `customConditions`, every codegen type import
has to flow through the namespaced surface. Don't deep-import codegen
types from `react-native/Libraries/...` — that path bypasses the
condition resolver.

### 2. `forwardRef` mismatch between native and non-native stubs

**Symptom.** `example/src/App.tsx` complained that `ref` doesn't exist
on `AudioWaveformView` after we added `forwardRef` only to the native
implementation.

**Root cause.** The package has two component files:
`AudioWaveformView.native.tsx` (loaded on iOS/Android by RN's platform
extension resolver) and `AudioWaveformView.tsx` (the web/Node stub used
for TypeScript). They have to expose the same component shape, otherwise
the type resolver picks the stub on `tsc` and complains.

**Fix.** Made the stub a `forwardRef` too, even though it just throws.

**Takeaway.** Whenever you change the public component's shape on
`.native.tsx`, mirror it on the plain `.tsx` stub. Add a comment up top
saying "this only exists for type parity with the native module."

### 3. Yarn lockfile blocked typecheck after rename

**Symptom.** `yarn typecheck` exploded with
`Internal Error: Package for react-native-waveform-player@workspace:. not found in the project`.

**Root cause.** The lockfile pinned the old workspace name. When you
rename a workspace, `yarn install` has to regenerate the resolution
table.

**Fix.** Ran `yarn install`. Done.

**Takeaway.** Renaming a workspace? Always follow up with
`yarn install` (or `npm install`) before running anything else.

## iOS

### 4. `AVAssetReader` cannot decode remote URLs

**Symptom.** Waveform decode silently failed for any `https://` source.

**Root cause.** `AVAssetReader` only works on local files. `AVURLAsset`
will *load* a remote URL but the reader can't pull samples out of it.

**Fix.** For remote URLs, `WaveformDecoder.swift` first downloads via
`URLSession.shared.downloadTask`, then runs `decodeLocalFile(...)`
on the staged temp file.

**Takeaway.** "AVURLAsset accepts the URL" is not the same as
"AVAssetReader can read from it." Local files only for the reader.

### 5. `AVURLAsset` couldn't identify the codec for Google Drive URLs

**Symptom.** Decode would download the file fine, then `track(withMediaType: .audio)` came back nil.

**Root cause.** `AVURLAsset` uses the file extension to identify the
codec. Google Drive download links look like
`/download?id=...&export=download` — no extension at all.

**Fix.** `WaveformDecoder.audioFileExtension(from:)` walks
`response.suggestedFilename` → MIME type → URL path extension → `m4a`
fallback, then writes the temp file with that extension before handing
it to `AVURLAsset`.

**Takeaway.** AVFoundation cares about file extensions, not MIME types.
When you stage downloaded media, give it a sensible extension or
nothing will decode.

### 6. Spinner stayed on for 5–10 seconds even though the waveform was already painted

**Symptom.** On a slow network, the bars view was visibly progressively
filling in (so decode was working), but the play-button spinner refused
to clear for ages.

**Root cause.** Two things compounded:

1. `AVPlayer`'s default `automaticallyWaitsToMinimizeStalling = true`
   makes it wait for a generous forward buffer before flipping
   `.readyToPlay`. On slow networks this can add many seconds even after
   enough data has arrived to start playback.
2. The waveform decoder's `URLSession.downloadTask` and `AVPlayer`'s
   streaming were running on the same HTTP connection at the same
   time, fighting each other for bandwidth. By the time the URLSession
   download finished (and the bars started painting), `AVPlayer` was
   still stalled on its initial buffer.

**Fix.**
- `AudioPlayerEngine.swift`: set
  `player.automaticallyWaitsToMinimizeStalling = false` in `init()`.
- `AudioWaveformViewImpl.swift`: deferred `decodeAmplitudesIfPossible()`
  from `applySource` to `engine.onLoad`, so `AVPlayer` gets undivided
  bandwidth during its initial buffer fetch.

**Takeaway.** When two subsystems share a network pipe, sequence them
or they will starve each other. Specifically for AVPlayer, default
buffering is conservative — opt into eager mode for short voice-note
content.

### 7. Tap on play during loading was silently dropped

**Symptom.** User taps play while the spinner is still showing → nothing
happens. Even when the engine becomes ready a second later, you have to
tap again.

**Root cause.** The naive engine `play()` early-returned when
`state == .loading`, with no record of the user's intent.

**Fix.** Added a `pendingStart` flag inside `AudioPlayerEngine`. `play()`
during `.loading` sets `pendingStart = true` and returns *without
firing `onStateChange`* (so the spinner stays). The state setter applies
the pending start atomically the moment it transitions to `.ready`,
firing one combined notification. Cleared on `pause()` / `reset()` /
new `setSource()`.

**Takeaway.** "Async resource not ready" buttons should queue intent,
not drop it. And queue it close to the resource (in the engine), not
in the view layer — that way every entry path (uncontrolled tap,
controlled prop, autoPlay) gets the behaviour for free.

### 8. Spinner→pause icon flicker at the end of loading

**Symptom.** When a queued tap finally fired, the spinner cleared,
revealed the play icon for one frame, then crossfaded to pause — visible
flash.

**Root cause.** `handleEngineStateChange` was setting `playButton.isLoading = false` *before* `playButton.isPlaying = true`. So the imageView became visible (with the stale "play" icon) before its image was updated, and the play→pause transition then ran with the 0.12 s `UIView.transition` crossfade.

**Fix.** Update `isPlaying` *first* (while the spinner still hides the
imageView — the icon swap is invisible), then drop `isLoading = false`.
The imageView reveals already pointing at the right icon, no crossfade
needed. `PlayPauseButton.swift` skips the crossfade animation when
`isLoading` is still true at the moment `isPlaying` changes.

**Takeaway.** Order of two state-affecting writes matters when one is
"hide a cover" and the other is "swap the thing under the cover."
Always swap first, then uncover.

### 9. Drag inside a parent `ScrollView` got cancelled

**Symptom.** Putting the component inside a vertical `ScrollView` (a
chat list, basically) made horizontal scrub gestures get cancelled the
moment the user moved more than a few pixels.

**Root cause.** `UIScrollView`'s pan recogniser is hungry. Plain
`touchesBegan/Moved/Ended` will be cancelled by the scroll view as
soon as it decides the user is doing a real pan.

**Fix.** Replaced manual touch handling with a
`UILongPressGestureRecognizer` configured with
`minimumPressDuration = 0`. Long-press recognisers claim the touch
sequence on `.began`, which prevents the scroll view from stealing
it. Zero press duration means it fires immediately.

**Takeaway.** Reach for a gesture recogniser whenever you want to win
arbitration against a parent `UIScrollView`. `touchesBegan` is fine in
isolation but loses every fight with parent gesture recognisers.

### 10. Play/pause icon went stale after imperative `pause()`

**Symptom.** Calling `ref.current.pause()` paused the audio fine but
the icon stayed showing "pause" until the next play.

**Root cause.** The icon was being refreshed only by the periodic
display-link tick that we use for the bars view's progress fraction.
The display link stops the moment we pause, so the final tick (with
`isPlaying = false`) never ran.

**Fix.** `handleEngineStateChange` explicitly sets
`playButton.isPlaying = engine.isPlaying` on every state transition,
not just from the display-link tick.

**Takeaway.** If a UI element reflects state, refresh it from the
authoritative state-change callback, not from a coalesced render
loop. The render loop is for things that need to change continuously
(progress fraction); discrete things should snap.

### 11. Fabric kept the AVPlayer alive after unmount

**Symptom.** Unmount the component, audio kept playing in the background.

**Root cause.** Fabric pools component views — `AudioWaveformView` (the
Obj-C++ shim) doesn't get deallocated when React unmounts; it goes
back into a recycler pool. The Swift `AudioWaveformViewImpl` it owns
stays alive too, with its `AVPlayer` happily playing.

**Fix.** Override `prepareForRecycle` in `AudioWaveformView.mm` and
call `AudioWaveformViewImpl.tearDown()`. `tearDown()` resets the
source to `""` (which runs through the regular reset path: cancel
decoder, reset engine, stop display link) and clears every other
piece of bookkeeping state so the recycled view is indistinguishable
from a freshly allocated one.

**Takeaway.** Any Fabric component that owns a system resource (audio
player, video player, location manager, network connection) needs an
explicit `prepareForRecycle` teardown. Don't trust unmount.

### 12. AVPlayer.rate leaked across item swaps → recycled view auto-played the next source

**Symptom.** After the `prepareForRecycle` fix landed (#11), an unmount
mount-cycle bug surfaced in the example app: play → unmount → mount again
with the same `source`, and the new player **started playing immediately**
(audible in the foreground, kept playing in background with
`playInBackground=true`). At the same time the play/pause button still
showed the **"play" icon** as if paused. Engine state and AVPlayer were
out of sync, and `ref.current?.pause()` from the JS-side cleanup didn't
help.

**Root cause.** `AVPlayer.rate` is **orthogonal to the current item** —
it survives `replaceCurrentItem(with:)`. Our `engine.reset()` was
clearing the item but not the rate, so:

1. Tap play → `startPlaybackInternal()` sets `player.rate = 1.0`.
2. Unmount → `engine.reset()` → `replaceCurrentItem(with: nil)`. Item
   gone, our `isPlaying` flag flipped to `false`, **but `player.rate`
   was still `1.0`**.
3. Remount → `engine.setSource(url)` → `replaceCurrentItem(with: newItem)`.
   From Apple's own docs: *"the new player item begins playing at the
   current rate. If the player is in a paused state, the new player
   item is paused as well."* Rate was non-zero → AVPlayer kicked the
   new item into playback the moment its status flipped to
   `.readyToPlay`.

Compounded by our `automaticallyWaitsToMinimizeStalling = false`
opt-in from #6 — that made `.readyToPlay` fire almost immediately, so
the auto-resume was instant. Engine bookkeeping said `isPlaying = false`
(button showed "play" icon) while AVPlayer was happily playing the new
item.

Android doesn't have this bug because `engine.reset()` over there calls
`MediaPlayer.release()` and the next `setSource` builds a fresh
`MediaPlayer` — no shared instance whose orthogonal state can leak.

**Fix.** Two explicit `player.pause()` calls in
`AudioPlayerEngine.swift`:

- In `reset()`, **before** `replaceCurrentItem(with: nil)` — so a
  recycled view's underlying `AVPlayer` starts the next mount with
  `rate = 0`.
- In `setSource(url:)`, **before** `replaceCurrentItem(with: item)` —
  defence in depth, so a `source` prop swap mid-playback also lands in a
  deterministic paused state and waits for an explicit
  `play()` / `autoPlay` / controlled `playing={true}` to resume.

Also reset `rate = 1.0` in `reset()` for symmetry with Android, and
`speedPill.setSpeed(1.0)` in `tearDown()` so the pill doesn't flash a
stale "2.0x" between unmount and the next mount's `defaultSpeed`
re-application.

**Takeaway.** When you hand a long-lived native object back for reuse,
**every field the OS treats as orthogonal to its current "task" is a
landmine**. AVPlayer has at least three: `rate`, `volume`, and
`actionAtItemEnd`. If your `reset()` doesn't touch them, the next item
silently inherits them — and that's almost never what you want.
Recreating the underlying resource (what Android does) is the
brute-force defence; explicitly nulling each orthogonal field is the
surgical one. Pick one, but don't half-do it.

### 13. Sub-pixel "redraw skipping" optimisation killed real-time highlight

**Symptom.** During playback, the playhead's partial-fill bar didn't
move smoothly — it would update once or twice a second, then pop.

**Root cause.** An early version of `WaveformBarsView` skipped
`setNeedsDisplay()` if the new `progressFraction` produced the same
pixel-rounded value as the previous one. Sounded like a sensible
optimisation, but with `barWidth = 3` the rounded values change
infrequently and the partial-fill is *exactly* what we wanted to
update sub-pixel.

**Fix.** Removed the skip-redraw optimisation. The path is cached
anyway so the actual cost is one `clipRect` + one re-fill — cheap.

**Takeaway.** "Skip if the value didn't change" optimisations are
risky on continuous-update rendering. Profile before adding; remove
if anything looks janky.

## Android

### 14. `eventName` shadowing crashed compile

**Symptom.** `e: AudioWaveformEvent.kt: 'eventName' hides member of supertype 'Event'`.

**Root cause.** Our custom event class declared a constructor parameter
named `eventName`, which collides with the inherited `getEventName()`
on Fabric's `Event` base class.

**Fix.** Renamed the parameter to `name`.

**Takeaway.** When subclassing platform classes (RN, Android, AppCompat),
spell-check your property names against the supertype before pushing.
`Event`, `View`, `Context`, etc. have lots of accessors that look
ordinary.

### 15. Swift-style argument labels in Kotlin

**Symptom.** Kotlin compile error
`'An explicit type is required on a value parameter.'` on
`fun nextSpeed(after current: Float)`.

**Root cause.** Pasted that signature from the Swift side without
realising Kotlin doesn't support argument labels. Kotlin reads
`after` as the parameter name and `current: Float` as a syntax error.

**Fix.** `fun nextSpeed(current: Float)`.

**Takeaway.** When porting Swift APIs to Kotlin (or vice versa), drop
the argument labels — Kotlin uses positional / named-argument-at-call
style instead.

### 16. `WAKE_LOCK` SecurityException came from the wrong call

**Symptom.** With `playInBackground = true` and no `WAKE_LOCK`
permission in the host app manifest, calling `engine.play()` did
nothing — no audio, no error in our code paths.

**Root cause.** We thought `MediaPlayer.setWakeMode(...)` would throw
SecurityException when the permission is missing, so we wrapped it in
a try/catch. Wrong: `setWakeMode` only *registers intent* to acquire a
wake lock. The actual `WakeLock.acquire()` happens later inside
`MediaPlayer.start()`. The SecurityException there was being swallowed
by the `MediaPlayer` internals, leaving us with `isPlaying = true` but
no audio.

**Fix.**
- `applyWakeMode` checks `Manifest.permission.WAKE_LOCK` via
  `context.checkSelfPermission(...)` *before* calling `setWakeMode`,
  and skips it (with a clear `Log.w`) if not granted.
- `play()` also wraps `p.start()` in a try/catch that resets
  `isPlaying = false`, stops the progress loop, and fires
  `onStateChange` if anything throws — so the UI doesn't get stuck.

**Takeaway.** "Where does the exception originate?" matters. Don't
assume the call you're protecting is the one that throws — read the
docs or the source. And `start()` is the public play entry point on
both platforms; harden it against any throw, not just the obvious ones.

### 17. `return@onTimeUpdate` was an unresolved label

**Symptom.** `e: ... Unresolved label` in `AudioWaveformView.kt`.

**Root cause.** `onTimeUpdate` is a property holding a lambda, not an
inline function — the implicit-label-from-call-site rule that lets
you write `return@inlineFunc` inside `forEach { ... }` doesn't apply.
The call site is `engine.onTimeUpdate = { … }`, and the lambda label
is `engine` (or whatever variable receives it), not `onTimeUpdate`.

**Fix.** Restructured the conditional to use an `if (!cond) { ... }`
block instead of an early return.

**Takeaway.** `return@<label>` only works for inline-function lambdas.
When you're assigning a lambda to a property, refactor the early-return
into structured `if` instead.

### 18. ScrollView intercepted horizontal drag (Android equivalent of #9)

**Symptom.** Same as iOS — drag inside a parent `ScrollView` got
cancelled.

**Fix.** Call `parent.requestDisallowInterceptTouchEvent(true)` on
`ACTION_DOWN`. Android's equivalent of "claim this touch sequence."

**Takeaway.** Both platforms have a "tell my parent to back off"
escape hatch; reach for it whenever a custom horizontal-drag gesture
lives inside a vertical scroller.

## Cross-platform UX

### 19. Controlled mode initially toggled state on tap before firing the event

**Symptom.** Apps using `playing={...}` saw the audio toggle on tap
even though they hadn't updated their state yet — then the state
caught up and produced a "double toggle" feel.

**Root cause.** Early code path called `engine.toggle()` first, *then*
fired `onPlayerStateChange`. In controlled mode that's wrong: the
component shouldn't mutate state at all, just emit the requested
new value.

**Fix.** Branch on `controlledPlaying != -1` *before* doing anything,
emit the event with `newPlaying = !engine.isPlaying`, and don't touch
the engine.

**Takeaway.** Controlled-component contract: *no internal state
changes on user interaction*. Emit the request, let the parent decide.

### 20. Loading state had no UI signal

**Symptom.** Mount the component → blank waveform area for several
seconds → bars suddenly appear → eventually you can play. No feedback
that anything's happening.

**Fix.**
- `WaveformBarsView` paints **uniform placeholder bars** (constant
  amplitude `0.2`) when no real data is available yet, then animates
  bar heights from placeholder → real over ~200 ms when the first
  amplitudes arrive.
- `WaveformDecoder` emits **progressive partial amplitude arrays**
  during decode (every ~5 % at first, then every ~20 %), so bars fill
  in left-to-right as the file decodes.
- `PlayPauseButton` shows a native spinner
  (`UIActivityIndicatorView` / `ProgressBar`) when
  `engine.state == .loading`.

**Takeaway.** "Empty UI while loading" reads as "broken." Always have
*something* on screen — placeholder, skeleton, spinner — and animate
into the real thing instead of popping.

### 21. Background tick refreshes wasted CPU

**Symptom.** Profile traces showed the 30 Hz progress refresh
keeping a few percent of CPU busy even when the app was backgrounded
and the view wasn't being composited.

**Root cause.** The progress tick on both platforms updated the bars
view's `progressFraction` and the time label string regardless of
whether the view was visible.

**Fix.** Added `pauseUiUpdatesInBackground` (default `true`). When
backgrounded, skip the bars/time-label refresh inside
`engine.onTimeUpdate`. The JS `onTimeUpdate` event keeps firing so
Now Playing / Lock Screen / analytics integrations work the same.
Snap the UI back to current state on `didBecomeActive` / `onHostResume`.

**Takeaway.** Background work is cheap-but-pointless work, multiplied
by 30/sec. When in doubt, gate it behind a lifecycle flag and snap
on resume.

### 22. AVPlayer eager mode + JS event order surprises

**Symptom.** Tests calling `play()` synchronously after mount
sometimes saw `onPlayerStateChange` arrive with `isPlaying = false`
before the "real" `isPlaying = true` event.

**Root cause.** With `automaticallyWaitsToMinimizeStalling = false`,
`AVPlayer` flips `.readyToPlay` very quickly. The state setter fires
`onStateChange` once when transitioning to `.ready`, then `onLoad`
runs, then *if* the user's `onLoad` handler calls `engine.play()`,
that fires another `onStateChange`. JS sees both.

**Fix.** Documented the contract on `onPlayerStateChange`: it's a
*full snapshot* fired on every transition, including load lifecycle.
Made it idempotent — receiving the same state twice in a row is fine,
parents should compare values rather than treating each event as a
delta.

**Takeaway.** When you collapse multiple events into "fire on every
transition," document that consumers should diff against their own
state, not treat each event as a unique edge.

## Things we'd do differently next time

A short list of "if we started over today":

- **Define the codegen TS spec first**, then build the public component
  type from it. Every mismatch we hit started with the public type
  drifting from the spec.
- **Put the `pendingStart` queue in the engine from day one.** We
  initially tried to handle it at the view layer; multiple entry
  points (tap, controlled prop, autoPlay) all needed the same fix.
  Putting it close to the resource was the right call.
- **Treat AVPlayer + URLSession sharing the network as a hazard.** The
  bandwidth-contention bug took an embarrassing amount of time to
  diagnose — the symptom (waveform appearing while spinner stays)
  didn't immediately suggest "two HTTP downloads competing."
- **Run `yarn install` reflexively after any package.json change.**
  Worth its own pre-commit hook honestly.
- **Write a teardown story before writing a mount story** for any
  Fabric component owning a system resource. Forgetting `prepareForRecycle`
  means audio playing inside the recycler pool — really hard to
  reproduce in normal dev because the issue only surfaces under
  rapid mount/unmount cycles.
- **Audit which fields of a long-lived native object survive its
  "current task."** AVPlayer's `rate`, `volume`, and `actionAtItemEnd`
  all persist across `replaceCurrentItem` — and that's how you ship a
  "the new source silently inherits the previous one's playback rate"
  bug (#12). Either explicitly null every orthogonal field in
  `reset()`, or recreate the underlying resource the way Android does.
  Half-measures are worse than either.
