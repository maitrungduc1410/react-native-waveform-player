---
description: "Install react-native-waveform-player in a bare React Native app or an Expo development build, with the New Architecture requirement and iOS pods."
---

# Installation

## Requirements

- **React Native with the New Architecture enabled.** The component is Fabric only. The New Architecture is on by default since React Native 0.76 and in Expo SDK 52 and later.
- **iOS:** the minimum iOS version of your React Native version. The pod links `AVFoundation`, `CoreMedia`, `QuartzCore` and `UIKit`, which ship with iOS.
- **Android:** min SDK 24.

The library has no JavaScript dependencies besides `react` and `react-native`.

## Bare React Native

Install the package:

::: code-group

```sh [npm]
npm install react-native-waveform-player
```

```sh [yarn]
yarn add react-native-waveform-player
```

:::

Then install the iOS pod:

```sh
cd ios && pod install
```

Rebuild the app (`npx react-native run-ios`, `run-android` or your IDE). A Metro reload is not enough after adding native code.

## Expo

The library contains native code, so it **does not run in Expo Go**. Use a [development build](https://docs.expo.dev/develop/development-builds/introduction/) or EAS Build. Autolinking picks it up without a config plugin.

```sh
npx expo install react-native-waveform-player
npx expo prebuild
npx expo run:ios
npx expo run:android
```

If you use [background playback](/guide/background-playback), put the iOS background mode and the Android `WAKE_LOCK` permission in `app.json` instead of editing the generated native projects, because `expo prebuild` regenerates them. The exact config is in [Background playback](/guide/background-playback#expo).

## Permissions

For normal playback nothing needs to be added:

- **Android:** the library's manifest declares `android.permission.INTERNET`, which is merged into your app so remote URLs work.
- **iOS:** no `Info.plist` keys are needed. Plain `http://` URLs are blocked by App Transport Security unless your app allows them, so prefer `https://`.

Background playback needs extra setup on iOS, and optionally on Android. See [Background playback](/guide/background-playback).

## Check that it works

Render the component with the URL of an audio file you know plays, and give it a height:

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

export function Check() {
  return (
    <AudioWaveformView
      source={{ uri: 'https://example.com/voice-note.m4a' }}
      style={{ height: 56 }}
      onLoad={(e) => console.log('loaded', e.durationMs)}
      onLoadError={(e) => console.warn('load error', e.message)}
    />
  );
}
```

You should see placeholder bars and a spinner first, then the real waveform. If nothing appears, see [Troubleshooting](/guide/troubleshooting).
