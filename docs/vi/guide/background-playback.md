---
description: "Tiếp tục phát tin nhắn thoại khi app xuống nền: playInBackground, background mode Audio trên iOS, AVAudioSession, WAKE_LOCK trên Android và cấu hình Expo."
---

# Phát trong nền {#background-playback}

## Mặc định: tạm dừng khi ở nền {#default-pause-in-the-background}

Mặc định, component tạm dừng khi app rời khỏi foreground:

- **iOS:** khi nhận `UIApplication.didEnterBackgroundNotification`. Kéo Control Center xuống không làm dừng phát, vì app vẫn ở foreground.
- **Android:** khi có lifecycle event `onHostPause` của React Native, xảy ra sau `Activity.onPause`. Điều này cũng xảy ra khi một activity khác mở đè lên activity của bạn, ví dụ bảng chia sẻ của hệ thống.

Việc phát không tự tiếp tục khi app quay lại. Người dùng phải chạm play lần nữa, hoặc bạn gọi `play()`.

## Bật bằng playInBackground {#opt-in-with-playinbackground}

```tsx
<AudioWaveformView source={{ uri }} playInBackground style={{ height: 56 }} />
```

Khi có `playInBackground`, component không can thiệp vào việc phát khi app chuyển xuống nền. iOS cần bật một capability để tính năng này hoạt động; Android chạy được ngay và có một quyền tùy chọn.

## Thiết lập cho iOS {#ios-setup}

Bật background mode **Audio** cho app target, theo một trong hai cách:

1. Trong Xcode, mở app target, vào **Signing & Capabilities**, thêm **Background Modes** và tích chọn **Audio, AirPlay, and Picture in Picture**.
2. Hoặc thêm đoạn sau vào `Info.plist`:

   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
   </array>
   ```

Nếu thiếu, iOS sẽ tạm ngưng app ngay sau khi app xuống nền và âm thanh dừng lại.

### Thư viện làm gì với AVAudioSession {#what-the-library-does-with-avaudiosession}

Khi `playInBackground` chuyển thành `true`, thư viện cấu hình `AVAudioSession` dùng chung:

- Nếu category đã là `.playback` hoặc `.playAndRecord`, thư viện chỉ kích hoạt session.
- Nếu không, thư viện đặt category thành `.playback` (mode mặc định, không có option) rồi kích hoạt.

Category `.playback` vẫn phát kể cả khi bật công tắc im lặng, và nó ngắt âm thanh của các app khác, chẳng hạn app nghe nhạc. Nếu bạn cần hành vi khác, ví dụ phát trộn với âm thanh khác, hãy tự đặt category thành `.playback` hoặc `.playAndRecord` với các option của bạn trước khi component được mount. Thư viện sẽ giữ nguyên cấu hình đó.

Đặt `playInBackground` về lại `false` không khôi phục category trước đó.

Khi `playInBackground` là `false`, thư viện hoàn toàn không động đến `AVAudioSession`. Xem [Không có tiếng trên iPhone ở chế độ im lặng](/vi/guide/troubleshooting#no-sound-in-silent-mode) để hiểu điều này có nghĩa gì.

## Thiết lập cho Android {#android-setup}

Với tin nhắn thoại thông thường, bạn không cần làm gì: `MediaPlayer` vẫn phát tiếp sau khi activity bị pause.

Nếu việc phát phải tiếp tục cả khi **thiết bị ngủ** (tắt màn hình và không hoạt động), hãy thêm quyền `WAKE_LOCK` vào `AndroidManifest.xml` của app:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Khi có quyền này, thư viện gọi `MediaPlayer.setWakeMode(PARTIAL_WAKE_LOCK)` mỗi khi `playInBackground` là `true`. Nếu không có, lời gọi đó bị bỏ qua và Logcat hiển thị cảnh báo với tag `AudioPlayerEngine`:

```text
playInBackground=true but WAKE_LOCK permission is not granted ...
```

Khi đó việc phát vẫn tiếp tục ở nền khi màn hình còn sáng, và dừng lại khi thiết bị ngủ.

Thư viện không khởi chạy foreground service hay media session. Như vậy là đủ cho tin nhắn thoại, nhưng Android vẫn có thể dừng một app ở nền để giải phóng bộ nhớ, nên thư viện không dành cho âm thanh dài.

## Expo {#expo}

`expo prebuild` tạo lại `ios/` và `android/`, nên hãy khai báo cả hai thiết lập trong `app.json` (hoặc `app.config.js`) thay vì sửa file native:

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

Hai mục này chỉ cần khi bạn dùng `playInBackground`. Sau khi thay đổi, hãy chạy lại `npx expo prebuild` hoặc tạo một EAS build mới.

## Màn hình khóa và Now Playing {#lock-screen-and-now-playing}

Thư viện không cung cấp nút điều khiển trên màn hình khóa, dữ liệu `MPNowPlayingInfoCenter` trên iOS hay thông báo media trên Android. `onTimeUpdate` vẫn được gọi khi ở nền, nên bạn có thể dựa vào nó để tự tích hợp.

## pauseUiUpdatesInBackground {#pauseuiupdatesinbackground}

Khi app ở nền, view không hiển thị, nhưng nhịp cập nhật tiến độ (khoảng 30 lần mỗi giây) vẫn sẽ cập nhật các thanh và định dạng nhãn thời gian. Với `pauseUiUpdatesInBackground` (mặc định `true`), các lần cập nhật đó bị bỏ qua, và view nhảy ngay đến vị trí hiện tại khi app quay lại.

- `onTimeUpdate` vẫn được gọi trong cả hai trường hợp.
- Chỉ đặt thành `false` nếu có thứ gì bạn render cần các thanh và nhãn native được cập nhật liên tục khi ở nền. Trường hợp này rất hiếm.
