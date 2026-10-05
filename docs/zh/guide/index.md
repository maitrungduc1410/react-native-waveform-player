---
description: "react-native-waveform-player 简介：带原生音频引擎、波形解码和拖动跳转的 Fabric 语音消息组件，支持 iOS 和 Android。"
---

# react-native-waveform-player 是什么？ {#what-is-react-native-waveform-player}

`react-native-waveform-player` 是一个用于语音消息和其他短音频的 React Native 组件。只要把音频文件的 URI 传给 `<AudioWaveformView />`，它就会渲染出聊天应用中常见的播放器：

- **播放 / 暂停按钮**，音频加载时显示原生加载指示器；
- **波形**，由从音频本身解码出的圆角波形条组成，随播放进度填充，用户可以按住并拖动来跳转；
- **时间标签**，可正计时或倒计时；
- **倍速按钮**，每次点击切换到下一个播放速度。

所有部分都是原生实现：Fabric 组件在 iOS 上用 Swift 编写，在 Android 上用 Kotlin 编写，进度更新、拖动处理和绘制都不会经过 JavaScript。你的 JavaScript 代码只需设置 props、监听[事件](/zh/guide/events)，需要时调用 [ref 方法](/zh/guide/ref-methods)。

<WaveformPlayground :controls="false" :events="false" />

## 平台与要求 {#platforms-and-requirements}

| | 支持情况 |
| --- | --- |
| iOS | 支持。播放使用 `AVPlayer`，波形使用 `AVAssetReader` |
| Android | 支持，min SDK 24。播放使用 `MediaPlayer`，波形使用 `MediaExtractor` 和 `MediaCodec` |
| New Architecture（Fabric） | 必需 |
| Old Architecture | 不支持 |
| Expo | 支持 development build 和 `expo prebuild`，不支持 Expo Go |
| Web | 不支持。在 Web 上渲染时组件会抛出错误 |

两个平台都支持本地 `file://` URI 和远程 `https://` URL，Android 还支持 `content://` URI。详见[平台说明](/zh/guide/platform-notes#sources)。

## 能做什么 {#what-you-can-do}

| 功能 | 参见 |
| --- | --- |
| 颜色，波形条的宽度、间距、圆角和数量，容器形状 | [样式](/zh/guide/styling) |
| 隐藏按钮、时间标签、倍速按钮或背景 | [样式](/zh/guide/styling#hiding-parts) |
| 自定义倍速、自动播放、起始位置、循环播放 | [倍速与播放控制](/zh/guide/playback) |
| 由你自己的 state 驱动播放状态和倍速 | [受控模式](/zh/guide/playback#controlled-mode) |
| 使用自己的峰值数据，跳过原生解码 | [预先计算的采样](/zh/guide/playback#pre-computed-samples) |
| 在后台继续播放 | [后台播放](/zh/guide/background-playback) |
| 响应加载、进度、跳转和播放结束 | [事件](/zh/guide/events) |
| 在代码中播放、暂停、跳转和切换倍速 | [Ref 方法](/zh/guide/ref-methods) |

## 各部分如何协作 {#how-the-pieces-fit}

```text
<AudioWaveformView source={{ uri }} ...props />
        │  Fabric props 与 commands
        ▼
native view ── 音频引擎（AVPlayer / MediaPlayer）── 状态、进度、结束
            ── 波形解码器 ── 振幅 ── bars view（绘制 + 拖动跳转）
            ── 播放按钮、时间标签、倍速按钮
        │  events
        ▼
onLoad, onPlayerStateChange, onTimeUpdate, onSeek, onEnd, onLoadError
```

音频引擎是播放状态的唯一数据源。每次点击、拖动和 props 变化都经过它，视图和你的事件回调都从它读取状态。

## 不在本库范围内 {#out-of-scope}

- **录音。** 本库只负责播放和可视化音频。如需录音并显示实时波形，请使用姊妹库 [react-native-waveform-recorder](https://maitrungduc1410.github.io/react-native-waveform-recorder/)。
- **实时或流式波形。** 波形基于完整的音频文件计算。
- **集成 Gesture Handler 或 Reanimated。** 手势由原生处理，因此本库不依赖它们。

## 下一步 {#next-steps}

- [安装本库](/zh/guide/installation)
- [渲染第一条语音消息](/zh/guide/quick-start)
- 浏览自动生成的 [API 参考](/api/)
