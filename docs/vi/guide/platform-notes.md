---
description: "Khác biệt của react-native-waveform-player giữa iOS và Android: nguồn âm thanh, giải mã waveform, đổi nguồn, nhãn tốc độ, bố cục, phát trong nền và audio focus."
---

# Lưu ý theo nền tảng {#platform-notes}

Hai bản cài đặt được giữ đồng bộ, nhưng mỗi bản chạy trên player khác nhau của nền tảng. Trang này liệt kê những khác biệt mà bạn có thể nhận thấy.

## Tóm tắt nhanh {#at-a-glance}

| | iOS | Android |
| --- | --- | --- |
| Player | `AVPlayer` | `MediaPlayer` |
| Bộ giải mã waveform | `AVAssetReader` | `MediaExtractor` + `MediaCodec` |
| Waveform cho file remote | Tải file về sau khi player sẵn sàng, rồi giải mã | Stream và giải mã trực tiếp từ URL, song song với player |
| Nguồn | `file://`, `https://` | `file://`, `https://`, `http://`, `content://` |
| Nút play | 60 % chiều cao, tối đa 36 pt | 32 dp |
| Nhãn tốc độ | Làm tròn đến một chữ số thập phân | Cắt còn một chữ số thập phân, theo locale của thiết bị |
| Tạm dừng khi xuống nền ở | `didEnterBackground` | `onHostPause` (`Activity.onPause`) |
| Tốc độ sau khi đổi nguồn | Giữ nguyên | Player quay về 1x |

## Nguồn âm thanh {#sources}

- **iOS** phát mọi thứ `AVPlayer` mở được từ URL: URI local `file://` và URL `https://`. URL `http://` không mã hóa cần ngoại lệ App Transport Security trong app của bạn.
- **Android** truyền thẳng URL `http://` và `https://` cho `MediaPlayer`, còn mọi thứ khác (`file://`, `content://`, ...) đi qua `Uri.parse`. Từ Android 9, `http://` không mã hóa bị chặn trừ khi app của bạn cho phép.
- Định dạng được hỗ trợ là những định dạng mà player của nền tảng hỗ trợ. AAC trong `.m4a` và MP3 chạy được trên cả hai.

## Giải mã waveform {#waveform-decoding}

Hai bộ giải mã cho ra cùng một loại dữ liệu: mỗi thanh ứng với một khoảng thời gian bằng nhau và chứa giá trị RMS của các sample trong đó, được chuẩn hóa theo thanh lớn nhất. Kết quả từng phần được gửi về trong lúc giải mã, nên các thanh được điền dần từ trái sang phải.

- **iOS** không giải mã trực tiếp được URL remote, nên nó tải toàn bộ file bằng `URLSession` rồi giải mã bản sao local. Để mạng rảnh cho lần buffer đầu tiên của player, việc tải chỉ bắt đầu sau `onLoad`. Phần mở rộng file được lấy từ tên file gợi ý của server, MIME type hoặc URL, nếu không có thì dùng `m4a`, nên các link không có phần mở rộng vẫn giải mã được.
- **Android** đọc URL bằng `MediaExtractor`, vốn stream qua HTTP. Việc giải mã bắt đầu ngay, song song với quá trình tải của `MediaPlayer`.

Vì vậy, trên cả hai nền tảng, file remote được tải hai lần: một lần bởi player và một lần bởi bộ giải mã. Hãy truyền [`samples`](/vi/guide/playback#pre-computed-samples) để bỏ qua bộ giải mã khi cần tiết kiệm băng thông.

## Đổi nguồn {#changing-the-source}

Khi `source.uri` thay đổi trên một view đang mount:

- **iOS** tạm dừng, hiển thị thanh placeholder và tải file mới. Tốc độ phát được giữ nguyên.
- **Android** giải phóng `MediaPlayer` cũ và tạo cái mới, player mới phát ở 1x dù nút tốc độ vẫn hiển thị tốc độ trước đó. Waveform và playhead cũ cũng vẫn nằm trên màn hình cho đến khi có dữ liệu mới.

Để có cùng một khởi đầu sạch trên cả hai nền tảng, hãy đặt `key={uri}` cho component để mỗi nguồn có một native view mới, hoặc gọi lại `setSpeed()` sau `onLoad`.

## Nhãn trên nút tốc độ {#speed-pill-label}

Nút hiển thị tốc độ với tối đa một chữ số thập phân:

- **iOS** làm tròn: `0.75` hiển thị `0.8x`, `1.25` hiển thị `1.3x`.
- **Android** cắt bớt: `0.75` hiển thị `0.7x`, `1.25` hiển thị `1.2x`. Android còn định dạng theo locale của thiết bị, nên điện thoại đặt ngôn ngữ dùng dấu phẩy thập phân, như tiếng Việt, sẽ hiển thị `1,5x`.

Các tốc độ có một chữ số thập phân (`0.5`, `1`, `1.5`, `2`) hiển thị cùng các chữ số trên cả hai nền tảng, chỉ khác dấu phân cách thập phân.

## Bố cục và giao diện {#layout-and-look}

- Trên iOS, nút play cao bằng 60 % chiều cao view, tối đa 36 pt; trên Android, nút cố định 32 dp.
- Cột bên phải (nhãn thời gian và nút tốc độ) rộng 56 pt trên iOS và vừa với nội dung trên Android.
- Icon là SF Symbols (`play.fill`, `pause.fill`) trên iOS và vector drawable trên Android. Spinner khi tải là `UIActivityIndicatorView` trên iOS và `ProgressBar` trên Android, cả hai đều có màu `playButtonColor`.
- Nhãn thời gian dùng chữ semibold trên iOS và bold trên Android, cả hai đều 13 pt/sp.

## Phát trong nền {#background}

- **iOS** tạm dừng khi `didEnterBackground`. Âm thanh nền cần background mode Audio, và thư viện chuyển `AVAudioSession` sang `.playback` khi `playInBackground` được bật.
- **Android** tạm dừng khi `onHostPause`, event này cũng xảy ra khi một activity khác che activity của bạn. Phát khi thiết bị ngủ cần quyền tùy chọn `WAKE_LOCK`.

Chi tiết xem ở [Phát trong nền](/vi/guide/background-playback).

## Audio focus và các app khác {#audio-focus-and-other-apps}

- **iOS:** với `playInBackground` hoặc `ignoreSilentSwitch`, session `.playback` sẽ ngắt âm thanh của các app khác khi bắt đầu phát. Nếu không bật, thư viện để nguyên session và category của app bạn được áp dụng. Với category mặc định của iOS (`soloAmbient`), công tắc im lặng sẽ tắt tiếng khi phát.
- **Android:** thư viện không yêu cầu audio focus, nên các app khác không được yêu cầu tạm dừng hay giảm âm lượng khi một tin nhắn thoại bắt đầu phát.

## seekTo() khi đang dừng {#seekto-while-paused}

Trên Android, gọi `seekTo()` khi đang dừng sẽ cập nhật nhãn thời gian ngay, nhưng phần đã phát của waveform chỉ cập nhật theo khi phát tiếp. Kéo trên waveform cập nhật cả hai ngay lập tức trên cả hai nền tảng.

## Khi unmount {#unmounting}

- **iOS:** Fabric tái sử dụng native view. Khi component unmount, thư viện dừng player và reset view trước khi đưa nó về pool, nên không còn âm thanh nào tiếp tục phát.
- **Android:** player được giải phóng khi view bị tách khỏi window.

## Trợ năng {#accessibility}

Nút play, nút tốc độ và waveform có sẵn hiện chưa đặt nhãn hay action trợ năng trên cả hai nền tảng. Nếu bạn cần hỗ trợ trình đọc màn hình, hãy cân nhắc ẩn các nút có sẵn và tự thêm các nút có hỗ trợ trợ năng gọi đến [phương thức ref](/vi/guide/ref-methods).

## Không hỗ trợ {#not-supported}

- **Old Architecture:** component chỉ hỗ trợ Fabric.
- **Web:** import package vẫn chạy (để code dùng chung vẫn type-check được), nhưng render `AudioWaveformView` trên web sẽ throw `'react-native-waveform-player' is only supported on native platforms.`
