---
description: "Điều khiển AudioWaveformView từ code bằng play, pause, toggle, seekTo và setSpeed qua ref, và cách mỗi phương thức hoạt động khi đang tải và ở controlled mode."
---

# Phương thức ref {#ref-methods}

Gắn một ref có kiểu `AudioWaveformViewRef` để gọi player từ code:

```tsx
import { useRef } from 'react';
import {
  AudioWaveformView,
  type AudioWaveformViewRef,
} from 'react-native-waveform-player';

const ref = useRef<AudioWaveformViewRef>(null);

<AudioWaveformView ref={ref} source={{ uri }} style={{ height: 56 }} />;

ref.current?.play();
ref.current?.pause();
ref.current?.toggle();
ref.current?.seekTo(0);
ref.current?.setSpeed(2);
```

Mọi phương thức đều trả về `void` và chạy ngay ở phía native. Theo dõi [`onPlayerStateChange`](/vi/guide/events#onplayerstatechange) và [`onSeek`](/vi/guide/events#onseek) để thấy kết quả.

| Phương thức | Chức năng | Ở controlled mode |
| --- | --- | --- |
| `play()` | Bắt đầu phát. | Không có tác dụng khi `playing` được đặt. |
| `pause()` | Tạm dừng. | Không có tác dụng khi `playing` được đặt. |
| `toggle()` | Phát nếu đang dừng, dừng nếu đang phát. | Không có tác dụng khi `playing` được đặt. |
| `seekTo(positionMs)` | Di chuyển playhead đến vị trí tính bằng mili giây. | Vẫn hoạt động. |
| `setSpeed(speed)` | Đổi tốc độ phát. | Không có tác dụng khi `speed` được đặt. |

Thử các phương thức trên bản mô phỏng web:

<WaveformPlayground :controls="false" />

## play() {#play}

- **Khi đang tải**, lời gọi được ghi nhớ: việc phát sẽ bắt đầu ngay khi nguồn sẵn sàng. Nút play vẫn hiển thị spinner cho đến lúc đó. Gọi `pause()` trước thời điểm này sẽ hủy yêu cầu.
- **Sau khi phát hết** (`state` là `ended`), `play()` phát lại từ `0`. Điều này vẫn xảy ra kể cả khi bạn đã gọi `seekTo()` hoặc người dùng đã kéo sau khi phát hết. Muốn tiếp tục từ vị trí khác, hãy gọi `play()` trước rồi mới gọi `seekTo()`.
- Khi `playing` được đặt, phương thức này không làm gì. Hãy đổi prop `playing`.

## pause() và toggle() {#pause-and-toggle}

`pause()` không làm gì nếu player đã dừng sẵn. `toggle()` gọi `play()` hoặc `pause()` tùy theo trạng thái hiện tại, với cùng các quy tắc ở trên.

## seekTo(positionMs) {#seekto-positionms}

- Giá trị được làm tròn thành mili giây nguyên, giá trị âm trở thành `0`, và player giới hạn kết quả theo thời lượng.
- Gọi `onSeek` với vị trí được yêu cầu.
- Trạng thái phát được giữ nguyên: đang phát thì tiếp tục phát từ vị trí mới, đang dừng thì vẫn dừng.
- Trước `onLoad`, thời lượng chưa được biết nên vị trí sẽ rơi về `0`. Muốn bắt đầu ở vị trí khác, hãy dùng prop [`initialPositionMs`](/vi/guide/props#playback).
- Phương thức vẫn hoạt động ở controlled mode, vì việc tua không xung đột với các prop `playing` hay `speed`.

## setSpeed(speed) {#setspeed-speed}

- Đổi tốc độ và cập nhật nút tốc độ. Bạn có thể gọi khi đang dừng; tốc độ mới sẽ áp dụng khi phát tiếp.
- Native player giới hạn tốc độ trong khoảng 0.25 đến 4, nhưng nút tốc độ và `onPlayerStateChange` hiển thị đúng giá trị bạn truyền vào. Hãy giữ giá trị trong khoảng đó.
- Giá trị không bắt buộc phải nằm trong `speeds`. Lần chạm tiếp theo vào nút tốc độ sẽ chuyển sang giá trị đầu tiên trong `speeds` lớn hơn nó, hoặc quay về giá trị đầu tiên.
- Khi `speed` được đặt, phương thức này không làm gì. Hãy đổi prop `speed`.
