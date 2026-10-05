---
description: "Keep voice notes playing when the app is in the background: playInBackground, the iOS audio background mode, AVAudioSession, Android WAKE_LOCK and Expo config."
---

# Background playback

## Default: pause in the background

By default the component pauses when the app leaves the foreground:

- **iOS:** on `UIApplication.didEnterBackgroundNotification`. Pulling down Control Center does not pause it, because the app stays in the foreground.
- **Android:** on the React Native `onHostPause` lifecycle event, which follows `Activity.onPause`. That also happens when another activity opens on top of yours, such as a system share sheet.

Playback does not resume by itself when the app comes back. The user taps play again, or you call `play()`.

## Opt in with playInBackground

```tsx
<AudioWaveformView source={{ uri }} playInBackground style={{ height: 56 }} />
```

With `playInBackground`, the component leaves playback alone when the app goes to the background. iOS needs one capability for this to work; Android works out of the box and has one optional permission.

## iOS setup

Enable the **Audio** background mode on the app target, in one of two ways:

1. In Xcode, open the app target, go to **Signing & Capabilities**, add **Background Modes** and check **Audio, AirPlay, and Picture in Picture**.
2. Or add this to `Info.plist`:

   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
   </array>
   ```

Without it, iOS suspends the app shortly after it goes to the background and the audio stops.

### What the library does with AVAudioSession

When `playInBackground` becomes `true`, the library configures the shared `AVAudioSession`:

- If the category is already `.playback` or `.playAndRecord`, it only activates the session.
- Otherwise it sets the category to `.playback` (default mode, no options) and activates it.

The `.playback` category plays even when the silent switch is on, and it interrupts audio from other apps, such as a music app. If you need different behavior, for example mixing with other audio, set the category yourself to `.playback` or `.playAndRecord` with your options before the component mounts. The library keeps it.

Setting `playInBackground` back to `false` does not restore the previous category.

When `playInBackground` is `false`, the library does not touch `AVAudioSession` at all. See [No sound on iPhone in silent mode](/guide/troubleshooting#no-sound-in-silent-mode) for what that means.

## Android setup

Nothing is required for typical voice notes: `MediaPlayer` keeps playing after the activity is paused.

If playback must continue while the **device sleeps** (screen off and idle), add the `WAKE_LOCK` permission to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

With the permission, the library calls `MediaPlayer.setWakeMode(PARTIAL_WAKE_LOCK)` whenever `playInBackground` is `true`. Without it, that call is skipped and Logcat shows a warning from the `AudioPlayerEngine` tag:

```text
playInBackground=true but WAKE_LOCK permission is not granted ...
```

Playback then continues in the background while the screen is on, and pauses when the device sleeps.

The library does not start a foreground service or a media session. That is fine for voice notes, but Android can still stop a backgrounded app to free memory, so it is not meant for long-form audio.

## Expo {#expo}

`expo prebuild` regenerates `ios/` and `android/`, so put both settings in `app.json` (or `app.config.js`) instead of editing the native files:

```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "UIBackgroundModes": ["audio"]
      }
    },
    "android": {
      "permissions": ["android.permission.WAKE_LOCK"]
    }
  }
}
```

Both entries are only needed when you use `playInBackground`. Run `npx expo prebuild` again, or start a new EAS build, after changing them.

## Lock screen and Now Playing

The library does not publish lock screen controls, `MPNowPlayingInfoCenter` data on iOS or a media notification on Android. `onTimeUpdate` keeps firing in the background, so you can drive your own integration from it.

## pauseUiUpdatesInBackground

While the app is in the background, the view is not visible, yet the progress tick (about 30 per second) would still update the bars and format the time label. With `pauseUiUpdatesInBackground` (default `true`), those updates are skipped, and the view snaps to the current position when the app returns.

- `onTimeUpdate` fires either way.
- Set it to `false` only if something you render needs the native bars and label to stay updated while in the background. That is rare.
