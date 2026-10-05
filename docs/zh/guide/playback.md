---
description: "react-native-waveform-player 的倍速、自动播放、起始位置、循环、拖动跳转、受控模式、单条播放和预先计算的采样。"
---

# 倍速与播放控制 {#speed-and-playback}

## 倍速 {#speed}

倍速按钮显示当前速度，例如 `1x` 或 `1.5x`。每次点击会切换到 **`speeds` 中第一个大于当前速度的值**，越过最大值后回到第一个值。请按升序列出速度；如果列表无序，按钮可能跳过某些值或卡住不动。

```tsx
<AudioWaveformView
  source={{ uri }}
  speeds={[1, 1.25, 1.5, 2]}
  defaultSpeed={1}
  style={{ height: 56 }}
/>
```

- **`defaultSpeed`** 是倍速按钮的初始速度，只生效一次：第一次应用倍速之后（无论来自 `defaultSpeed` 本身、点击还是 `setSpeed()`），再修改 `defaultSpeed` 都会被忽略。之后要修改倍速，请调用 [`setSpeed()`](/zh/guide/ref-methods#setspeed-speed) 或使用受控的 [`speed`](#controlled-mode) prop。
- **范围。** 原生播放器会把倍速限制在 0.25 到 4 之间，而倍速按钮和事件仍显示你设置的值，因此请保持在此范围内。
- **标签**保留一位小数。iOS 四舍五入（`0.75` 显示为 `0.8x`），Android 直接截断（`0.75` 显示为 `0.7x`），因此建议使用最多一位小数的倍速。详见[平台说明](/zh/guide/platform-notes#speed-pill-label)。

## 自动播放与起始位置 {#autoplay-and-start-position}

```tsx
<AudioWaveformView
  source={{ uri }}
  autoPlay
  initialPositionMs={12_000}
  style={{ height: 56 }}
/>
```

两者都在音频源就绪时（紧接 `onLoad` 之后）应用，每个音频源一次。设置了 `playing` prop 时会忽略 `autoPlay`，此时请改用 `playing={true}`。

## 循环播放 {#looping}

开启 `loop` 后，播放到结尾会跳回 `0` 继续。不会触发 `onEnd`，状态保持为 `ready`。

## 加载中点击播放 {#tapping-play-while-loading}

无需等待 `onLoad`。加载期间点击播放按钮、调用 `play()` 或设置 `playing={true}` 都会被记住，音频源一就绪就开始播放。在此之前加载指示器会一直显示。

## 拖动跳转 {#scrubbing}

在波形上任意位置按下，播放头会立即跳到该处，拖动即可移动。

- 手指按住期间，播放暂停，`onTimeUpdate` 停止触发。
- 松开后，播放器跳转到最终位置，触发 `onSeek`，如果之前正在播放则继续播放。如果触摸被系统取消，或 `playing` 处于受控状态且为 `false`，则不会继续播放。
- 波形在触摸开始时就会接管手势，因此父级 `ScrollView` 或 `FlatList` 无法抢走水平拖动。从波形上开始的垂直滑动会触发跳转，而不是滚动列表。
- 音频源就绪前时长未知，拖动无法跳转。

## 播放结束 {#the-end-of-playback}

在 `loop` 关闭时播放到结尾，播放头保持填满，按钮显示播放图标，状态为 `ended`，并触发 `onEnd`。下一次播放从 `0` 开始，即使中间进行过跳转也是如此。如需从其他位置开始，请先播放再跳转。

## 受控模式 {#controlled-mode}

默认情况下，组件自行管理播放状态和倍速。设置 `playing` 和/或 `speed` 后，改由你的 state 管理：

- 点击播放按钮或倍速按钮**不会改变播放**，而是发送带有**请求值**的 `onPlayerStateChange`。
- 是否应用由你决定，方式是更新对应的 prop。
- 设置了 `playing` 时，`play()`、`pause()` 和 `toggle()` 无效；设置了 `speed` 时，`setSpeed()` 无效。`seekTo()` 仍然有效。

```tsx
const [playing, setPlaying] = useState(false);
const [speed, setSpeed] = useState(1);

<AudioWaveformView
  source={{ uri }}
  playing={playing}
  speed={speed}
  onPlayerStateChange={(e) => {
    // 加载期间，即使已排队开始播放，快照中的 isPlaying 仍为 false。
    if (e.isPlaying || (e.state !== 'loading' && e.state !== 'idle')) {
      setPlaying(e.isPlaying);
    }
    setSpeed(e.speed);
  }}
  style={{ height: 56 }}
/>;
```

对 `state` 的判断很重要。音频源仍在加载时设置 `playing={true}` 会把开始播放排入队列，但随后的快照仍然是 `isPlaying: false`。如果把这个值写回去，`playing` 会变成 `false`，排队的播放也会被取消。

### 同一时间只播放一条 {#one-at-a-time}

每个 `AudioWaveformView` 都有自己的原生播放器，因此多个实例可以同时播放。在聊天中，通常希望开始播放一条语音时其他语音停止。把当前播放的语音 id 存在 state 中，并控制 `playing`：

```tsx
function VoiceNoteList({ notes }: { notes: { id: string; uri: string }[] }) {
  const [activeId, setActiveId] = useState<string | null>(null);

  return (
    <FlatList
      data={notes}
      extraData={activeId}
      keyExtractor={(note) => note.id}
      renderItem={({ item }) => (
        <AudioWaveformView
          source={{ uri: item.uri }}
          playing={activeId === item.id}
          onPlayerStateChange={(e) => {
            if (e.isPlaying) {
              setActiveId(item.id);
            } else if (e.state !== 'loading' && e.state !== 'idle') {
              setActiveId((current) => (current === item.id ? null : current));
            }
          }}
          style={{ height: 56, marginVertical: 4 }}
        />
      )}
    />
  );
}
```

点击某条语音的播放按钮会将其设为当前播放项，并暂停之前那条。暂停它或播放到结尾都会清空 `activeId`。

## 预先计算的采样 {#pre-computed-samples}

默认情况下，组件会在设备上解码音频来绘制波形。对于远程文件，这意味着除了播放器自身的流式加载外还要再下载一次（见[平台说明](/zh/guide/platform-notes#waveform-decoding)）。如果你的后端已经存储了峰值数据，可以通过 `samples` 传入，从而跳过解码：

```tsx
<AudioWaveformView
  source={{ uri: message.audioUrl }}
  samples={message.peaks} // 例如 64 个介于 0 和 1 之间的值
  style={{ height: 56 }}
/>
```

- 取值应在 `[0, 1]` 范围内。只要有一个值大于 `1`，整个数组都会除以其中的最大值。
- 数组会按波形条数量重新采样，聊天气泡用 50 到 100 个值就足够了。
- 恰好为 `0` 的值会以占位高度绘制。静音部分请使用较小的正数。
- 波形会立即显示，没有占位阶段。

## 切换音频源 {#changing-the-source}

在已挂载的组件上修改 `source.uri` 会停止播放并加载新文件，`autoPlay` 和 `initialPositionMs` 会再次生效。iOS 上倍速保持不变。Android 上倍速和旧波形的表现不同，见[平台说明](/zh/guide/platform-notes#changing-the-source)。如果希望每个文件都从干净的状态开始，请给组件设置 `key={uri}`，让 React 为每个音频源挂载新的原生视图。
