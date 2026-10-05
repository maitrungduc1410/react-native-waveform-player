---
description: "在原生 React Native 或 Expo development build 中安装 react-native-waveform-player，含 New Architecture 要求。"
---

# 安装 {#installation}

## 要求 {#requirements}

- **已启用 New Architecture 的 React Native。** 组件仅支持 Fabric。从 React Native 0.76 和 Expo SDK 52 起，New Architecture 默认开启。
- **iOS：** 与你所用 React Native 版本的最低 iOS 版本一致。pod 链接 `AVFoundation`、`CoreMedia`、`QuartzCore` 和 `UIKit`，这些都是 iOS 自带的框架。
- **Android：** min SDK 24。

除 `react` 和 `react-native` 外，本库没有其他 JavaScript 依赖。

## 原生 React Native {#bare-react-native}

安装依赖包：

::: code-group

```sh [npm]
npm install react-native-waveform-player
```

```sh [yarn]
yarn add react-native-waveform-player
```

:::

然后安装 iOS pod：

```sh
cd ios && pod install
```

重新构建应用（`npx react-native run-ios`、`run-android` 或使用 IDE）。添加原生代码后，仅重新加载 Metro 是不够的。

## Expo {#expo}

本库包含原生代码，因此**无法在 Expo Go 中运行**。请使用 [development build](https://docs.expo.dev/develop/development-builds/introduction/) 或 EAS Build。Autolinking 会自动识别本库，无需 config plugin。

```sh
npx expo install react-native-waveform-player
npx expo prebuild
npx expo run:ios
npx expo run:android
```

如果使用[后台播放](/zh/guide/background-playback)，请把 iOS 后台模式和 Android `WAKE_LOCK` 权限写在 `app.json` 中，不要直接修改生成的原生工程，因为 `expo prebuild` 会重新生成它们。具体配置见[后台播放](/zh/guide/background-playback#expo)。

## 权限 {#permissions}

普通播放无需额外配置：

- **Android：** 本库的 manifest 已声明 `android.permission.INTERNET`，会合并到你的应用中，因此远程 URL 可以直接使用。
- **iOS：** 不需要在 `Info.plist` 中添加任何键。除非应用已放行，否则普通 `http://` URL 会被 App Transport Security 拦截，建议使用 `https://`。

后台播放在 iOS 上需要额外配置，在 Android 上可选配置。详见[后台播放](/zh/guide/background-playback)。

## 验证安装 {#check-that-it-works}

用一个确定能播放的音频文件 URL 渲染组件，并给它设置高度：

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

你会先看到占位波形条和加载指示器，然后显示真正的波形。如果什么都没有显示，请参阅[故障排查](/zh/guide/troubleshooting)。
