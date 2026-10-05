---
description: "A native voice-note player for React Native: animated waveform, press-and-drag scrubbing, a speed pill and background playback, in Swift and Kotlin."
layout: home

hero:
  name: React Native Waveform Player
  text: Voice notes, drawn natively
  tagline: One Fabric component plays any local or remote audio file and renders a play button, an animated waveform you can scrub, a time label and a speed pill. Swift on iOS, Kotlin on Android, no JavaScript in the playback or drawing loop.
  actions:
    - theme: brand
      text: Get started
      link: /guide/quick-start
    - theme: alt
      text: What is it?
      link: /guide/
    - theme: alt
      text: API reference
      link: /api/

features:
  - title: Native waveform
    details: Rounded bars decoded from the audio on the device, with placeholder bars while loading and a playhead that fills the current bar up to the exact pixel.
    link: /guide/styling
    linkText: Styling
  - title: Scrub and speed
    details: Press and drag anywhere on the waveform to seek, even inside a ScrollView. Tap the pill to cycle through your own list of speeds.
    link: /guide/playback
    linkText: Speed and playback
  - title: Controlled or uncontrolled
    details: Let the component manage play and speed itself, or drive them from your state with the playing and speed props.
    link: /guide/playback#controlled-mode
    linkText: Controlled mode
  - title: Background playback
    details: Paused when the app goes to the background by default. Opt in with playInBackground; the page lists the iOS and Android setup.
    link: /guide/background-playback
    linkText: Background playback
  - title: Events and ref methods
    details: onLoad, onPlayerStateChange, onTimeUpdate, onSeek and onEnd, plus play, pause, toggle, seekTo and setSpeed on a ref.
    link: /guide/events
    linkText: Events
  - title: Bare React Native and Expo
    details: Fabric component for the New Architecture. Works in Expo development builds and with expo prebuild, not in Expo Go.
    link: /guide/installation
    linkText: Installation
---

<div class="home-section vp-doc">

## Install

::: code-group

```sh [npm]
npm install react-native-waveform-player
cd ios && pod install
```

```sh [yarn]
yarn add react-native-waveform-player
cd ios && pod install
```

```sh [Expo]
npx expo install react-native-waveform-player
npx expo prebuild
```

:::

See [Installation](/guide/installation) for requirements and Expo details.

## Render a voice note

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

<AudioWaveformView
  source={{ uri: 'https://example.com/voice-note.m4a' }}
  style={{ height: 56 }}
/>;
```

## Try it in the browser

<WaveformPlayground :controls="false" :events="false" />

Change colors, bar size and more in the [styling playground](/guide/styling#playground).

## See it on a device

<div class="demo-shots">
  <figure>
    <img src="../demo/ios.png" alt="Example app on iOS with four voice-note players in different styles" loading="lazy" />
    <figcaption>iOS</figcaption>
  </figure>
  <figure>
    <img src="../demo/android.png" alt="Example app on Android with four voice-note players in different styles" loading="lazy" />
    <figcaption>Android</figcaption>
  </figure>
</div>

## Need to record too?

This library plays and visualizes audio. To record voice notes with a live waveform, see the sister library [react-native-waveform-recorder](https://maitrungduc1410.github.io/react-native-waveform-recorder/).

</div>
