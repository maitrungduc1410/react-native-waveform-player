---
description: "Trình phát tin nhắn thoại native cho React Native: waveform có animation, kéo để tua, nút tốc độ và phát trong nền, viết bằng Swift và Kotlin."
layout: home

hero:
  name: React Native Waveform Player
  text: Tin nhắn thoại, vẽ hoàn toàn native
  tagline: Một Fabric component phát mọi file âm thanh local hoặc remote, kèm nút play, waveform có animation để tua, nhãn thời gian và nút tốc độ. Swift trên iOS, Kotlin trên Android, không có JavaScript trong vòng lặp phát và vẽ.
  actions:
    - theme: brand
      text: Bắt đầu
      link: /vi/guide/quick-start
    - theme: alt
      text: Đây là gì?
      link: /vi/guide/
    - theme: alt
      text: Tài liệu API
      link: /api/

features:
  - title: Waveform native
    details: Các thanh bo tròn được giải mã từ chính file âm thanh ngay trên thiết bị, có thanh placeholder khi đang tải và playhead tô đầy thanh hiện tại đến đúng từng pixel.
    link: /vi/guide/styling
    linkText: Tùy biến giao diện
  - title: Tua và đổi tốc độ
    details: Nhấn giữ rồi kéo ở bất kỳ đâu trên waveform để tua, kể cả khi nằm trong ScrollView. Chạm vào nút tốc độ để xoay vòng qua danh sách tốc độ của riêng bạn.
    link: /vi/guide/playback
    linkText: Tốc độ và phát lại
  - title: Controlled hoặc uncontrolled
    details: Để component tự quản lý trạng thái phát và tốc độ, hoặc điều khiển chúng từ state của bạn qua props playing và speed.
    link: /vi/guide/playback#controlled-mode
    linkText: Controlled mode
  - title: Phát trong nền
    details: Mặc định sẽ tạm dừng khi app chuyển xuống nền. Bật playInBackground để tiếp tục phát; trang hướng dẫn có đủ phần thiết lập cho iOS và Android.
    link: /vi/guide/background-playback
    linkText: Phát trong nền
  - title: Event và phương thức ref
    details: onLoad, onPlayerStateChange, onTimeUpdate, onSeek và onEnd, cùng play, pause, toggle, seekTo và setSpeed trên ref.
    link: /vi/guide/events
    linkText: Sự kiện
  - title: React Native thuần và Expo
    details: Fabric component cho New Architecture. Chạy được trong Expo development build và với expo prebuild, không chạy trong Expo Go.
    link: /vi/guide/installation
    linkText: Cài đặt
---

<div class="home-section vp-doc">

## Cài đặt {#install}

::: code-group

```sh [npm]
npm install react-native-waveform-player
cd ios && pod install
```

```sh [yarn]
yarn add react-native-waveform-player
cd ios && pod install
```

```sh [Expo]
npx expo install react-native-waveform-player
npx expo prebuild
```

:::

Xem [Cài đặt](/vi/guide/installation) để biết yêu cầu hệ thống và chi tiết cho Expo.

## Hiển thị một tin nhắn thoại {#render-a-voice-note}

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

<AudioWaveformView
  source={{ uri: 'https://example.com/voice-note.m4a' }}
  style={{ height: 56 }}
/>;
```

## Thử ngay trên trình duyệt {#try-it-in-the-browser}

<WaveformPlayground :controls="false" :events="false" />

Đổi màu, kích thước thanh và nhiều thứ khác trong [playground tùy biến giao diện](/vi/guide/styling#playground).

## Xem trên thiết bị thật {#see-it-on-a-device}

<div class="demo-shots">
  <figure>
    <img src="../../demo/ios.png" alt="App ví dụ trên iOS với bốn trình phát tin nhắn thoại theo các kiểu khác nhau" loading="lazy" />
    <figcaption>iOS</figcaption>
  </figure>
  <figure>
    <img src="../../demo/android.png" alt="App ví dụ trên Android với bốn trình phát tin nhắn thoại theo các kiểu khác nhau" loading="lazy" />
    <figcaption>Android</figcaption>
  </figure>
</div>

## Cần ghi âm nữa? {#need-to-record-too}

Thư viện này chỉ phát và hiển thị âm thanh. Nếu bạn cần ghi tin nhắn thoại với waveform trực tiếp, hãy xem thư viện anh em [react-native-waveform-recorder](https://maitrungduc1410.github.io/react-native-waveform-recorder/).

</div>
