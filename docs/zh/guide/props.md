---
description: "AudioWaveformView 全部 props 的类型与默认值：音频源、采样、波形条尺寸、颜色、时间标签、倍速按钮、播放、后台和受控 props。"
---

# Props {#props}

`AudioWaveformView` 接受下列 props，以及除 `children` 外的标准 `View` props（`style`、`testID`、`pointerEvents` 等）。只有 `source` 是必填项。尺寸在 iOS 上以 pt 为单位，在 Android 上以 dp 为单位。颜色类 props 接受任意 React Native 颜色值，例如 `'#22D3EE'`、`'rgba(34, 211, 238, 0.35)'` 或 `'white'`。

自动生成的 [API 参考](/api/type-aliases/AudioWaveformViewProps)列出了相同的 props 及其 TypeScript 类型。

## 音频源与波形数据 {#source-and-waveform-data}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `source`（必填） | `{ uri: string }` | | 要播放的音频：两个平台均支持 `file://` 和 `https://`，Android 还支持 `content://`。 |
| `samples` | `number[]` | | 预先计算好的振幅，取值范围 `[0, 1]`。数组非空时跳过原生波形解码。 |

- 修改 `source.uri` 会停止播放并加载新文件。在 iOS 上，波形会先恢复为占位条，直到新文件解码完成。Android 的情况见[平台说明](/zh/guide/platform-notes#changing-the-source)。
- `samples` 会按波形条数量重新采样，因此长度无需一致。若有大于 `1` 的值，所有值会按最大值归一化。恰好为 `0` 的值会以占位高度（波形区域的 20%）绘制，因为 bars view 把 `0` 视为“尚未解码”；静音部分请使用 `0.01` 这样的小正数。把 `samples` 改回空数组会重新开始原生解码。详见[预先计算的采样](/zh/guide/playback#pre-computed-samples)。

## 波形条 {#bars}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `playedBarColor` | `ColorValue` | `#FFFFFF` | 播放头左侧波形条的颜色。 |
| `unplayedBarColor` | `ColorValue` | `rgba(255, 255, 255, 0.5)` | 尚未播放的波形条颜色。 |
| `barWidth` | `number` | `3` | 每根波形条的宽度。 |
| `barGap` | `number` | `2` | 波形条之间的间距。 |
| `barRadius` | `number` | `barWidth / 2` | 每根波形条的圆角半径。 |
| `barCount` | `number` | 能放下的最大数量 | 固定的波形条数量。超过可容纳数量时会被截断。 |

播放头所在的波形条会在精确的像素位置分割：左侧为已播放颜色，右侧为未播放颜色。波形区域的布局方式见[样式](/zh/guide/styling#bars)。

## 容器 {#container}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `containerBackgroundColor` | `ColorValue` | `#3478F6` | 圆角容器的背景色。 |
| `containerBorderRadius` | `number` | `16` | 容器的圆角半径。 |
| `showBackground` | `boolean` | `true` | 是否绘制容器背景。设为 `false` 时，上面两个 props 不再生效。 |

## 播放按钮 {#play-button}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `showPlayButton` | `boolean` | `true` | 显示播放 / 暂停按钮。 |
| `playButtonColor` | `ColorValue` | `#FFFFFF` | 播放 / 暂停图标和加载指示器的颜色。 |

## 时间标签 {#time-label}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `showTime` | `boolean` | `true` | 显示时间标签。 |
| `timeColor` | `ColorValue` | `#FFFFFF` | 时间标签的文字颜色。 |
| `timeMode` | `'count-up' \| 'count-down'` | `'count-up'` | 显示已播放时间或剩余时间。 |

标签使用 `m:ss` 格式，例如 `0:07` 或 `12:30`。分钟数不会换算成小时。

## 倍速按钮 {#speed-pill}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `showSpeedControl` | `boolean` | `true` | 显示倍速按钮。 |
| `speedColor` | `ColorValue` | `#FFFFFF` | 倍速按钮的文字颜色。 |
| `speedBackgroundColor` | `ColorValue` | `rgba(255, 255, 255, 0.25)` | 倍速按钮的背景色。 |
| `speeds` | `number[]` | `[0.5, 1, 1.5, 2]` | 倍速按钮循环切换的速度列表。传入空数组时使用默认值。 |
| `defaultSpeed` | `number` | `1` | 初始倍速。 |

倍速按钮如何选择下一个速度，以及 `defaultSpeed` 与 `setSpeed()` 如何相互影响，见[倍速与播放控制](/zh/guide/playback#speed)。

## 播放 {#playback}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `autoPlay` | `boolean` | `false` | 音频源就绪后立即开始播放。设置了 `playing` 时忽略此项。 |
| `initialPositionMs` | `number` | `0` | 音频源就绪时跳转到该位置（毫秒）。 |
| `loop` | `boolean` | `false` | 播放到结尾后从头开始。循环播放时不会触发 `onEnd`。 |

`autoPlay` 和 `initialPositionMs` 在音频源加载完成时读取。之后再修改，只会影响下一个音频源，不影响当前音频源。

## 后台 {#background}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `playInBackground` | `boolean` | `false` | 应用进入后台时继续播放。iOS 上需要额外配置。 |
| `pauseUiUpdatesInBackground` | `boolean` | `true` | 在后台时跳过波形条和时间标签的刷新。`onTimeUpdate` 仍会继续触发。 |

iOS 必需的 capability、Android 可选的 `WAKE_LOCK` 权限以及 Expo 配置，见[后台播放](/zh/guide/background-playback)。

## 受控 props {#controlled-props}

| Prop | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `playing` | `boolean` | | 设置后组件变为受控：点击播放按钮只会通过 `onPlayerStateChange` 请求变更。 |
| `speed` | `number` | | 设置后，点击倍速按钮只会通过 `onPlayerStateChange` 请求变更。 |

保持为 `undefined` 时组件是非受控的。两者相互独立，因此你可以只控制 `playing`，倍速仍交给倍速按钮处理。详见[受控模式](/zh/guide/playback#controlled-mode)。

## 事件 {#events}

| Prop | Payload |
| --- | --- |
| `onLoad` | `{ durationMs }` |
| `onLoadError` | `{ message }` |
| `onPlayerStateChange` | `{ state, isPlaying, speed, error? }` |
| `onTimeUpdate` | `{ currentTimeMs, durationMs }` |
| `onSeek` | `{ positionMs }` |
| `onEnd` | 无 |

各事件的触发时机见[事件](/zh/guide/events)。
