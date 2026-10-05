---
description: "AudioWaveformView 各事件（onLoad、onPlayerStateChange、onTimeUpdate、onSeek、onEnd、onLoadError）的触发时机。"
---

# 事件 {#events}

所有事件都是 `AudioWaveformView` 的 props。payload 是普通对象，无需读取 `nativeEvent`。

| 事件 | Payload | 触发时机 |
| --- | --- | --- |
| `onLoad` | `{ durationMs }` | 音频源已可以播放。 |
| `onLoadError` | `{ message }` | 音频源无法加载或播放，或者波形无法解码。 |
| `onPlayerStateChange` | `{ state, isPlaying, speed, error? }` | 播放状态的任何部分发生变化。发送完整快照。 |
| `onTimeUpdate` | `{ currentTimeMs, durationMs }` | 播放期间每秒约 30 次。 |
| `onSeek` | `{ positionMs }` | 在波形上的拖动结束时，或调用 `seekTo()` 之后。 |
| `onEnd` | 无 | 播放到结尾且 `loop` 关闭。 |

在下方播放、拖动或点击倍速按钮即可查看事件。该演示是网页上的近似实现：原生组件会发送相同的事件和 payload，但重复快照的次数可能不同。

<WaveformPlayground :controls="false" />

## onPlayerStateChange {#onplayerstatechange}

```ts
type AudioWaveformPlayerStateEvent = {
  state: 'idle' | 'loading' | 'ready' | 'ended' | 'error';
  isPlaying: boolean;
  speed: number;
  error?: string;
};
```

这是一份**快照**，而不是增量。每次状态切换都会发送：开始加载、音频源就绪、播放和暂停、倍速变化、播放结束以及出错时。同一份快照可能连续到达两三次（例如在 `onLoad` 前后），因此请与你自己的 state 比较：

```tsx
onPlayerStateChange={(e) => {
  if (e.isPlaying !== playing) setPlaying(e.isPlaying);
  if (e.speed !== speed) setSpeed(e.speed);
}}
```

| `state` | 含义 |
| --- | --- |
| `idle` | 尚未加载音频源。 |
| `loading` | 原生播放器正在打开并缓冲音频源。播放按钮显示加载指示器。 |
| `ready` | 音频源可以播放。通过 `isPlaying` 判断是否正在播放。 |
| `ended` | 在 `loop` 关闭时播放到了结尾。再次播放会从 `0` 开始。 |
| `error` | 原生播放器出错。 |

只有在播放器出错时与 `onLoadError` 一同发送的那份快照才带有 `error` 字段。其他快照，包括第一份处于 `error` 状态的快照，都不包含该字段。

**在受控模式下**（设置了 `playing` 或 `speed`），点击播放按钮或倍速按钮不会改变播放。组件会发送一份带有**请求值**的快照：`isPlaying` 取反，或 `speed` 为 `speeds` 中的下一个速度。你需要通过更新 prop 来应用它。详见[受控模式](/zh/guide/playback#controlled-mode)。

## onLoad {#onload}

每个音频源触发一次，在原生播放器可以播放时触发。`durationMs` 是以毫秒为单位的时长，播放器无法获取时为 `0`。此时组件还会应用 `initialPositionMs` 和 `autoPlay`，然后在 iOS 上开始解码波形（Android 更早开始解码，见[平台说明](/zh/guide/platform-notes#waveform-decoding)）。

一次典型的加载会依次发送 `loading` 快照、`ready` 快照、`onLoad`，然后再发送一份或多份 `ready` 快照。

## onTimeUpdate {#ontimeupdate}

播放期间每秒触发约 30 次，携带以毫秒为单位的位置和时长。播放结束时还会再触发一次，此时 `currentTimeMs` 等于 `durationMs`。

- 用户在波形上拖动期间**不会**触发。请用 `onSeek` 获取最终位置。
- 开启[后台播放](/zh/guide/background-playback)时，**在后台也会持续触发**，即使 `pauseUiUpdatesInBackground` 跳过了视图刷新。你可以用它驱动自己的进度 UI 或做数据统计。

原生视图会自行更新波形条和时间标签，因此不需要依靠这个事件来驱动组件动画。

## onSeek {#onseek}

携带以毫秒为单位的位置触发：

- 在波形上的拖动结束时，包括被系统取消的拖动；
- 每次调用 `seekTo()` 之后，携带请求的位置（取整，并限制为不小于 `0`）。播放器本身会将其限制在时长范围内。

`initialPositionMs` 不会触发该事件。

## onEnd {#onend}

播放到结尾且 `loop` 关闭时触发。前后还会收到最后一次 `onTimeUpdate` 和 `ended` 快照。开启 `loop` 时，播放会跳回 `0` 继续，不会触发 `onEnd`。

## onLoadError {#onloaderror}

在两种不同情况下触发，并携带原生错误信息：

1. **播放器出错**，无法打开或播放音频源。状态变为 `error`，播放按钮停止显示加载指示器。错误信息来自平台，例如 iOS 上的 `AVFoundation` 错误，或 Android 上的 `MediaPlayer error: what=1 extra=-1004` 和 `setDataSource failed: ...`。
2. **波形解码器失败**，例如 iOS 上的 `Audio track not found` 或 Android 上的 `No audio track found`。这种情况下播放仍可能正常，波形条保持占位状态。如果你的文件无法在设备上解码，请传入 [`samples`](/zh/guide/playback#pre-computed-samples)。

在 iOS 上，无法解析为 URL 的 URI 会触发 `onLoadError`，错误信息就是该 URI 本身，除此之外不会发生任何事情。

对于第 1 种情况，建议提供重试选项。对于第 2 种情况，通常记录日志即可。
