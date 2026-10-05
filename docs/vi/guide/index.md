---
description: "Giới thiệu react-native-waveform-player: Fabric component cho tin nhắn thoại với audio engine, bộ giải mã waveform và thao tác tua native trên iOS và Android."
---

# react-native-waveform-player là gì? {#what-is-react-native-waveform-player}

`react-native-waveform-player` là một React Native component dành cho tin nhắn thoại và các đoạn âm thanh ngắn. Bạn truyền URI của một file âm thanh vào `<AudioWaveformView />`, và nó hiển thị một trình phát quen thuộc như trong các app chat:

- **nút play / pause**, có spinner native trong lúc âm thanh đang tải,
- **waveform** gồm các thanh bo tròn được giải mã từ chính file âm thanh, được tô dần theo tiến độ phát và cho phép người dùng nhấn giữ rồi kéo để tua,
- **nhãn thời gian** đếm lên hoặc đếm ngược,
- **nút tốc độ** xoay vòng qua các tốc độ phát mỗi lần chạm.

Mọi thứ đều chạy native: Fabric component được viết bằng Swift trên iOS và Kotlin trên Android, việc cập nhật tiến độ, xử lý thao tác kéo và vẽ không bao giờ đi qua JavaScript. Code JavaScript của bạn chỉ cần đặt props, lắng nghe [event](/vi/guide/events) và, nếu muốn, gọi [phương thức ref](/vi/guide/ref-methods).

<WaveformPlayground :controls="false" :events="false" />

## Nền tảng và yêu cầu {#platforms-and-requirements}

| | Hỗ trợ |
| --- | --- |
| iOS | Có. `AVPlayer` để phát, `AVAssetReader` cho waveform |
| Android | Có, min SDK 24. `MediaPlayer` để phát, `MediaExtractor` và `MediaCodec` cho waveform |
| New Architecture (Fabric) | Bắt buộc |
| Old Architecture | Không hỗ trợ |
| Expo | Development build và `expo prebuild`. Không chạy trên Expo Go |
| Web | Không hỗ trợ. Component sẽ throw lỗi khi render trên web |

Âm thanh có thể đến từ URI local `file://` hoặc URL remote `https://` trên cả hai nền tảng, và từ URI `content://` trên Android. Chi tiết xem ở [Lưu ý theo nền tảng](/vi/guide/platform-notes#sources).

## Bạn có thể làm gì {#what-you-can-do}

| Tính năng | Xem ở đâu |
| --- | --- |
| Màu sắc, kích thước, khoảng cách, độ bo và số lượng thanh, hình dạng khung | [Tùy biến giao diện](/vi/guide/styling) |
| Ẩn nút play, nhãn thời gian, nút tốc độ hoặc nền | [Tùy biến giao diện](/vi/guide/styling#hiding-parts) |
| Tốc độ tùy chỉnh, tự động phát, vị trí bắt đầu, phát lặp | [Tốc độ và phát lại](/vi/guide/playback) |
| Điều khiển trạng thái phát và tốc độ từ state của bạn | [Controlled mode](/vi/guide/playback#controlled-mode) |
| Bỏ qua bước giải mã native bằng dữ liệu đỉnh sóng của riêng bạn | [Samples tính sẵn](/vi/guide/playback#pre-computed-samples) |
| Tiếp tục phát khi app ở nền | [Phát trong nền](/vi/guide/background-playback) |
| Phản hồi khi tải xong, khi tiến độ thay đổi, khi tua và khi phát hết | [Sự kiện](/vi/guide/events) |
| Play, pause, tua và đổi tốc độ từ code | [Phương thức ref](/vi/guide/ref-methods) |

## Các thành phần kết nối với nhau thế nào {#how-the-pieces-fit}

```text
<AudioWaveformView source={{ uri }} ...props />
        │  Fabric props và commands
        ▼
native view ── audio engine (AVPlayer / MediaPlayer) ── state, tiến độ, kết thúc
            ── bộ giải mã waveform ── biên độ ── bars view (vẽ + kéo để tua)
            ── nút play, nhãn thời gian, nút tốc độ
        │  events
        ▼
onLoad, onPlayerStateChange, onTimeUpdate, onSeek, onEnd, onLoadError
```

Audio engine là nguồn dữ liệu duy nhất cho trạng thái phát. Mọi thao tác chạm, kéo và thay đổi props đều đi qua nó, còn view và các event handler của bạn đọc dữ liệu từ nó.

## Ngoài phạm vi {#out-of-scope}

- **Ghi âm.** Thư viện này chỉ phát và hiển thị âm thanh. Để ghi âm với waveform trực tiếp, hãy dùng thư viện anh em [react-native-waveform-recorder](https://maitrungduc1410.github.io/react-native-waveform-recorder/).
- **Waveform trực tiếp hoặc streaming.** Waveform được tính từ một file âm thanh hoàn chỉnh.
- **Tích hợp Gesture Handler hoặc Reanimated.** Cử chỉ được xử lý native nên thư viện không phụ thuộc vào chúng.

## Bước tiếp theo {#next-steps}

- [Cài đặt thư viện](/vi/guide/installation)
- [Hiển thị tin nhắn thoại đầu tiên](/vi/guide/quick-start)
- Xem [tài liệu API](/api/) được sinh tự động
