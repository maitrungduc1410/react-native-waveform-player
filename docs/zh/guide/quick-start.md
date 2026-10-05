---
description: "几行代码用 AudioWaveformView 渲染语音消息：远程或本地音频源、高度、自定义主题、事件和命令式 ref。"
---

# 快速开始 {#quick-start}

## 第一条语音消息 {#your-first-voice-note}

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

export function VoiceNote() {
  return (
    <AudioWaveformView
      source={{ uri: 'https://example.com/voice-note.m4a' }}
      style={{ height: 56 }}
    />
  );
}
```

有两项是必需的：

- **带 `uri` 的 `source`。** 两个平台都支持远程 `https://` URL 和本地 `file://` URI。
- **高度。** 原生视图没有固有尺寸，如果 `style` 中没有高度（也没有父视图将其撑开），就什么都不会渲染。聊天气泡中 48 到 64 比较合适。

组件默认是非受控的：播放按钮、倍速按钮和波形拖动都无需你编写任何代码即可使用。

## 播放本地文件 {#play-a-local-file}

传入一个绝对路径的 `file://` URI，例如你录制或下载的文件：

```tsx
<AudioWaveformView
  source={{ uri: 'file:///path/to/Documents/note-42.m4a' }}
  style={{ height: 56 }}
/>
```

本地文件几毫秒就能加载完成，加载指示器几乎不会出现。在 Android 上也可以使用 `content://` URI。

## 匹配你的主题 {#match-your-theme}

所有颜色和波形条尺寸都是 props：

```tsx
<AudioWaveformView
  source={{ uri }}
  containerBackgroundColor="#0F172A"
  containerBorderRadius={20}
  playedBarColor="#22D3EE"
  unplayedBarColor="rgba(34, 211, 238, 0.35)"
  playButtonColor="#22D3EE"
  timeColor="#A5F3FC"
  timeMode="count-down"
  speedColor="#0F172A"
  speedBackgroundColor="#22D3EE"
  speeds={[1, 1.5, 2]}
  defaultSpeed={1.5}
  barWidth={4}
  barGap={3}
  style={{ height: 56 }}
/>
```

可以在[样式调试台](/zh/guide/styling#playground)中实时尝试这些值。

## 监听事件 {#listen-to-events}

```tsx
<AudioWaveformView
  source={{ uri }}
  style={{ height: 56 }}
  onLoad={({ durationMs }) => setDuration(durationMs)}
  onPlayerStateChange={({ state, isPlaying, speed }) => {
    console.log(state, isPlaying, speed);
  }}
  onEnd={() => markAsListened(messageId)}
  onLoadError={({ message }) => console.warn(message)}
/>
```

`onPlayerStateChange` 每次变化都会发送完整快照，因此请与你自己的 state 比较，而不是统计事件次数。详见[事件](/zh/guide/events)。

## 用代码控制 {#control-it-from-code}

```tsx
import { useRef } from 'react';
import { Button } from 'react-native';
import {
  AudioWaveformView,
  type AudioWaveformViewRef,
} from 'react-native-waveform-player';

export function VoiceNoteWithButtons({ uri }: { uri: string }) {
  const ref = useRef<AudioWaveformViewRef>(null);
  return (
    <>
      <AudioWaveformView ref={ref} source={{ uri }} style={{ height: 56 }} />
      <Button title="Restart" onPress={() => ref.current?.seekTo(0)} />
      <Button title="2x" onPress={() => ref.current?.setSpeed(2)} />
    </>
  );
}
```

全部方法见 [Ref 方法](/zh/guide/ref-methods)。

## 下一步 {#next-steps}

- [Props](/zh/guide/props)：所有 props 及其默认值
- [倍速与播放控制](/zh/guide/playback)：倍速、循环播放、受控模式、同一时间只播放一条语音
- [后台播放](/zh/guide/background-playback)：应用在后台时继续播放
