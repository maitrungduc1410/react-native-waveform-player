---
description: "React Native 原生语音消息播放器：带动画的波形、按住拖动快进、倍速按钮与后台播放，使用 Swift 和 Kotlin 实现。"
layout: home

hero:
  name: React Native Waveform Player
  text: 原生绘制的语音消息
  tagline: 一个 Fabric 组件即可播放本地或远程音频文件，并渲染播放按钮、可拖动的动画波形、时间标签和倍速按钮。iOS 使用 Swift，Android 使用 Kotlin，播放与绘制循环中没有 JavaScript。
  actions:
    - theme: brand
      text: 快速开始
      link: /zh/guide/quick-start
    - theme: alt
      text: 这是什么？
      link: /zh/guide/
    - theme: alt
      text: API 参考
      link: /api/

features:
  - title: 原生波形
    details: 圆角波形条直接在设备上从音频解码得到。加载期间显示占位条，播放头会精确到像素地填充当前波形条。
    link: /zh/guide/styling
    linkText: 样式
  - title: 拖动与倍速
    details: 在波形上任意位置按住并拖动即可跳转，在 ScrollView 中同样有效。点击倍速按钮可在你自定义的倍速列表中循环切换。
    link: /zh/guide/playback
    linkText: 倍速与播放控制
  - title: 受控或非受控
    details: 可以让组件自行管理播放状态和倍速，也可以通过 playing 和 speed 两个 props 由你的 state 驱动。
    link: /zh/guide/playback#controlled-mode
    linkText: 受控模式
  - title: 后台播放
    details: 默认在应用进入后台时暂停。设置 playInBackground 即可继续播放，相关页面列出了 iOS 和 Android 的配置步骤。
    link: /zh/guide/background-playback
    linkText: 后台播放
  - title: 事件与 ref 方法
    details: 提供 onLoad、onPlayerStateChange、onTimeUpdate、onSeek 和 onEnd 事件，以及 ref 上的 play、pause、toggle、seekTo 和 setSpeed。
    link: /zh/guide/events
    linkText: 事件
  - title: 原生 React Native 与 Expo
    details: 面向 New Architecture 的 Fabric 组件。可在 Expo development build 和 expo prebuild 中使用，不支持 Expo Go。
    link: /zh/guide/installation
    linkText: 安装
---

<div class="home-section vp-doc">

## 安装 {#install}

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

系统要求和 Expo 的详细说明见[安装](/zh/guide/installation)。

## 渲染一条语音消息 {#render-a-voice-note}

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

<AudioWaveformView
  source={{ uri: 'https://example.com/voice-note.m4a' }}
  style={{ height: 56 }}
/>;
```

## 在浏览器中试用 {#try-it-in-the-browser}

<WaveformPlayground :controls="false" :events="false" />

在[样式调试台](/zh/guide/styling#playground)中可以修改颜色、波形条尺寸等更多参数。

## 真机效果 {#see-it-on-a-device}

<div class="demo-shots">
  <figure>
    <img src="../../demo/ios.png" alt="iOS 上的示例应用，展示四种不同样式的语音消息播放器" loading="lazy" />
    <figcaption>iOS</figcaption>
  </figure>
  <figure>
    <img src="../../demo/android.png" alt="Android 上的示例应用，展示四种不同样式的语音消息播放器" loading="lazy" />
    <figcaption>Android</figcaption>
  </figure>
</div>

## 还需要录音？ {#need-to-record-too}

本库只负责播放和可视化音频。如需录制语音消息并显示实时波形，请使用姊妹库 [react-native-waveform-recorder](https://maitrungduc1410.github.io/react-native-waveform-recorder/)。

</div>
