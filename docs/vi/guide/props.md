---
description: "Mọi prop của AudioWaveformView kèm kiểu và giá trị mặc định: source, samples, kích thước thanh, màu, nhãn thời gian, nút tốc độ, phát lại và controlled props."
---

# Props {#props}

`AudioWaveformView` nhận các props bên dưới cùng với các props chuẩn của `View` (`style`, `testID`, `pointerEvents`, ...), trừ `children`. Chỉ `source` là bắt buộc. Kích thước tính bằng point trên iOS và dp trên Android. Các prop màu nhận mọi giá trị màu của React Native, ví dụ `'#22D3EE'`, `'rgba(34, 211, 238, 0.35)'` hoặc `'white'`.

[Tài liệu API](/api/type-aliases/AudioWaveformViewProps) được sinh tự động có cùng danh sách này kèm kiểu TypeScript.

## Nguồn âm thanh và dữ liệu waveform {#source-and-waveform-data}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `source` (bắt buộc) | `{ uri: string }` | | Âm thanh cần phát: `file://` hoặc `https://` trên cả hai nền tảng, `content://` trên Android. |
| `samples` | `number[]` | | Biên độ tính sẵn trong khoảng `[0, 1]`. Khi mảng không rỗng, bước giải mã waveform native sẽ bị bỏ qua. |

- Đổi `source.uri` sẽ dừng phát và tải file mới. Trên iOS, waveform quay về các thanh placeholder cho đến khi giải mã xong file mới. Với Android, xem [Lưu ý theo nền tảng](/vi/guide/platform-notes#changing-the-source).
- `samples` được lấy mẫu lại theo số thanh, nên độ dài mảng không cần khớp. Nếu có giá trị lớn hơn `1`, mọi giá trị sẽ được chuẩn hóa theo giá trị lớn nhất. Giá trị đúng bằng `0` được vẽ ở chiều cao placeholder (20 % vùng vẽ thanh), vì bars view coi `0` là "chưa giải mã"; với đoạn im lặng, hãy dùng một số dương nhỏ như `0.01`. Đặt `samples` về mảng rỗng sẽ bắt đầu giải mã native. Chi tiết ở [Samples tính sẵn](/vi/guide/playback#pre-computed-samples).

## Thanh waveform {#bars}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `playedBarColor` | `ColorValue` | `#FFFFFF` | Màu của các thanh nằm bên trái playhead. |
| `unplayedBarColor` | `ColorValue` | `rgba(255, 255, 255, 0.5)` | Màu của các thanh chưa phát tới. |
| `barWidth` | `number` | `3` | Độ rộng mỗi thanh. |
| `barGap` | `number` | `2` | Khoảng cách giữa các thanh. |
| `barRadius` | `number` | `barWidth / 2` | Độ bo góc của mỗi thanh. |
| `barCount` | `number` | vừa đủ chỗ | Số thanh cố định. Giá trị lớn hơn số thanh vừa chỗ sẽ bị giới hạn lại. |

Thanh nằm dưới playhead được chia đúng tại pixel hiện tại: bên trái là màu đã phát, bên phải là màu chưa phát. Cách bố trí vùng vẽ thanh được giải thích trong [Tùy biến giao diện](/vi/guide/styling#bars).

## Khung chứa {#container}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `containerBackgroundColor` | `ColorValue` | `#3478F6` | Màu nền của khung bo tròn. |
| `containerBorderRadius` | `number` | `16` | Độ bo góc của khung. |
| `showBackground` | `boolean` | `true` | Vẽ nền cho khung. Khi đặt `false`, hai prop ở trên không còn tác dụng. |

## Nút play {#play-button}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `showPlayButton` | `boolean` | `true` | Hiện nút play / pause. |
| `playButtonColor` | `ColorValue` | `#FFFFFF` | Màu của biểu tượng play / pause và của spinner khi đang tải. |

## Nhãn thời gian {#time-label}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `showTime` | `boolean` | `true` | Hiện nhãn thời gian. |
| `timeColor` | `ColorValue` | `#FFFFFF` | Màu chữ của nhãn thời gian. |
| `timeMode` | `'count-up' \| 'count-down'` | `'count-up'` | Thời gian đã phát, hoặc thời gian còn lại. |

Nhãn dùng định dạng `m:ss`, ví dụ `0:07` hoặc `12:30`. Số phút không được quy đổi thành giờ.

## Nút tốc độ {#speed-pill}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `showSpeedControl` | `boolean` | `true` | Hiện nút tốc độ. |
| `speedColor` | `ColorValue` | `#FFFFFF` | Màu chữ của nút tốc độ. |
| `speedBackgroundColor` | `ColorValue` | `rgba(255, 255, 255, 0.25)` | Màu nền của nút tốc độ. |
| `speeds` | `number[]` | `[0.5, 1, 1.5, 2]` | Các tốc độ mà nút xoay vòng qua. Mảng rỗng sẽ dùng giá trị mặc định. |
| `defaultSpeed` | `number` | `1` | Tốc độ ban đầu. |

Cách nút chọn tốc độ kế tiếp, và cách `defaultSpeed` tương tác với `setSpeed()`, được giải thích trong [Tốc độ và phát lại](/vi/guide/playback#speed).

## Phát lại {#playback}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `autoPlay` | `boolean` | `false` | Bắt đầu phát ngay khi nguồn sẵn sàng. Bị bỏ qua khi `playing` được đặt. |
| `initialPositionMs` | `number` | `0` | Tua đến vị trí này (mili giây) khi nguồn sẵn sàng. |
| `loop` | `boolean` | `false` | Phát lại từ đầu khi đến cuối. `onEnd` không được gọi khi đang phát lặp. |

`autoPlay` và `initialPositionMs` được đọc khi một nguồn tải xong. Thay đổi chúng sau đó chỉ ảnh hưởng tới nguồn tiếp theo, không ảnh hưởng nguồn hiện tại.

## Phát trong nền {#background}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `playInBackground` | `boolean` | `false` | Tiếp tục phát khi app chuyển xuống nền. Cần thiết lập thêm trên iOS. |
| `ignoreSilentSwitch` | `boolean` | `false` | Chỉ iOS. Vẫn phát khi bật công tắc Chuông / Im lặng, bằng cách chuyển audio session sang `.playback` khi bắt đầu phát. |
| `pauseUiUpdatesInBackground` | `boolean` | `true` | Bỏ qua việc vẽ lại thanh và nhãn thời gian khi ở nền. `onTimeUpdate` vẫn tiếp tục được gọi. |

Xem [Phát trong nền](/vi/guide/background-playback) để biết capability bắt buộc trên iOS, quyền `WAKE_LOCK` tùy chọn trên Android và cấu hình cho Expo.

## Controlled props {#controlled-props}

| Prop | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `playing` | `boolean` | | Khi được đặt, component trở thành controlled: chạm vào nút play chỉ gửi yêu cầu thay đổi qua `onPlayerStateChange`. |
| `speed` | `number` | | Khi được đặt, chạm vào nút tốc độ chỉ gửi yêu cầu thay đổi qua `onPlayerStateChange`. |

Để chúng là `undefined` thì component vẫn là uncontrolled. Hai prop độc lập với nhau, nên bạn có thể điều khiển `playing` và để nút tốc độ tự xử lý tốc độ. Xem [Controlled mode](/vi/guide/playback#controlled-mode).

## Sự kiện {#events}

| Prop | Payload |
| --- | --- |
| `onLoad` | `{ durationMs }` |
| `onLoadError` | `{ message }` |
| `onPlayerStateChange` | `{ state, isPlaying, speed, error? }` |
| `onTimeUpdate` | `{ currentTimeMs, durationMs }` |
| `onSeek` | `{ positionMs }` |
| `onEnd` | không có |

Thời điểm mỗi event được gọi được mô tả trong [Sự kiện](/vi/guide/events).
