---
description: "What react-native-waveform-player is: a Fabric voice-note component with a native audio engine, waveform decoder and scrubbing on iOS and Android."
---

# What is react-native-waveform-player?

`react-native-waveform-player` is a React Native component for voice notes and other short audio clips. You give `<AudioWaveformView />` the URI of an audio file, and it renders a familiar chat-app player:

- a **play / pause button**, with a native spinner while the audio loads,
- a **waveform** of rounded bars decoded from the audio itself, which fills in as playback moves and lets the user press and drag to seek,
- a **time label** counting up or down,
- a **speed pill** that cycles through playback speeds on tap.

Everything is native: the Fabric component is written in Swift on iOS and Kotlin on Android, and the progress updates, drag handling and drawing never cross into JavaScript. Your JavaScript code only sets props, listens to [events](/guide/events) and, if you want, calls [ref methods](/guide/ref-methods).

<WaveformPlayground :controls="false" :events="false" />

## Platforms and requirements

| | Support |
| --- | --- |
| iOS | Yes. `AVPlayer` for playback, `AVAssetReader` for the waveform |
| Android | Yes, min SDK 24. `MediaPlayer` for playback, `MediaExtractor` and `MediaCodec` for the waveform |
| New Architecture (Fabric) | Required |
| Old Architecture | Not supported |
| Expo | Development builds and `expo prebuild`. Not Expo Go |
| Web | Not supported. The component throws when rendered on web |

Audio can come from a local `file://` URI or a remote `https://` URL on both platforms, and from a `content://` URI on Android. See [Platform notes](/guide/platform-notes#sources) for the details.

## What you can do

| Feature | Where |
| --- | --- |
| Colors, bar size, gap, radius and count, container shape | [Styling](/guide/styling) |
| Hide the button, time label, speed pill or background | [Styling](/guide/styling#hiding-parts) |
| Custom speeds, autoplay, start position, looping | [Speed and playback](/guide/playback) |
| Drive play state and speed from your own state | [Controlled mode](/guide/playback#controlled-mode) |
| Skip native decoding with your own peaks | [Pre-computed samples](/guide/playback#pre-computed-samples) |
| Keep playing in the background | [Background playback](/guide/background-playback) |
| React to loading, progress, seeking and the end | [Events](/guide/events) |
| Play, pause, seek and change speed from code | [Ref methods](/guide/ref-methods) |

## How the pieces fit

```text
<AudioWaveformView source={{ uri }} ...props />
        │  Fabric props and commands
        ▼
native view ── audio engine (AVPlayer / MediaPlayer) ── state, progress, end
            ── waveform decoder ── amplitudes ── bars view (drawing + drag to seek)
            ── play button, time label, speed pill
        │  events
        ▼
onLoad, onPlayerStateChange, onTimeUpdate, onSeek, onEnd, onLoadError
```

The audio engine is the single source of truth for the playback state. Every tap, drag and prop change goes through it, and the view and your event handlers read from it.

## Out of scope

- **Recording.** This library only plays and visualizes audio. For recording with a live waveform, use the sister library [react-native-waveform-recorder](https://maitrungduc1410.github.io/react-native-waveform-recorder/).
- **Live or streaming waveforms.** The waveform is computed from a complete audio file.
- **Gesture Handler or Reanimated integration.** Gestures are handled natively, so the library has no dependency on them.

## Next steps

- [Install the library](/guide/installation)
- [Render your first voice note](/guide/quick-start)
- Browse the generated [API reference](/api/)
