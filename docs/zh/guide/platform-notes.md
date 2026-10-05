---
description: "react-native-waveform-player 在 iOS 与 Android 上的差异：音频源、波形解码、切换音频源、倍速标签、布局、后台与音频焦点。"
---

# 平台说明 {#platform-notes}

两个平台的实现保持同步，但底层使用的是不同的平台播放器。本页列出你可能注意到的差异。

## 概览 {#at-a-glance}

| | iOS | Android |
| --- | --- | --- |
| 播放器 | `AVPlayer` | `MediaPlayer` |
| 波形解码器 | `AVAssetReader` | `MediaExtractor` + `MediaCodec` |
| 远程文件的波形 | 播放器就绪后下载文件，再进行解码 | 直接从 URL 流式解码，与播放器并行 |
| 音频源 | `file://`、`https://` | `file://`、`https://`、`http://`、`content://` |
| 播放按钮 | 高度的 60%，最大 36 pt | 32 dp |
| 倍速标签 | 四舍五入到一位小数 | 截断到一位小数，使用设备区域设置 |
| 进入后台时暂停的时机 | `didEnterBackground` | `onHostPause`（`Activity.onPause`） |
| 切换音频源后的倍速 | 保持不变 | 播放器重置为 1x |

## 音频源 {#sources}

- **iOS** 可播放 `AVPlayer` 能从 URL 打开的任何内容：本地 `file://` URI 和 `https://` URL。普通 `http://` 需要在应用中配置 App Transport Security 例外。
- **Android** 把 `http://` 和 `https://` URL 直接交给 `MediaPlayer`，其他（`file://`、`content://` 等）通过 `Uri.parse` 处理。从 Android 9 起，明文 `http://` 默认被拦截，除非应用放行。
- 支持的格式取决于平台播放器。`.m4a` 中的 AAC 和 MP3 在两个平台上都可用。

## 波形解码 {#waveform-decoding}

两个解码器产生的数据相同：每根波形条对应一段等长的时间，取值为其中采样的 RMS，并按最响的波形条归一化。解码过程中会逐步返回部分结果，因此波形条从左到右依次出现。

- **iOS** 无法直接解码远程 URL，因此会用 `URLSession` 下载整个文件，再解码本地副本。为了让网络优先满足播放器的初始缓冲，下载在 `onLoad` 之后才开始。文件扩展名取自服务器建议的文件名、MIME 类型或 URL，都没有时使用 `m4a`，因此没有扩展名的链接也能解码。
- **Android** 用 `MediaExtractor` 读取 URL，它通过 HTTP 流式读取。解码会立即开始，与 `MediaPlayer` 自身的加载同时进行。

因此在两个平台上，远程文件都会被获取两次：播放器一次，解码器一次。如果在意流量，请传入 [`samples`](/zh/guide/playback#pre-computed-samples) 跳过解码。

## 切换音频源 {#changing-the-source}

已挂载的视图上 `source.uri` 发生变化时：

- **iOS** 会暂停，显示占位波形条，并加载新文件。播放倍速保持不变。
- **Android** 会释放旧的 `MediaPlayer` 并创建新的实例，新播放器以 1x 播放，但倍速按钮仍显示之前的倍速。旧的波形和播放头也会一直留在屏幕上，直到新数据到达。

要在两个平台上获得一致的干净起点，请给组件设置 `key={uri}`，让每个音频源都使用新的原生视图，或者在 `onLoad` 之后再次调用 `setSpeed()`。

## 倍速按钮标签 {#speed-pill-label}

按钮最多显示一位小数：

- **iOS** 四舍五入：`0.75` 显示为 `0.8x`，`1.25` 显示为 `1.3x`。
- **Android** 直接截断：`0.75` 显示为 `0.7x`，`1.25` 显示为 `1.2x`。它还会按设备区域设置格式化，因此设置为使用逗号作小数点的语言（例如越南语）的手机会显示 `1,5x`。

一位小数的倍速（`0.5`、`1`、`1.5`、`2`）在两个平台上显示的数字相同，只有小数分隔符可能不同。

## 布局与外观 {#layout-and-look}

- 播放按钮在 iOS 上为视图高度的 60%，最大 36 pt；在 Android 上固定为 32 dp。
- 右侧一列（时间标签和倍速按钮）在 iOS 上宽 56 pt，在 Android 上随内容而定。
- 图标在 iOS 上使用 SF Symbols（`play.fill`、`pause.fill`），在 Android 上使用 vector drawable。加载指示器在 iOS 上是 `UIActivityIndicatorView`，在 Android 上是 `ProgressBar`，颜色都取自 `playButtonColor`。
- 时间标签在 iOS 上为 semibold，在 Android 上为 bold，字号均为 13 pt/sp。

## 后台 {#background}

- **iOS** 在 `didEnterBackground` 时暂停。后台音频需要 Audio 后台模式，开启 `playInBackground` 时本库会把 `AVAudioSession` 切换为 `.playback`。
- **Android** 在 `onHostPause` 时暂停，另一个 activity 遮住你的 activity 时也会触发。设备休眠时继续播放需要可选的 `WAKE_LOCK` 权限。

详见[后台播放](/zh/guide/background-playback)。

## 音频焦点与其他应用 {#audio-focus-and-other-apps}

- **iOS：** 开启 `playInBackground` 时，`.playback` session 会打断其他应用的音频。未开启时，本库不改动 session，使用你应用自己的 category。在 iOS 默认 category（`soloAmbient`）下，静音开关会让播放没有声音。
- **Android：** 本库不申请音频焦点，因此语音开始播放时不会要求其他应用暂停或降低音量。

## 暂停时调用 seekTo() {#seekto-while-paused}

在 Android 上，暂停时调用 `seekTo()` 会立即更新时间标签，但波形的已播放部分要等恢复播放后才会跟上。在波形上拖动时，两个平台都会立即同时更新两者。

## 卸载 {#unmounting}

- **iOS：** Fabric 会复用原生视图。组件卸载时，本库会先停止播放器并重置视图，再把视图放回复用池，因此不会有音频继续播放。
- **Android：** 视图从 window 上分离时释放播放器。

## 无障碍 {#accessibility}

内置的播放按钮、倍速按钮和波形目前在两个平台上都没有设置无障碍标签或操作。如果需要支持读屏软件，可以考虑隐藏内置控件，自行添加调用 [ref 方法](/zh/guide/ref-methods)的无障碍按钮。

## 不支持 {#not-supported}

- **Old Architecture：** 组件仅支持 Fabric。
- **Web：** 可以导入该包（便于共享代码通过类型检查），但在 Web 上渲染 `AudioWaveformView` 会抛出 `'react-native-waveform-player' is only supported on native platforms.`
