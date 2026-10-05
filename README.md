# react-native-waveform-player

Native voice-note player for React Native. Play any local or remote audio file
and render its waveform natively: Swift on iOS, Kotlin on Android, Fabric (New
Architecture) only. Works in bare React Native and in Expo development builds
(not Expo Go).

<p align="center">
  <a href="https://maitrungduc1410.github.io/react-native-waveform-player/"><strong>Documentation</strong></a> ·
  <a href="https://maitrungduc1410.github.io/react-native-waveform-player/guide/quick-start">Quick start</a> ·
  <a href="https://maitrungduc1410.github.io/react-native-waveform-player/api/">API reference</a> ·
  <a href="https://maitrungduc1410.github.io/react-native-waveform-player/vi/">Tiếng Việt</a> ·
  <a href="https://maitrungduc1410.github.io/react-native-waveform-player/zh/">简体中文</a>
</p>

<p align="center">
  <img src="./demo/ios.png" alt="iOS" width="48%" />
  <img src="./demo/android.png" alt="Android" width="48%" />
</p>

## Features

- Play, pause, scrub and cycle speed, all drawn in native code with no
  JavaScript in the hot path.
- Rounded-bar waveform decoded on the device, with a playhead that fills the
  current bar up to the exact pixel.
- Press-and-drag scrubbing with no activation delay, even inside a `ScrollView`.
- Configurable bar size, gap, radius and count, colors, time label (count-up or
  count-down) and a tap-to-cycle speed pill. Every part can be hidden.
- Pre-computed `samples` when you already have peaks data.
- Controlled (`playing`, `speed`) and uncontrolled modes, plus `play()`,
  `pause()`, `toggle()`, `seekTo()` and `setSpeed()` on a ref.
- Opt-in background playback with `playInBackground`.
- Events: `onLoad`, `onLoadError`, `onPlayerStateChange`, `onTimeUpdate`,
  `onSeek`, `onEnd`.

Try the styling options in the
[browser playground](https://maitrungduc1410.github.io/react-native-waveform-player/guide/styling#playground).
To record voice notes, see the sister library
[react-native-waveform-recorder](https://maitrungduc1410.github.io/react-native-waveform-recorder/).

## Installation

```sh
npm install react-native-waveform-player
# or
yarn add react-native-waveform-player

# iOS
cd ios && pod install
```

Expo: `npx expo install react-native-waveform-player`, then `npx expo prebuild`
and run a development build. Requirements and the background playback setup
are in the
[installation guide](https://maitrungduc1410.github.io/react-native-waveform-player/guide/installation).

## Quick start

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

export function VoiceNote() {
  return (
    <AudioWaveformView
      source={{ uri: 'https://example.com/voice-note.m4a' }}
      style={{ height: 56 }}
      onEnd={() => console.log('finished')}
    />
  );
}
```

The view has no intrinsic size, so always give it a height.

## Documentation

Everything else lives on the documentation site:
**https://maitrungduc1410.github.io/react-native-waveform-player/**

- [Props](https://maitrungduc1410.github.io/react-native-waveform-player/guide/props) with their defaults
- [Events](https://maitrungduc1410.github.io/react-native-waveform-player/guide/events) and [ref methods](https://maitrungduc1410.github.io/react-native-waveform-player/guide/ref-methods)
- [Styling](https://maitrungduc1410.github.io/react-native-waveform-player/guide/styling) and [speed and playback](https://maitrungduc1410.github.io/react-native-waveform-player/guide/playback), including controlled mode
- [Background playback](https://maitrungduc1410.github.io/react-native-waveform-player/guide/background-playback)
- [Platform notes](https://maitrungduc1410.github.io/react-native-waveform-player/guide/platform-notes) and [troubleshooting](https://maitrungduc1410.github.io/react-native-waveform-player/guide/troubleshooting)

The site is built from [`docs/`](./docs) with VitePress, and the API reference
is generated from the TSDoc comments in `src/` with TypeDoc. Run
`yarn docs:dev` to preview it locally.

## Architecture

- [ARCHITECTURE.md](./ARCHITECTURE.md): codegen pipeline, the audio engine,
  decoder and bars view, the loading sequence and where state lives.
- [LESSONS_LEARNED.md](./LESSONS_LEARNED.md): bugs we hit and what we would do
  differently.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Agent / contributor guide](AGENTS.md)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
