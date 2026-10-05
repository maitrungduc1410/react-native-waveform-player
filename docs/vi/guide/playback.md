---
description: "Tốc độ, tự động phát, vị trí bắt đầu, phát lặp, kéo để tua, controlled mode, mỗi lần một tin nhắn thoại và samples tính sẵn trong react-native-waveform-player."
---

# Tốc độ và phát lại {#speed-and-playback}

## Tốc độ {#speed}

Nút tốc độ hiển thị tốc độ hiện tại, ví dụ `1x` hoặc `1.5x`. Mỗi lần chạm sẽ chuyển sang **giá trị đầu tiên trong `speeds` lớn hơn tốc độ hiện tại**, và quay về giá trị đầu tiên sau giá trị lớn nhất. Hãy liệt kê các tốc độ theo thứ tự tăng dần; nếu danh sách không được sắp xếp, nút có thể bỏ qua giá trị hoặc bị kẹt.

```tsx
<AudioWaveformView
  source={{ uri }}
  speeds={[1, 1.25, 1.5, 2]}
  defaultSpeed={1}
  style={{ height: 56 }}
/>
```

- **`defaultSpeed`** là tốc độ ban đầu của nút. Nó chỉ được áp dụng một lần: sau khi tốc độ đầu tiên được áp dụng (bởi chính `defaultSpeed`, một lần chạm hoặc `setSpeed()`), các thay đổi sau đó của `defaultSpeed` đều bị bỏ qua. Muốn đổi tốc độ về sau, hãy gọi [`setSpeed()`](/vi/guide/ref-methods#setspeed-speed) hoặc dùng prop controlled [`speed`](#controlled-mode).
- **Khoảng giá trị.** Native player giới hạn tốc độ trong khoảng 0.25 đến 4. Nút tốc độ và các event vẫn hiển thị giá trị bạn đặt, nên hãy giữ trong khoảng đó.
- **Nhãn** hiển thị một chữ số thập phân. iOS làm tròn (`0.75` hiển thị `0.8x`) còn Android cắt bớt (`0.75` hiển thị `0.7x`), nên hãy ưu tiên tốc độ có tối đa một chữ số thập phân. Xem [Lưu ý theo nền tảng](/vi/guide/platform-notes#speed-pill-label).

## Tự động phát và vị trí bắt đầu {#autoplay-and-start-position}

```tsx
<AudioWaveformView
  source={{ uri }}
  autoPlay
  initialPositionMs={12_000}
  style={{ height: 56 }}
/>
```

Cả hai được áp dụng khi nguồn sẵn sàng (ngay sau `onLoad`), một lần cho mỗi nguồn. `autoPlay` bị bỏ qua khi prop `playing` được đặt; khi đó hãy dùng `playing={true}`.

## Phát lặp {#looping}

Với `loop`, khi đến cuối, việc phát quay về `0` và tiếp tục. `onEnd` không được gọi và trạng thái vẫn là `ready`.

## Chạm play khi đang tải {#tapping-play-while-loading}

Bạn không cần chờ `onLoad`. Một lần chạm nút play, một lời gọi `play()` hay `playing={true}` trong lúc đang tải đều được ghi nhớ, và việc phát bắt đầu ngay khi nguồn sẵn sàng. Spinner vẫn hiển thị cho đến lúc đó.

## Kéo để tua {#scrubbing}

Nhấn vào bất kỳ đâu trên waveform, playhead sẽ nhảy đến đó ngay lập tức. Kéo để di chuyển nó.

- Khi ngón tay còn chạm, việc phát tạm dừng và `onTimeUpdate` ngừng được gọi.
- Khi thả tay, player tua đến vị trí cuối cùng, `onSeek` được gọi, và việc phát tiếp tục nếu trước đó đang phát. Việc phát không tiếp tục nếu hệ thống đã hủy thao tác chạm, hoặc nếu `playing` đang được controlled với giá trị `false`.
- Waveform giành lấy thao tác chạm ngay khi bắt đầu, nên `ScrollView` hoặc `FlatList` cha không thể chiếm thao tác kéo ngang. Một cú vuốt dọc bắt đầu trên waveform sẽ tua thay vì cuộn danh sách.
- Trước khi nguồn sẵn sàng, thời lượng chưa được biết nên kéo không thể tua.

## Khi phát hết {#the-end-of-playback}

Khi âm thanh phát đến cuối mà `loop` tắt, playhead giữ ở trạng thái đầy, nút hiển thị biểu tượng play, trạng thái là `ended` và `onEnd` được gọi. Lần phát tiếp theo bắt đầu từ `0`, kể cả khi bạn tua ở giữa. Muốn bắt đầu từ vị trí khác, hãy phát trước rồi mới tua.

## Controlled mode {#controlled-mode}

Mặc định, component tự quản lý trạng thái phát và tốc độ. Đặt `playing` và/hoặc `speed` để quản lý chúng từ state của bạn:

- Chạm vào nút play hoặc nút tốc độ **không làm thay đổi việc phát**. Nó gửi `onPlayerStateChange` với giá trị **được yêu cầu**.
- Bạn quyết định có áp dụng hay không bằng cách cập nhật prop.
- `play()`, `pause()` và `toggle()` không làm gì khi `playing` được đặt, và `setSpeed()` không làm gì khi `speed` được đặt. `seekTo()` vẫn hoạt động.

```tsx
const [playing, setPlaying] = useState(false);
const [speed, setSpeed] = useState(1);

<AudioWaveformView
  source={{ uri }}
  playing={playing}
  speed={speed}
  onPlayerStateChange={(e) => {
    // Khi đang tải, snapshot báo isPlaying: false kể cả khi đã có yêu cầu phát đang chờ.
    if (e.isPlaying || (e.state !== 'loading' && e.state !== 'idle')) {
      setPlaying(e.isPlaying);
    }
    setSpeed(e.speed);
  }}
  style={{ height: 56 }}
/>;
```

Việc kiểm tra `state` rất quan trọng. Đặt `playing={true}` khi nguồn còn đang tải sẽ xếp lệnh phát vào hàng chờ, nhưng snapshot ngay sau đó vẫn báo `isPlaying: false`. Nếu chép giá trị đó ngược lại, `playing` sẽ thành `false` và lệnh phát đang chờ bị hủy.

### Mỗi lần một tin nhắn thoại {#one-at-a-time}

Mỗi `AudioWaveformView` có native player riêng, nên nhiều view có thể phát cùng lúc. Trong app chat, bạn thường muốn khi bắt đầu phát một tin nhắn thì các tin khác dừng lại. Hãy lưu id của tin đang phát trong state và điều khiển `playing`:

```tsx
function VoiceNoteList({ notes }: { notes: { id: string; uri: string }[] }) {
  const [activeId, setActiveId] = useState<string | null>(null);

  return (
    <FlatList
      data={notes}
      extraData={activeId}
      keyExtractor={(note) => note.id}
      renderItem={({ item }) => (
        <AudioWaveformView
          source={{ uri: item.uri }}
          playing={activeId === item.id}
          onPlayerStateChange={(e) => {
            if (e.isPlaying) {
              setActiveId(item.id);
            } else if (e.state !== 'loading' && e.state !== 'idle') {
              setActiveId((current) => (current === item.id ? null : current));
            }
          }}
          style={{ height: 56, marginVertical: 4 }}
        />
      )}
    />
  );
}
```

Chạm play trên một tin nhắn sẽ đặt nó thành tin đang phát và dừng tin trước đó. Tạm dừng nó, hoặc phát đến cuối, sẽ xóa `activeId`.

## Samples tính sẵn {#pre-computed-samples}

Mặc định, component giải mã âm thanh ngay trên thiết bị để vẽ waveform. Với file remote, điều này nghĩa là phải tải thêm một lần nữa bên cạnh lần stream của chính player (xem [Lưu ý theo nền tảng](/vi/guide/platform-notes#waveform-decoding)). Nếu backend của bạn đã lưu sẵn dữ liệu đỉnh sóng, hãy truyền chúng qua `samples` để bỏ qua bước giải mã:

```tsx
<AudioWaveformView
  source={{ uri: message.audioUrl }}
  samples={message.peaks} // ví dụ 64 giá trị từ 0 đến 1
  style={{ height: 56 }}
/>
```

- Giá trị nên nằm trong `[0, 1]`. Nếu có giá trị lớn hơn `1`, cả mảng sẽ được chia cho giá trị lớn nhất.
- Mảng được lấy mẫu lại theo số thanh, nên 50 đến 100 giá trị là quá đủ cho một bong bóng chat.
- Giá trị đúng bằng `0` được vẽ ở chiều cao placeholder. Hãy dùng một số dương nhỏ cho đoạn im lặng.
- Waveform hiển thị ngay lập tức, không có giai đoạn placeholder.

## Đổi nguồn {#changing-the-source}

Đổi `source.uri` trên một component đang mount sẽ dừng phát và tải file mới; `autoPlay` và `initialPositionMs` được áp dụng lại. Trên iOS, tốc độ được giữ nguyên. Trên Android, tốc độ và waveform cũ hoạt động khác, xem [Lưu ý theo nền tảng](/vi/guide/platform-notes#changing-the-source). Nếu bạn muốn mỗi file bắt đầu từ trạng thái sạch, hãy đặt `key={uri}` cho component để React mount một native view mới cho mỗi nguồn.
