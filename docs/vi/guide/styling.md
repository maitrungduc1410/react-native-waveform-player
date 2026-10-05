---
description: "Tùy biến AudioWaveformView: bố cục nút play, thanh, nhãn thời gian và nút tốc độ, màu sắc, kích thước thanh, ẩn thành phần, theme sáng tối và playground."
---

# Tùy biến giao diện {#styling}

## Playground {#playground}

Mỗi điều khiển bên dưới tương ứng với một prop thật, và đoạn code bên dưới cập nhật ngay khi bạn thay đổi. Đây là bản mô phỏng trên web dựng theo số đo bố cục của iOS; trên thiết bị, component được vẽ native với font và icon của chính nền tảng đó.

<WaveformPlayground :events="false" />

## Bố cục {#layout}

Từ trái sang phải, bên trong khung chứa:

1. **Padding 12 pt** ở cả hai bên.
2. **Nút play** hình vuông. Trên iOS, nút cao bằng 60 % chiều cao view, tối đa 36 pt. Trên Android, nút có kích thước 32 dp.
3. **Khoảng cách 8 pt**, rồi đến **vùng vẽ thanh**, chiếm toàn bộ chiều rộng còn lại và toàn bộ chiều cao.
4. **Khoảng cách 8 pt**, rồi đến một cột gồm **nhãn thời gian** (13 pt, semibold) nằm trên **nút tốc độ** (44 × 22, bo tròn hoàn toàn, chữ 12 pt). Trên iOS, cột này rộng 56 pt; trên Android, cột rộng vừa với nội dung.

Ẩn nút play, hoặc ẩn cả nhãn thời gian lẫn nút tốc độ, sẽ nhường khoảng trống đó cho vùng vẽ thanh. Component không bao giờ tự đặt chiều cao: hãy đặt chiều cao trong `style`.

```tsx
<AudioWaveformView source={{ uri }} style={{ height: 56, marginVertical: 4 }} />
```

## Thanh waveform {#bars}

- Số thanh là `floor(barsAreaWidth / (barWidth + barGap))`, trừ khi bạn đặt `barCount` nhỏ hơn. Các thanh bắt đầu từ mép trái, nên bên phải có thể còn trống tối đa một bước thanh.
- Mỗi thanh được căn giữa theo chiều dọc. Vùng vẽ thanh chừa trống `barWidth × 1.5` ở trên và dưới, thanh lớn nhất lấp đầy phần còn lại.
- Thanh ngắn nhất cao bằng `barWidth`. Với độ bo mặc định (`barWidth / 2`), các đoạn nhỏ tiếng sẽ hiện thành các chấm tròn.
- Trong lúc âm thanh đang tải, mọi thanh được vẽ ở 20 % chiều cao. Khi có waveform, chúng cao dần đến chiều cao thật trong khoảng 200 ms.

```tsx
// Thanh mảnh, dày đặc
<AudioWaveformView source={{ uri }} barWidth={2} barGap={1.5} style={{ height: 48 }} />

// Thanh vuông, to bản
<AudioWaveformView source={{ uri }} barWidth={5} barGap={3} barRadius={0} style={{ height: 64 }} />

// Luôn có 40 thanh, bất kể chiều rộng
<AudioWaveformView source={{ uri }} barCount={40} style={{ height: 56 }} />
```

## Màu sắc {#colors}

| Thành phần | Props |
| --- | --- |
| Khung chứa | `containerBackgroundColor`, `containerBorderRadius` |
| Thanh waveform | `playedBarColor`, `unplayedBarColor` |
| Nút play và spinner | `playButtonColor` |
| Nhãn thời gian | `timeColor` |
| Nút tốc độ | `speedColor` (chữ), `speedBackgroundColor` |

Dùng phiên bản trong suốt của màu đã phát cho `unplayedBarColor` thường cho kết quả đẹp, giống như giá trị mặc định (`#FFFFFF` và `rgba(255, 255, 255, 0.5)`).

## Ẩn thành phần {#hiding-parts}

Mỗi thành phần có công tắc riêng: `showPlayButton`, `showTime`, `showSpeedControl` và `showBackground`. Tắt hết, bạn sẽ có một waveform trơn vẫn hỗ trợ kéo để tua, rất tiện khi bạn tự dựng các nút điều khiển xung quanh bằng [phương thức ref](/vi/guide/ref-methods):

```tsx
<AudioWaveformView
  source={{ uri }}
  showPlayButton={false}
  showTime={false}
  showSpeedControl={false}
  showBackground={false}
  playedBarColor="#DB2777"
  unplayedBarColor="rgba(219, 39, 119, 0.3)"
  style={{ height: 40 }}
/>
```

## Theme sáng và tối {#light-and-dark-themes}

Props là giá trị thông thường, nên bạn chỉ cần đổi chúng theo `useColorScheme()`:

```tsx
import { useColorScheme } from 'react-native';

const palettes = {
  light: {
    containerBackgroundColor: '#EEF2F7',
    playedBarColor: '#1F2937',
    unplayedBarColor: 'rgba(31, 41, 55, 0.3)',
    playButtonColor: '#1F2937',
    timeColor: '#4B5563',
    speedColor: '#1F2937',
    speedBackgroundColor: 'rgba(31, 41, 55, 0.1)',
  },
  dark: {
    containerBackgroundColor: '#0F172A',
    playedBarColor: '#22D3EE',
    unplayedBarColor: 'rgba(34, 211, 238, 0.35)',
    playButtonColor: '#22D3EE',
    timeColor: '#A5F3FC',
    speedColor: '#0F172A',
    speedBackgroundColor: '#22D3EE',
  },
};

export function ThemedVoiceNote({ uri }: { uri: string }) {
  const scheme = useColorScheme() === 'dark' ? 'dark' : 'light';
  return <AudioWaveformView source={{ uri }} {...palettes[scheme]} style={{ height: 56 }} />;
}
```

## Bong bóng gửi và nhận {#sent-and-received-bubbles}

Các app chat thường hiển thị tin nhắn thoại của người gửi theo kiểu khác. Hãy truyền bảng màu khác nhau cho từng tin nhắn và giữ nguyên kích thước để các bong bóng thẳng hàng:

```tsx
<AudioWaveformView
  source={{ uri: message.audioUri }}
  containerBackgroundColor={message.mine ? '#A21CAF' : '#F3F4F6'}
  playedBarColor={message.mine ? '#FFFFFF' : '#A21CAF'}
  unplayedBarColor={message.mine ? 'rgba(255, 255, 255, 0.45)' : 'rgba(162, 28, 175, 0.3)'}
  playButtonColor={message.mine ? '#FFFFFF' : '#A21CAF'}
  timeColor={message.mine ? '#FFFFFF' : '#4B5563'}
  speedColor={message.mine ? '#FFFFFF' : '#A21CAF'}
  speedBackgroundColor={message.mine ? 'rgba(255, 255, 255, 0.2)' : 'rgba(162, 28, 175, 0.12)'}
  style={{ height: 56, width: 260, alignSelf: message.mine ? 'flex-end' : 'flex-start' }}
/>
```
