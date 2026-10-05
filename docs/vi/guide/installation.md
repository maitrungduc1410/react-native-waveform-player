---
description: "Cài đặt react-native-waveform-player vào app React Native thuần hoặc Expo development build, kèm yêu cầu New Architecture và bước cài pod cho iOS."
---

# Cài đặt {#installation}

## Yêu cầu {#requirements}

- **React Native đã bật New Architecture.** Component chỉ hỗ trợ Fabric. New Architecture được bật mặc định từ React Native 0.76 và từ Expo SDK 52 trở lên.
- **iOS:** phiên bản iOS tối thiểu theo phiên bản React Native bạn dùng. Pod liên kết với `AVFoundation`, `CoreMedia`, `QuartzCore` và `UIKit`, đều có sẵn trong iOS.
- **Android:** min SDK 24.

Ngoài `react` và `react-native`, thư viện không có dependency JavaScript nào khác.

## React Native thuần {#bare-react-native}

Cài package:

::: code-group

```sh [npm]
npm install react-native-waveform-player
```

```sh [yarn]
yarn add react-native-waveform-player
```

:::

Sau đó cài pod cho iOS:

```sh
cd ios && pod install
```

Build lại app (`npx react-native run-ios`, `run-android` hoặc từ IDE). Chỉ reload Metro là không đủ sau khi thêm code native.

## Expo {#expo}

Thư viện có code native nên **không chạy trong Expo Go**. Hãy dùng [development build](https://docs.expo.dev/develop/development-builds/introduction/) hoặc EAS Build. Autolinking tự nhận thư viện, không cần config plugin.

```sh
npx expo install react-native-waveform-player
npx expo prebuild
npx expo run:ios
npx expo run:android
```

Nếu bạn dùng [phát trong nền](/vi/guide/background-playback), hãy khai báo background mode cho iOS và quyền `WAKE_LOCK` cho Android trong `app.json` thay vì sửa trực tiếp các project native được sinh ra, vì `expo prebuild` sẽ tạo lại chúng. Cấu hình cụ thể có trong [Phát trong nền](/vi/guide/background-playback#expo).

## Quyền {#permissions}

Với việc phát thông thường, bạn không cần thêm gì:

- **Android:** manifest của thư viện đã khai báo `android.permission.INTERNET`, quyền này được merge vào app của bạn nên URL remote chạy được ngay.
- **iOS:** không cần key nào trong `Info.plist`. URL `http://` không mã hóa sẽ bị App Transport Security chặn nếu app của bạn chưa cho phép, nên hãy ưu tiên `https://`.

Phát trong nền cần thiết lập thêm trên iOS, và tùy chọn trên Android. Xem [Phát trong nền](/vi/guide/background-playback).

## Kiểm tra hoạt động {#check-that-it-works}

Render component với URL của một file âm thanh mà bạn biết chắc phát được, và đặt chiều cao cho nó:

```tsx
import { AudioWaveformView } from 'react-native-waveform-player';

export function Check() {
  return (
    <AudioWaveformView
      source={{ uri: 'https://example.com/voice-note.m4a' }}
      style={{ height: 56 }}
      onLoad={(e) => console.log('loaded', e.durationMs)}
      onLoadError={(e) => console.warn('load error', e.message)}
    />
  );
}
```

Ban đầu bạn sẽ thấy các thanh placeholder và spinner, sau đó là waveform thật. Nếu không thấy gì, xem [Khắc phục sự cố](/vi/guide/troubleshooting).
