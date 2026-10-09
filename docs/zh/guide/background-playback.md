---
description: "应用进入后台时继续播放语音：playInBackground、iOS Audio 后台模式、AVAudioSession、Android WAKE_LOCK 与 Expo 配置。"
---

# 后台播放 {#background-playback}

## 默认：进入后台时暂停 {#default-pause-in-the-background}

默认情况下，应用离开前台时组件会暂停：

- **iOS：** 收到 `UIApplication.didEnterBackgroundNotification` 时暂停。下拉控制中心不会暂停，因为应用仍在前台。
- **Android：** 在 React Native 的 `onHostPause` 生命周期事件时暂停，该事件紧随 `Activity.onPause`。当另一个 activity 覆盖在你的 activity 之上时（例如系统分享面板）也会触发。

应用回到前台后不会自动恢复播放，需要用户再次点击播放，或由你调用 `play()`。

## 通过 playInBackground 开启 {#opt-in-with-playinbackground}

```tsx
<AudioWaveformView source={{ uri }} playInBackground style={{ height: 56 }} />
```

设置 `playInBackground` 后，应用进入后台时组件不会干预播放。iOS 需要开启一项 capability 才能生效；Android 开箱即用，另有一个可选权限。

## iOS 配置 {#ios-setup}

为应用 target 开启 **Audio** 后台模式，有两种方式：

1. 在 Xcode 中打开应用 target，进入 **Signing & Capabilities**，添加 **Background Modes** 并勾选 **Audio, AirPlay, and Picture in Picture**。
2. 或在 `Info.plist` 中添加：

   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
   </array>
   ```

如果没有这项配置，应用进入后台后不久就会被 iOS 挂起，音频随之停止。

### 本库如何处理 AVAudioSession {#what-the-library-does-with-avaudiosession}

在 `playInBackground`（或 `ignoreSilentSwitch`）开启的情况下开始播放时，本库会配置共享的 `AVAudioSession`：

- 如果 category 已经是 `.playback` 或 `.playAndRecord`，只激活 session。
- 否则把 category 设为 `.playback`（默认 mode，不带 options）并激活。

`.playback` category 在静音开关打开时仍会发声，并且会打断其他应用（例如音乐应用）的音频。如果需要不同的行为，例如与其他音频混音，请在组件挂载前自行把 category 设为带有你所需 options 的 `.playback` 或 `.playAndRecord`，本库会保留该设置。

session 在开始播放时才会被配置，而不是在组件挂载时，因此仅渲染播放器不会打断其他应用的音频，直到用户按下播放。

把 `playInBackground` 改回 `false` 不会恢复之前的 category。

当 `playInBackground` 和 `ignoreSilentSwitch` 都为 `false` 时，本库完全不会改动 `AVAudioSession`。这意味着什么，请参阅[iPhone 静音模式下没有声音](/zh/guide/troubleshooting#no-sound-in-silent-mode)。

## Android 配置 {#android-setup}

普通语音消息无需任何配置：activity 进入 pause 状态后，`MediaPlayer` 会继续播放。

如果需要在**设备休眠**（屏幕关闭且处于空闲）时继续播放，请在应用的 `AndroidManifest.xml` 中添加 `WAKE_LOCK` 权限：

```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

有该权限时，只要 `playInBackground` 为 `true`，本库就会调用 `MediaPlayer.setWakeMode(PARTIAL_WAKE_LOCK)`。没有该权限时会跳过这次调用，Logcat 中会出现 `AudioPlayerEngine` 标签下的警告：

```text
playInBackground=true but WAKE_LOCK permission is not granted ...
```

此时屏幕亮着时仍可在后台播放，设备休眠后会暂停。

本库不会启动前台服务或 media session。对语音消息来说这已足够，但 Android 仍可能为释放内存而终止后台应用，因此本库不适合长音频。

## Expo {#expo}

`expo prebuild` 会重新生成 `ios/` 和 `android/`，因此请把这两项设置写在 `app.json`（或 `app.config.js`）中，而不是修改原生文件：

```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "UIBackgroundModes": ["audio"]
      }
    },
    "android": {
      "permissions": ["android.permission.WAKE_LOCK"]
    }
  }
}
```

只有使用 `playInBackground` 时才需要这两项。修改后请重新运行 `npx expo prebuild`，或发起新的 EAS 构建。

## 锁屏与正在播放 {#lock-screen-and-now-playing}

本库不提供锁屏控制、iOS 上的 `MPNowPlayingInfoCenter` 信息或 Android 上的媒体通知。`onTimeUpdate` 在后台仍会持续触发，你可以基于它自行集成。

## pauseUiUpdatesInBackground {#pauseuiupdatesinbackground}

应用在后台时视图不可见，但进度更新（每秒约 30 次）仍会刷新波形条并格式化时间标签。开启 `pauseUiUpdatesInBackground`（默认 `true`）后会跳过这些刷新，应用回到前台时视图会立即跳到当前位置。

- 无论哪种设置，`onTimeUpdate` 都会触发。
- 只有当你渲染的某些内容需要原生波形条和标签在后台保持更新时，才设为 `false`。这种情况很少见。
