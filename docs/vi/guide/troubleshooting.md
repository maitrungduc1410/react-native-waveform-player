---
description: "Cách sửa lỗi thường gặp với react-native-waveform-player: view trống, không có tiếng ở chế độ im lặng, spinner quay mãi, thanh placeholder và dừng phát ở nền."
---

# Khắc phục sự cố {#troubleshooting}

## Không hiển thị gì {#nothing-shows-up}

- **Đặt chiều cao cho view.** Native view không có kích thước tự nhiên. Hãy thêm `height` vào `style` (56 hợp với bong bóng chat), hoặc đảm bảo view cha kéo giãn nó.
- **Build lại app.** Sau khi cài đặt, chạy `pod install` cho iOS và build lại cả hai nền tảng. Reload JavaScript không nạp được code native mới.
- **Kiểm tra New Architecture.** Component chỉ hỗ trợ Fabric. Nếu app của bạn đang tắt New Architecture, native component sẽ không được đăng ký.
- **Expo Go không được hỗ trợ.** Hãy dùng [development build](/vi/guide/installation#expo).
- **Web throw lỗi** `'react-native-waveform-player' is only supported on native platforms.` Chỉ render component trên iOS và Android, ví dụ đặt sau điều kiện `Platform.OS !== 'web'`.

## Không có tiếng trên iPhone ở chế độ im lặng {#no-sound-in-silent-mode}

Khi `playInBackground` tắt, thư viện không cấu hình `AVAudioSession`, nên category của app bạn được áp dụng. Category mặc định của iOS bị tắt tiếng bởi công tắc Chuông / Im lặng. Bạn có thể:

- tự đặt category audio session của app thành `.playback` (bằng code native, hoặc qua một thư viện audio bạn đang dùng), hoặc
- bật [`playInBackground`](/vi/guide/background-playback), tùy chọn này chuyển session sang `.playback`.

## Spinner quay mãi không dừng {#the-spinner-never-stops}

Player không thể sẵn sàng. Thêm `onLoadError` và xem thông báo lỗi:

- **URL HTTP:** iOS chặn `http://` qua App Transport Security, còn Android 9 trở lên mặc định chặn kết nối không mã hóa. Hãy dùng `https://`, hoặc cho phép domain đó trong cấu hình app.
- **Sai scheme:** file local cần URI `file://` với đường dẫn tuyệt đối. URI `content://` chỉ chạy trên Android.
- **iOS không parse được URL:** nếu iOS không parse được chuỗi thành URL, `onLoadError` được gọi với chính URI đó làm thông báo. Hãy percent-encode dấu cách và các ký tự đặc biệt khác, ví dụ bằng `encodeURI()`.
- **Định dạng không được hỗ trợ:** player của nền tảng phải hỗ trợ file đó. AAC (`.m4a`) và MP3 chạy được trên cả hai nền tảng.

## Waveform chỉ toàn thanh placeholder phẳng {#the-waveform-stays-as-flat-placeholder-bars}

Âm thanh vẫn phát nhưng các thanh không bao giờ thành hình. Bộ giải mã waveform đã gặp lỗi, và `onLoadError` cho bạn biết lý do (ví dụ `Audio track not found` trên iOS hoặc `No audio track found` trên Android).

- Trên iOS, file remote được tải thêm một lần để giải mã, nên URL chỉ cho phép một request, hoặc hết hạn nhanh, có thể gây lỗi.
- Nếu server của bạn đã có sẵn dữ liệu đỉnh sóng, hãy truyền [`samples`](/vi/guide/playback#pre-computed-samples) để bỏ qua hoàn toàn bước giải mã.
- Với `samples`, giá trị đúng bằng `0` được vẽ ở chiều cao placeholder. Hãy dùng một số dương nhỏ cho đoạn im lặng.

## Âm thanh dừng khi app xuống nền {#audio-stops-when-the-app-goes-to-the-background}

Đó là hành vi mặc định. Hãy đặt [`playInBackground`](/vi/guide/background-playback). Trên iOS, bạn còn cần background mode **Audio**; nếu thiếu, app bị tạm ngưng và việc phát dừng lại.

## Android dừng phát khi tắt màn hình {#android-stops-when-the-screen-turns-off}

Thêm quyền `WAKE_LOCK` vào manifest của app (hoặc `android.permissions` trong `app.json` của Expo). Nếu thiếu, Logcat hiển thị `playInBackground=true but WAKE_LOCK permission is not granted` từ `AudioPlayerEngine`. Xem [Thiết lập cho Android](/vi/guide/background-playback#android-setup).

## Chạm vào nút play hoặc nút tốc độ không có tác dụng {#taps-on-play-or-the-speed-pill-do-nothing}

Bạn đã đặt `playing` hoặc `speed`, nên component đang ở chế độ controlled. Thao tác chạm chỉ gửi `onPlayerStateChange` với giá trị được yêu cầu; hãy cập nhật prop của bạn trong handler. `play()`, `pause()`, `toggle()` và `setSpeed()` cũng bị bỏ qua khi prop tương ứng được đặt. Xem [Controlled mode](/vi/guide/playback#controlled-mode).

## Player controlled vừa phát đã dừng ngay {#a-controlled-player-starts-and-stops-right-away}

Handler `onPlayerStateChange` của bạn chép `isPlaying: false` ngược lại vào `playing` trong khi nguồn còn đang tải. Snapshot ở trạng thái `loading` báo `isPlaying: false` kể cả khi đã có lệnh phát đang chờ. Hãy bỏ qua `false` khi `state` là `loading` hoặc `idle`, như trong [ví dụ controlled mode](/vi/guide/playback#controlled-mode).

## Nhiều tin nhắn thoại phát cùng lúc {#several-voice-notes-play-at-the-same-time}

Mỗi component có native player riêng. Để chỉ cho phép phát một tin mỗi lần, hãy điều khiển `playing` từ một state "tin đang phát" dùng chung, như trong [Mỗi lần một tin nhắn thoại](/vi/guide/playback#one-at-a-time).

## Sau khi phát hết, play lại bắt đầu từ đầu {#play-starts-from-the-beginning-after-the-end}

Sau `onEnd`, trạng thái là `ended`, và lần phát tiếp theo luôn bắt đầu từ `0`, kể cả khi bạn đã tua ở giữa. Hãy gọi `play()` trước, rồi mới gọi `seekTo()`.

## Vuốt danh sách lại tua waveform {#swiping-the-list-scrolls-the-waveform-instead}

Waveform giành lấy thao tác chạm ngay khi bắt đầu, nên `ScrollView` cha không thể chiếm thao tác kéo. Điều này cũng có nghĩa là một cú vuốt bắt đầu trên waveform sẽ tua thay vì cuộn. Hãy chừa khoảng trống quanh player để người dùng có chỗ cuộn.

## Trên Android, nguồn mới phát ở 1x {#on-android-a-new-source-plays-at-1x}

Đổi `source` trên Android sẽ tạo player mới chạy ở 1x, trong khi nút tốc độ vẫn hiển thị tốc độ cũ. Hãy đặt `key={uri}` cho component, hoặc gọi `setSpeed()` sau `onLoad`. Xem [Đổi nguồn](/vi/guide/platform-notes#changing-the-source).

## Nhãn tốc độ hiển thị 0.8x hoặc 1,5x {#the-speed-label-shows-0-8x-or-1-5x}

Nút tốc độ hiển thị một chữ số thập phân. iOS làm tròn còn Android cắt bớt, và Android dùng dấu phân cách thập phân của thiết bị. Xem [Nhãn trên nút tốc độ](/vi/guide/platform-notes#speed-pill-label).
