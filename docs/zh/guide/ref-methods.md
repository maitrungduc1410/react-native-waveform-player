---
description: "通过 ref 上的 play、pause、toggle、seekTo 和 setSpeed 在代码中控制 AudioWaveformView，以及各方法在加载中和受控模式下的行为。"
---

# Ref 方法 {#ref-methods}

绑定一个类型为 `AudioWaveformViewRef` 的 ref，即可在代码中调用播放器：

```tsx
import { useRef } from 'react';
import {
  AudioWaveformView,
  type AudioWaveformViewRef,
} from 'react-native-waveform-player';

const ref = useRef<AudioWaveformViewRef>(null);

<AudioWaveformView ref={ref} source={{ uri }} style={{ height: 56 }} />;

ref.current?.play();
ref.current?.pause();
ref.current?.toggle();
ref.current?.seekTo(0);
ref.current?.setSpeed(2);
```

所有方法都返回 `void`，并立即在原生侧执行。通过 [`onPlayerStateChange`](/zh/guide/events#onplayerstatechange) 和 [`onSeek`](/zh/guide/events#onseek) 查看结果。

| 方法 | 作用 | 受控模式下 |
| --- | --- | --- |
| `play()` | 开始播放。 | 设置了 `playing` 时无效。 |
| `pause()` | 暂停播放。 | 设置了 `playing` 时无效。 |
| `toggle()` | 暂停时播放，播放时暂停。 | 设置了 `playing` 时无效。 |
| `seekTo(positionMs)` | 将播放头移动到以毫秒为单位的位置。 | 有效。 |
| `setSpeed(speed)` | 修改播放倍速。 | 设置了 `speed` 时无效。 |

在网页近似演示中试试这些方法：

<WaveformPlayground :controls="false" />

## play() {#play}

- **加载期间**调用会被记住：音频源一就绪就开始播放，在此之前按钮持续显示加载指示器。在此之前调用 `pause()` 会取消这次请求。
- **播放结束后**（`state` 为 `ended`），`play()` 会从 `0` 重新开始。即使你在结束后调用过 `seekTo()` 或用户拖动过，也是如此。如需从其他位置继续，请先调用 `play()`，再调用 `seekTo()`。
- 设置了 `playing` 时，该方法不做任何事。请改为修改 `playing` prop。

## pause() 与 toggle() {#pause-and-toggle}

播放器已暂停时，`pause()` 不做任何事。`toggle()` 根据当前状态调用 `play()` 或 `pause()`，规则与上文相同。

## seekTo(positionMs) {#seekto-positionms}

- 数值会取整为毫秒，负值变为 `0`，播放器会把结果限制在时长范围内。
- 以请求的位置触发 `onSeek`。
- 播放状态保持不变：正在播放的会从新位置继续，已暂停的仍保持暂停。
- 在 `onLoad` 之前时长未知，因此位置会落在 `0`。如需从其他位置开始，请使用 [`initialPositionMs`](/zh/guide/props#playback) prop。
- 受控模式下同样有效，因为跳转与 `playing` 或 `speed` props 不冲突。

## setSpeed(speed) {#setspeed-speed}

- 修改倍速并更新倍速按钮。暂停时也可以调用，恢复播放时生效。
- 原生播放器会把倍速限制在 0.25 到 4 之间，但倍速按钮和 `onPlayerStateChange` 显示的是你传入的值。请把数值保持在该范围内。
- 该值不必在 `speeds` 中。下次点击倍速按钮时，会切换到 `speeds` 中第一个比它大的值，若没有则回到第一个值。
- 设置了 `speed` 时，该方法不做任何事。请改为修改 `speed` prop。
