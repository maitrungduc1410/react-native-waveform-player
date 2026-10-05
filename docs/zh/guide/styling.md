---
description: "AudioWaveformView 样式：按钮、波形条、时间标签和倍速按钮的布局，颜色，波形条尺寸，隐藏部件，明暗主题与实时调试台。"
---

# 样式 {#styling}

## 调试台 {#playground}

下方每个控件都对应一个真实的 prop，下面的代码会随调整实时更新。这是按 iOS 布局尺寸实现的网页近似版本；在设备上，组件由原生绘制，使用平台自带的字体和图标。

<WaveformPlayground :events="false" />

## 布局 {#layout}

在容器内从左到右依次为：

1. 两侧各 **12 pt 内边距**。
2. **播放按钮**，正方形。iOS 上为视图高度的 60%，最大 36 pt；Android 上为 32 dp。
3. **8 pt 间距**，然后是**波形区域**，占据剩余全部宽度和整个高度。
4. **8 pt 间距**，然后是一列，**时间标签**（13 pt，semibold）在上，**倍速按钮**（44 × 22，全圆角，12 pt 文字）在下。iOS 上该列宽 56 pt；Android 上宽度随内容而定。

隐藏播放按钮，或同时隐藏时间标签和倍速按钮，空出的空间会让给波形区域。组件从不自行设置高度，请在 `style` 中设置。

```tsx
<AudioWaveformView source={{ uri }} style={{ height: 56, marginVertical: 4 }} />
```

## 波形条 {#bars}

- 波形条数量为 `floor(barsAreaWidth / (barWidth + barGap))`，除非你把 `barCount` 设得更小。波形条从左边缘开始排列，因此右侧最多会留出一个波形条步长的空白。
- 每根波形条垂直居中。波形区域上下各留出 `barWidth × 1.5` 的空白，最响的波形条填满剩余高度。
- 最短的波形条高度为 `barWidth`。使用默认圆角（`barWidth / 2`）时，安静的部分会显示为圆点。
- 音频加载期间，所有波形条都以 20% 的高度绘制。波形就绪后，它们会在约 200 ms 内增长到真实高度。

```tsx
// 细而密的波形条
<AudioWaveformView source={{ uri }} barWidth={2} barGap={1.5} style={{ height: 48 }} />

// 粗的方形波形条
<AudioWaveformView source={{ uri }} barWidth={5} barGap={3} barRadius={0} style={{ height: 64 }} />

// 无论宽度如何，始终 40 根波形条
<AudioWaveformView source={{ uri }} barCount={40} style={{ height: 56 }} />
```

## 颜色 {#colors}

| 部件 | Props |
| --- | --- |
| 容器 | `containerBackgroundColor`、`containerBorderRadius` |
| 波形条 | `playedBarColor`、`unplayedBarColor` |
| 播放按钮与加载指示器 | `playButtonColor` |
| 时间标签 | `timeColor` |
| 倍速按钮 | `speedColor`（文字）、`speedBackgroundColor` |

`unplayedBarColor` 通常使用已播放颜色的半透明版本效果较好，默认值就是这样（`#FFFFFF` 和 `rgba(255, 255, 255, 0.5)`）。

## 隐藏部件 {#hiding-parts}

每个部件都有独立的开关：`showPlayButton`、`showTime`、`showSpeedControl` 和 `showBackground`。全部关闭后会得到一个仍支持拖动跳转的纯波形，适合配合 [ref 方法](/zh/guide/ref-methods)自行搭建控件：

```tsx
<AudioWaveformView
  source={{ uri }}
  showPlayButton={false}
  showTime={false}
  showSpeedControl={false}
  showBackground={false}
  playedBarColor="#DB2777"
  unplayedBarColor="rgba(219, 39, 119, 0.3)"
  style={{ height: 40 }}
/>
```

## 浅色与深色主题 {#light-and-dark-themes}

props 都是普通值，因此可以根据 `useColorScheme()` 切换：

```tsx
import { useColorScheme } from 'react-native';

const palettes = {
  light: {
    containerBackgroundColor: '#EEF2F7',
    playedBarColor: '#1F2937',
    unplayedBarColor: 'rgba(31, 41, 55, 0.3)',
    playButtonColor: '#1F2937',
    timeColor: '#4B5563',
    speedColor: '#1F2937',
    speedBackgroundColor: 'rgba(31, 41, 55, 0.1)',
  },
  dark: {
    containerBackgroundColor: '#0F172A',
    playedBarColor: '#22D3EE',
    unplayedBarColor: 'rgba(34, 211, 238, 0.35)',
    playButtonColor: '#22D3EE',
    timeColor: '#A5F3FC',
    speedColor: '#0F172A',
    speedBackgroundColor: '#22D3EE',
  },
};

export function ThemedVoiceNote({ uri }: { uri: string }) {
  const scheme = useColorScheme() === 'dark' ? 'dark' : 'light';
  return <AudioWaveformView source={{ uri }} {...palettes[scheme]} style={{ height: 56 }} />;
}
```

## 发送与接收气泡 {#sent-and-received-bubbles}

聊天应用通常会让发送方的语音消息使用不同样式。为每条消息传入不同的配色，并保持尺寸一致，让气泡对齐：

```tsx
<AudioWaveformView
  source={{ uri: message.audioUri }}
  containerBackgroundColor={message.mine ? '#A21CAF' : '#F3F4F6'}
  playedBarColor={message.mine ? '#FFFFFF' : '#A21CAF'}
  unplayedBarColor={message.mine ? 'rgba(255, 255, 255, 0.45)' : 'rgba(162, 28, 175, 0.3)'}
  playButtonColor={message.mine ? '#FFFFFF' : '#A21CAF'}
  timeColor={message.mine ? '#FFFFFF' : '#4B5563'}
  speedColor={message.mine ? '#FFFFFF' : '#A21CAF'}
  speedBackgroundColor={message.mine ? 'rgba(255, 255, 255, 0.2)' : 'rgba(162, 28, 175, 0.12)'}
  style={{ height: 56, width: 260, alignSelf: message.mine ? 'flex-end' : 'flex-start' }}
/>
```
