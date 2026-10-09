---
description: "react-native-waveform-player 常见问题的解决方法：视图空白、静音模式无声、加载不停、占位波形条、后台停止和受控点击无效。"
---

# 故障排查 {#troubleshooting}

## 什么都不显示 {#nothing-shows-up}

- **给视图设置高度。** 原生视图没有固有尺寸。请在 `style` 中添加 `height`（聊天气泡用 56 比较合适），或确保父视图将其撑开。
- **重新构建应用。** 安装后，为 iOS 运行 `pod install`，并重新构建两个平台。重新加载 JavaScript 不会加载新的原生代码。
- **检查 New Architecture。** 组件仅支持 Fabric。如果应用关闭了 New Architecture，原生组件不会被注册。
- **不支持 Expo Go。** 请使用 [development build](/zh/guide/installation#expo)。
- **Web 上抛出** `'react-native-waveform-player' is only supported on native platforms.` 请只在 iOS 和 Android 上渲染该组件，例如放在 `Platform.OS !== 'web'` 判断之后。

## iPhone 静音模式下没有声音 {#no-sound-in-silent-mode}

默认情况下本库不会配置 `AVAudioSession`，因此使用的是你应用自己的 category。iOS 默认 category 会被响铃 / 静音开关静音。你可以：

- 开启 [`ignoreSilentSwitch`](/zh/guide/props#background)，它会在开始播放时把 session 切换为 `.playback`，或者
- 自行把应用的 audio session category 设为 `.playback`（在原生代码中，或通过你已在使用的音频库），或者
- 如果你还希望在后台继续播放，开启 [`playInBackground`](/zh/guide/background-playback)，它会以同样的方式把 session 切换为 `.playback`。

## 加载指示器一直转 {#the-spinner-never-stops}

播放器无法就绪。添加 `onLoadError` 并查看错误信息：

- **HTTP URL：** iOS 通过 App Transport Security 拦截 `http://`，Android 9 及以上默认拦截明文流量。请使用 `https://`，或在应用配置中放行该域名。
- **scheme 错误：** 本地文件需要使用绝对路径的 `file://` URI。`content://` URI 仅适用于 Android。
- **iOS URL 解析：** 如果 iOS 无法把字符串解析为 URL，会触发 `onLoadError`，错误信息就是该 URI 本身。请对空格和其他特殊字符进行百分号编码，例如使用 `encodeURI()`。
- **格式不受支持：** 文件必须是平台播放器支持的格式。AAC（`.m4a`）和 MP3 在两个平台上都可用。

## 波形一直是扁平的占位条 {#the-waveform-stays-as-flat-placeholder-bars}

可以播放，但波形条始终没有成形。说明波形解码器失败了，`onLoadError` 会告诉你原因（例如 iOS 上的 `Audio track not found` 或 Android 上的 `No audio track found`）。

- 在 iOS 上，远程文件会为解码再下载一次，因此只允许一次请求或很快过期的 URL 可能会失败。
- 如果服务器已经有峰值数据，请传入 [`samples`](/zh/guide/playback#pre-computed-samples)，完全跳过解码。
- 使用 `samples` 时，恰好为 `0` 的值会以占位高度绘制。静音部分请使用较小的正数。

## 应用进入后台时音频停止 {#audio-stops-when-the-app-goes-to-the-background}

这是默认行为。请设置 [`playInBackground`](/zh/guide/background-playback)。在 iOS 上还需要 **Audio** 后台模式，否则应用会被挂起，播放随之停止。

## Android 熄屏后停止播放 {#android-stops-when-the-screen-turns-off}

在应用 manifest 中添加 `WAKE_LOCK` 权限（或在 Expo 的 `app.json` 中添加到 `android.permissions`）。缺少该权限时，Logcat 会显示来自 `AudioPlayerEngine` 的 `playInBackground=true but WAKE_LOCK permission is not granted`。详见 [Android 配置](/zh/guide/background-playback#android-setup)。

## 点击播放按钮或倍速按钮没有反应 {#taps-on-play-or-the-speed-pill-do-nothing}

你设置了 `playing` 或 `speed`，所以组件处于受控状态。点击只会发送带有请求值的 `onPlayerStateChange`，请在回调中更新你的 prop。对应 prop 已设置时，`play()`、`pause()`、`toggle()` 和 `setSpeed()` 也会被忽略。详见[受控模式](/zh/guide/playback#controlled-mode)。

## 受控播放器刚开始就停止 {#a-controlled-player-starts-and-stops-right-away}

你的 `onPlayerStateChange` 回调在音频源仍在加载时把 `isPlaying: false` 写回了 `playing`。即使已排队开始播放，`loading` 状态下的快照仍会报告 `isPlaying: false`。当 `state` 为 `loading` 或 `idle` 时请忽略 `false`，参见[受控模式示例](/zh/guide/playback#controlled-mode)。

## 多条语音同时播放 {#several-voice-notes-play-at-the-same-time}

每个组件都有自己的原生播放器。如果只允许同时播放一条，请用共享的“当前语音”state 控制 `playing`，参见[同一时间只播放一条](/zh/guide/playback#one-at-a-time)。

## 播放结束后再次播放从头开始 {#play-starts-from-the-beginning-after-the-end}

`onEnd` 之后状态为 `ended`，下一次播放总是从 `0` 开始，即使中间进行过跳转。请先调用 `play()`，再调用 `seekTo()`。

## 滑动列表时却拖动了波形 {#swiping-the-list-scrolls-the-waveform-instead}

波形在触摸开始时就会接管手势，因此父级 `ScrollView` 无法抢走拖动。这也意味着从波形上开始的滑动会触发跳转而不是滚动。请在播放器周围留出可供用户滚动的空间。

## Android 上新音频源以 1x 播放 {#on-android-a-new-source-plays-at-1x}

在 Android 上修改 `source` 会创建以 1x 运行的新播放器，而倍速按钮仍显示旧的倍速。请给组件设置 `key={uri}`，或在 `onLoad` 之后调用 `setSpeed()`。详见[切换音频源](/zh/guide/platform-notes#changing-the-source)。

## 倍速标签显示 0.8x 或 1,5x {#the-speed-label-shows-0-8x-or-1-5x}

倍速按钮显示一位小数。iOS 四舍五入，Android 直接截断，并且 Android 使用设备的小数分隔符。详见[倍速按钮标签](/zh/guide/platform-notes#speed-pill-label)。
