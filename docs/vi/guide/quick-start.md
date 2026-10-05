---
description: "Hiển thị tin nhắn thoại với AudioWaveformView chỉ trong vài dòng: nguồn remote hoặc local, chiều cao, theme riêng, event và ref để điều khiển."
---

# Bắt đầu nhanh {#quick-start}

## Tin nhắn thoại đầu tiên {#your-first-voice-note}

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

export function VoiceNote() {
  return (
    <AudioWaveformView
      source={{ uri: 'https://example.com/voice-note.m4a' }}
      style={{ height: 56 }}
    />
  );
}
```

Bắt buộc phải có hai thứ:

- **`source`** có `uri`. URL remote `https://` và URI local `file://` đều chạy được trên cả hai nền tảng.
- **Chiều cao.** Native view không có kích thước tự nhiên, nên nếu không có chiều cao trong `style` (hoặc một view cha kéo giãn nó) thì sẽ không hiển thị gì. Từ 48 đến 64 là hợp với bong bóng chat.

Mặc định component là uncontrolled: nút play, nút tốc độ và thao tác kéo trên waveform đều hoạt động mà bạn không cần viết thêm code nào.

## Phát file local {#play-a-local-file}

Truyền vào một URI `file://` tuyệt đối, ví dụ file bạn vừa ghi âm hoặc tải về:

```tsx
<AudioWaveformView
  source={{ uri: 'file:///path/to/Documents/note-42.m4a' }}
  style={{ height: 56 }}
/>
```

File local tải chỉ trong vài mili giây nên spinner gần như không kịp hiện. Trên Android, URI `content://` cũng dùng được.

## Khớp với theme của bạn {#match-your-theme}

Mọi màu sắc và kích thước thanh đều là props:

```tsx
<AudioWaveformView
  source={{ uri }}
  containerBackgroundColor="#0F172A"
  containerBorderRadius={20}
  playedBarColor="#22D3EE"
  unplayedBarColor="rgba(34, 211, 238, 0.35)"
  playButtonColor="#22D3EE"
  timeColor="#A5F3FC"
  timeMode="count-down"
  speedColor="#0F172A"
  speedBackgroundColor="#22D3EE"
  speeds={[1, 1.5, 2]}
  defaultSpeed={1.5}
  barWidth={4}
  barGap={3}
  style={{ height: 56 }}
/>
```

Thử trực tiếp các giá trị trong [playground tùy biến giao diện](/vi/guide/styling#playground).

## Lắng nghe event {#listen-to-events}

```tsx
<AudioWaveformView
  source={{ uri }}
  style={{ height: 56 }}
  onLoad={({ durationMs }) => setDuration(durationMs)}
  onPlayerStateChange={({ state, isPlaying, speed }) => {
    console.log(state, isPlaying, speed);
  }}
  onEnd={() => markAsListened(messageId)}
  onLoadError={({ message }) => console.warn(message)}
/>
```

`onPlayerStateChange` gửi một snapshot đầy đủ mỗi khi có thay đổi, vì vậy hãy so sánh nó với state của bạn thay vì đếm số event. Xem [Sự kiện](/vi/guide/events).

## Điều khiển từ code {#control-it-from-code}

```tsx
import { useRef } from 'react';
import { Button } from 'react-native';
import {
  AudioWaveformView,
  type AudioWaveformViewRef,
} from 'react-native-waveform-player';

export function VoiceNoteWithButtons({ uri }: { uri: string }) {
  const ref = useRef<AudioWaveformViewRef>(null);
  return (
    <>
      <AudioWaveformView ref={ref} source={{ uri }} style={{ height: 56 }} />
      <Button title="Restart" onPress={() => ref.current?.seekTo(0)} />
      <Button title="2x" onPress={() => ref.current?.setSpeed(2)} />
    </>
  );
}
```

Toàn bộ phương thức được liệt kê trong [Phương thức ref](/vi/guide/ref-methods).

## Bước tiếp theo {#next-steps}

- [Props](/vi/guide/props): mọi prop cùng giá trị mặc định
- [Tốc độ và phát lại](/vi/guide/playback): tốc độ, phát lặp, controlled mode, mỗi lần chỉ phát một tin nhắn thoại
- [Phát trong nền](/vi/guide/background-playback): tiếp tục phát khi app ở nền
