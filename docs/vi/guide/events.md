---
description: "Khi nào AudioWaveformView gọi onLoad, onPlayerStateChange, onTimeUpdate, onSeek, onEnd và onLoadError, payload chứa gì và cách xử lý event lặp lại."
---

# Sự kiện {#events}

Mọi event đều là props của `AudioWaveformView`. Payload là object thông thường; bạn không cần đọc `nativeEvent`.

| Event | Payload | Được gọi khi |
| --- | --- | --- |
| `onLoad` | `{ durationMs }` | Nguồn đã sẵn sàng để phát. |
| `onLoadError` | `{ message }` | Không tải hoặc phát được nguồn, hoặc không giải mã được waveform. |
| `onPlayerStateChange` | `{ state, isPlaying, speed, error? }` | Bất kỳ thông tin nào về trạng thái phát thay đổi. Gửi snapshot đầy đủ. |
| `onTimeUpdate` | `{ currentTimeMs, durationMs }` | Khoảng 30 lần mỗi giây khi đang phát. |
| `onSeek` | `{ positionMs }` | Người dùng kết thúc thao tác kéo trên waveform, hoặc sau khi gọi `seekTo()`. |
| `onEnd` | không có | Phát đến cuối và `loop` đang tắt. |

Bấm play, kéo trên waveform và chạm vào nút tốc độ bên dưới để xem các event. Đây là bản mô phỏng trên web: component native gửi cùng các event với cùng payload, tuy số snapshot lặp lại có thể khác.

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

Đây là một **snapshot**, không phải phần thay đổi. Nó được gửi ở mọi lần chuyển trạng thái: khi bắt đầu tải, khi nguồn sẵn sàng, khi play và pause, khi đổi tốc độ, khi phát hết và khi có lỗi. Cùng một snapshot có thể đến hai hoặc ba lần liên tiếp (ví dụ quanh thời điểm `onLoad`), nên hãy so sánh giá trị với state của bạn:

```tsx
onPlayerStateChange={(e) => {
  if (e.isPlaying !== playing) setPlaying(e.isPlaying);
  if (e.speed !== speed) setSpeed(e.speed);
}}
```

| `state` | Ý nghĩa |
| --- | --- |
| `idle` | Chưa có nguồn nào được tải. |
| `loading` | Native player đang mở và buffer nguồn. Nút play hiển thị spinner. |
| `ready` | Nguồn có thể phát. Kiểm tra `isPlaying` để biết có đang phát hay không. |
| `ended` | Đã phát đến cuối khi `loop` tắt. Phát lại sẽ bắt đầu từ `0`. |
| `error` | Native player gặp lỗi. |

`error` chỉ có giá trị trong snapshot được gửi cùng `onLoadError` khi player gặp lỗi. Các snapshot khác, kể cả snapshot đầu tiên ở trạng thái `error`, không có trường này.

**Ở controlled mode** (khi `playing` hoặc `speed` được đặt), chạm vào nút play hay nút tốc độ không làm thay đổi việc phát. Thay vào đó, component gửi một snapshot chứa giá trị **được yêu cầu**: `isPlaying` bị đảo, hoặc `speed` là tốc độ kế tiếp trong `speeds`. Bạn áp dụng nó bằng cách cập nhật prop của mình. Xem [Controlled mode](/vi/guide/playback#controlled-mode).

## onLoad {#onload}

Được gọi một lần cho mỗi nguồn, khi native player sẵn sàng phát. `durationMs` là thời lượng tính bằng mili giây, hoặc `0` nếu player không xác định được. Lúc này component cũng áp dụng `initialPositionMs` và `autoPlay`, rồi bắt đầu giải mã waveform trên iOS (Android bắt đầu giải mã sớm hơn, xem [Lưu ý theo nền tảng](/vi/guide/platform-notes#waveform-decoding)).

Một lần tải thông thường sẽ gửi snapshot `loading`, snapshot `ready`, `onLoad`, rồi thêm một hoặc vài snapshot `ready`.

## onTimeUpdate {#ontimeupdate}

Được gọi khoảng 30 lần mỗi giây khi đang phát, kèm vị trí và thời lượng tính bằng mili giây. Event này cũng được gọi thêm một lần khi phát hết, với `currentTimeMs` bằng `durationMs`.

- Event **không** được gọi trong lúc người dùng đang kéo trên waveform. Hãy dùng `onSeek` để lấy vị trí cuối cùng.
- Event **vẫn tiếp tục được gọi khi app ở nền** nếu [phát trong nền](/vi/guide/background-playback) đang bật, kể cả khi `pauseUiUpdatesInBackground` đã bỏ qua việc vẽ lại view. Bạn có thể dùng nó cho UI tiến độ riêng hoặc cho analytics.

Native view tự cập nhật các thanh và nhãn thời gian, nên bạn không cần event này để tạo animation cho component.

## onSeek {#onseek}

Được gọi kèm vị trí tính bằng mili giây:

- khi kết thúc thao tác kéo trên waveform, kể cả khi hệ thống hủy thao tác kéo,
- sau mỗi lần gọi `seekTo()`, với vị trí được yêu cầu (đã làm tròn và giới hạn từ `0` trở lên). Bản thân player sẽ giới hạn vị trí theo thời lượng.

Event không được gọi cho `initialPositionMs`.

## onEnd {#onend}

Được gọi khi phát đến cuối và `loop` đang tắt. Xung quanh thời điểm đó, bạn cũng nhận được `onTimeUpdate` cuối cùng và các snapshot `ended`. Khi bật `loop`, việc phát quay về `0` và tiếp tục mà không gọi `onEnd`.

## onLoadError {#onloaderror}

Được gọi kèm thông báo native trong hai trường hợp khác nhau:

1. **Player gặp lỗi** khi mở hoặc phát nguồn. Trạng thái chuyển thành `error` và nút play ngừng quay spinner. Thông báo đến từ nền tảng, ví dụ lỗi `AVFoundation` trên iOS, hoặc `MediaPlayer error: what=1 extra=-1004` và `setDataSource failed: ...` trên Android.
2. **Bộ giải mã waveform gặp lỗi**, ví dụ `Audio track not found` trên iOS hoặc `No audio track found` trên Android. Trường hợp này việc phát vẫn có thể hoạt động; các thanh giữ nguyên dạng placeholder. Hãy truyền [`samples`](/vi/guide/playback#pre-computed-samples) nếu file của bạn không giải mã được trên thiết bị.

Trên iOS, URI không thể parse thành URL sẽ gọi `onLoadError` với chính URI đó làm thông báo, và không có gì khác xảy ra.

Với trường hợp 1, hãy hiển thị lựa chọn thử lại. Với trường hợp 2, thường chỉ cần ghi log.
