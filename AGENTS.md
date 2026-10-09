# Agent guide

Short, opinionated guide for AI coding agents (and new humans) working on
this repo. Read this before making changes.

If anything here disagrees with [ARCHITECTURE.md](./ARCHITECTURE.md) or
[LESSONS_LEARNED.md](./LESSONS_LEARNED.md), those win — this file is the
quick-reference, they're the deep-dive.

## What this project is

A native React Native Fabric component that renders a voice-note style UI
(play / pause button, animated waveform, time label, speed pill) for any
local or remote audio file. Swift on iOS, Kotlin on Android. **No JS in
the playback or rendering hot path.**

Public component: `<AudioWaveformView />` from `react-native-waveform-player`.

## Read these first

1. [ARCHITECTURE.md](./ARCHITECTURE.md) — how the pieces fit together,
   data flow for prop / event / command, where state lives.
2. [LESSONS_LEARNED.md](./LESSONS_LEARNED.md) — bugs we hit and what we
   learned. Many of them have subtle traps you'd reintroduce if you don't
   know about them.
3. The docs site in [`docs/`](./docs): public API surface (props,
   events, ref methods) in `docs/guide/props.md`, `events.md` and
   `ref-methods.md`. The README is a short overview that links there.
4. [CONTRIBUTING.md](./CONTRIBUTING.md) — dev workflow specifics
   (running the example app, opening native projects in Xcode / Android
   Studio).

## Project structure

```
src/                     ← JS / TS layer
  AudioWaveformViewNativeComponent.ts   ← codegen spec (source of truth)
  AudioWaveformView.native.tsx          ← public component, native side
  AudioWaveformView.tsx                 ← non-native stub (throws)
  types.ts                              ← public types + TSDoc (single source)
  index.tsx                             ← public exports
ios/                     ← Swift + Obj-C++
android/src/main/...     ← Kotlin
example/                 ← Yarn workspace; example app for manual testing
docs/                    ← Yarn workspace; VitePress + TypeDoc docs site
demo/                    ← screenshots used in the README and the docs
```

## Commands you will need

All commands are Yarn. Node `>= 22.11.0` (see `.nvmrc`).

| Command | What it does |
|---|---|
| `yarn install` | Install + (re)generate the lockfile. **Run after every `package.json` change.** |
| `yarn typecheck` | `tsc` against the strict-api conditions. Must pass. |
| `yarn lint` | ESLint + Prettier. `--fix` is fine. |
| `yarn prepare` | Run `react-native-builder-bob` to produce `lib/`. |
| `yarn example start` | Metro for the example app. |
| `yarn example ios` | Run the example on iOS (you must `cd example/ios && pod install` first if native code changed). |
| `yarn example android` | Run the example on Android. |
| `yarn clean` | Wipe all build artefacts (`lib/`, native build dirs). |
| `yarn docs:dev` | Docs site dev server (regenerates the API reference first). |
| `yarn docs:build` | Build the docs site to `docs/.vitepress/dist`. Fails on dead links. |

`pre-commit` (via `lefthook`) runs `eslint` on staged JS/TS files and
`tsc` over the whole project, plus `commitlint` on the message.

## Code conventions

### Comments

- Comments explain **why**, not **what**. A comment that paraphrases the
  code below it is noise — delete it.
- The exception is design notes that document a non-obvious trade-off
  ("we set isPlaying *before* isLoading to avoid a crossfade flash").
  Keep those. They're the institutional memory.

### Style

- TypeScript: 2-space indent, single quotes, trailing commas, no
  semicolons missing. `prettier` enforces; just run `--fix`.
- Swift: standard 4-space indent. Mark Fabric-bridged properties with
  `public var ... { didSet { ... } }`. Use `@objc` only when the
  Obj-C++ shim or selector targets need to see it.
- Kotlin: standard 4-space indent. Custom-getter / custom-setter
  properties for prop reactivity (matches the Swift `didSet` pattern).
  Avoid AppCompat dependencies — use the platform-baseline `View` /
  `TextView` / `ImageView`.

### Don't

- **Don't add emojis** to source, comments, or commit messages.
- **Don't add new runtime dependencies** without a strong reason.
  We deliberately avoid `react-native-gesture-handler` / Reanimated /
  `react-native-svg` / etc. Custom gestures and drawing are native.
- **Don't move the codegen spec** out of `src/AudioWaveformViewNativeComponent.ts`. RN's codegen relies on the path + file naming.
- **Don't deep-import codegen types** from
  `react-native/Libraries/...`, and don't use qualified
  `CodegenTypes.X` names in the spec either. Import the bare names
  (`Int32`, `Float`, `WithDefault`, `DirectEventHandler`) from
  `src/codegenTypes.ts`, which aliases them off the `CodegenTypes`
  namespace. That keeps `tsc` on the strict-api surface and keeps
  codegen working on RN < 0.80. See Lessons #1 and #23.

## Where to make changes

A reference cheat sheet — see [ARCHITECTURE.md → Adding things](./ARCHITECTURE.md#adding-things--quick-checklists)
for the full "add a prop / event / command" walkthroughs.

| You want to… | Touch these files |
|---|---|
| Add a prop | `src/AudioWaveformViewNativeComponent.ts`, `src/types.ts` (`AudioWaveformViewProps` + TSDoc), `src/AudioWaveformView.native.tsx`, `ios/AudioWaveformViewImpl.swift`, `ios/AudioWaveformView.mm` (`updateProps`), `android/.../AudioWaveformView.kt`, `android/.../AudioWaveformViewManager.kt`, `docs/guide/props.md` (en, vi, zh) |
| Add an event | codegen spec (payload + `DirectEventHandler`), `src/types.ts` (payload type, callback prop + TSDoc), `AudioWaveformView.native.tsx` (unwrap), `ios/AudioWaveformView.mm` (`emitOn*`), `ios/AudioWaveformViewImpl.swift` (the closure), `android/.../AudioWaveformView.kt` (the closure), `android/.../AudioWaveformViewManager.kt` (`wireEvents`), `docs/guide/events.md` (en, vi, zh) |
| Add a command | codegen spec (`NativeCommands` + `supportedCommands`), `AudioWaveformView.native.tsx` (`useImperativeHandle`), `ios/AudioWaveformView.mm` (`handleCommand:`), `ios/AudioWaveformViewImpl.swift` (the impl), `android/.../AudioWaveformView.kt` + `…ViewManager.kt`, `AudioWaveformViewRef` + TSDoc in `src/types.ts`, `docs/guide/ref-methods.md` (en, vi, zh) |
| Change audio behaviour (state, play/pause, seek, rate) | `ios/AudioPlayerEngine.swift` and `android/.../AudioPlayerEngine.kt`. Keep the two in lockstep. |
| Change waveform decoding | `ios/WaveformDecoder.swift` and `android/.../WaveformDecoder.kt`. Both emit progressive partials in the same shape. |
| Change bar rendering | `ios/WaveformBarsView.swift` and `android/.../WaveformBarsView.kt`. |
| Change loading / play-button UX | `ios/PlayPauseButton.swift` and `android/.../PlayPauseButton.kt`. |

## Critical invariants — don't break these

- **Engine is the single source of truth** for `state`, `isPlaying`,
  `currentMs`, `durationMs`, `rate`. The view layer reads these; it does
  not duplicate them.
- **`pendingStart` lives in the engine**, not the view. Anything that
  wants "start when ready" calls `engine.play()` and lets the engine
  queue if `state == .loading`. Don't add a parallel queue at the view
  layer ([Lesson #7](./LESSONS_LEARNED.md)).
- **Callbacks are main-thread.** Decoders use background queues
  internally; they marshal back to main before invoking any callback.
- **Order of `playButton.isPlaying` / `playButton.isLoading` matters.**
  Set `isPlaying` first, then `isLoading`. Reversing it reintroduces
  the crossfade flash ([Lesson #8](./LESSONS_LEARNED.md)).
- **Sentinels are single-source.** `controlledPlaying = -1` / `controlledSpeed = -1` mean "uncontrolled." Translation between TS optional and sentinel happens **once**, in `AudioWaveformView.native.tsx`. Don't retranslate in native.
- **Fabric view recycling on iOS.** `prepareForRecycle` calls
  `tearDown()`. If you add a new system resource (timer, observer,
  network task) to `AudioWaveformViewImpl`, also reset it in `tearDown()`
  ([Lesson #11](./LESSONS_LEARNED.md)).
- **Codegen `customConditions`.** Keep the strict-api flag in
  `tsconfig.json` and import codegen types through `src/codegenTypes.ts`
  ([Lessons #1 and #23](./LESSONS_LEARNED.md)).
- **`AVAudioSession` is touched at play time only.** Never configure or
  activate it from a prop setter or on mount; that interrupts other
  apps' audio just by rendering a player ([Lesson #24](./LESSONS_LEARNED.md)).
- **AVPlayer + URLSession are bandwidth rivals.** Don't kick off the
  waveform decoder in parallel with the engine's initial fetch — defer
  it to `engine.onLoad` ([Lesson #6](./LESSONS_LEARNED.md)).

## Before you start coding — scan LESSONS_LEARNED

This is the single most important habit for this repo.
[LESSONS_LEARNED.md](./LESSONS_LEARNED.md) has 24 numbered entries
describing the exact bugs we hit and how we fixed them. **Before you
modify any subsystem, do a quick keyword search in that file** for
the area you're touching:

- Touching codegen / TS types → check entries 1–3 and 23.
- Touching iOS playback / loading / gestures / audio session → check 4–12 and 24.
- Touching Android playback / lifecycle / gestures → check 13–17.
- Touching UX (controlled mode, loading state, background) → 18–21.

If a lesson applies to your change, follow its takeaway. If your
change reintroduces a problem listed there, you've almost certainly
broken an invariant. Stop and rethink.

## Verification before declaring "done"

For any change beyond a doc edit:

1. `yarn typecheck` — must pass cleanly.
2. `yarn lint` — must pass cleanly (run `--fix` first if there are
   prettier complaints).
3. **Native build**, when you change `ios/` or `android/` or the
   codegen spec:
   - iOS: `cd example/ios && pod install` regenerates the codegen
     C++ output. Then run the example app from Xcode or
     `yarn example ios` to confirm it builds + behaves.
   - Android: `yarn example android` (Gradle will run codegen
     automatically).
4. Manually exercise the change against the demos in
   `example/src/App.tsx`. Add a new demo card if you've added a new
   prop / mode worth showcasing.
5. **Re-scan [LESSONS_LEARNED.md](./LESSONS_LEARNED.md)** for the
   subsystem you touched. Make sure your change doesn't reintroduce
   a fixed bug. If you fixed a new class of bug worth remembering,
   add a 22nd entry to that file.

There is currently **no automated test suite**. Manual testing in the
example app is the canonical "did this regress anything" check.

## Documentation site

`docs/` is a VitePress site published to GitHub Pages by
`.github/workflows/docs.yml` on every push to `master`, at
https://maitrungduc1410.github.io/react-native-waveform-player/.

- Guide pages live in `docs/guide/` (English), `docs/vi/guide/` and
  `docs/zh/guide/`. Keep the three locales in step: same pages, same
  headings with the English `{#slug}` ids, so links and anchors match.
- `docs/api/` is generated by TypeDoc from `src/index.tsx` and is
  gitignored. Public types live in `src/types.ts`, so the TSDoc comments
  there are what the API reference shows. Write defaults inline ("Defaults to `x`."), because
  the generated tables drop `@defaultValue`.
- The browser playground (`docs/.vitepress/theme/components/`) is a web
  approximation of the native view. If you change the layout, defaults
  or behaviour natively, update it too.
- Every claim in the guide should match the native code. When a
  behaviour changes, search the guide for it in all three locales.

## When you get stuck

- Comments in the source files are usually the best documentation —
  many decisions are explained inline next to the code that implements
  them.
- For "why does the loading flow look like this," see
  [ARCHITECTURE.md → Sequencing & loading UX](./ARCHITECTURE.md#sequencing--loading-ux).
- For "why doesn't this obvious thing work," scan
  [LESSONS_LEARNED.md](./LESSONS_LEARNED.md) — there's a decent chance
  someone has already hit it.

## Tone for commit messages

`commitlint` enforces conventional commits, so messages look like:

```
fix(ios): clear pendingStart on source change
feat(android): wire pauseUiUpdatesInBackground
docs: add ARCHITECTURE.md
```

Short subject, no period, present tense. The body (optional) explains
*why*, not *what*. Same rule as comments.
