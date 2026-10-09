---
description: "Fixes for common react-native-waveform-player issues: blank view, no sound in silent mode, stuck spinner, placeholder bars, background stops, controlled taps."
---

# Troubleshooting

## Nothing shows up {#nothing-shows-up}

- **Give the view a height.** The native view has no intrinsic size. Add a `height` to its `style` (56 suits a chat bubble), or make sure a parent stretches it.
- **Rebuild the app.** After installing, run `pod install` for iOS and rebuild both platforms. A JavaScript reload does not load new native code.
- **Check the New Architecture.** The component is Fabric only. If the New Architecture is turned off in your app, the native component is not registered.
- **Expo Go is not supported.** Use a [development build](/guide/installation#expo).
- **Web throws** `'react-native-waveform-player' is only supported on native platforms.` Render the component only on iOS and Android, for example behind `Platform.OS !== 'web'`.

## No sound on iPhone in silent mode {#no-sound-in-silent-mode}

By default the library does not configure `AVAudioSession`, so your app's category applies. The iOS default category is muted by the Ring / Silent switch. Either:

- set [`ignoreSilentSwitch`](/guide/props#background), which switches the session to `.playback` when playback starts, or
- set your app's audio session category to `.playback` yourself (natively, or with an audio library you already use), or
- turn on [`playInBackground`](/guide/background-playback) if you also want playback to continue in the background. It switches the session to `.playback` the same way.

## The spinner never stops

The player could not get ready. Add `onLoadError` and look at the message:

- **HTTP URLs:** iOS blocks `http://` through App Transport Security, and Android 9 and later blocks cleartext traffic by default. Use `https://`, or allow the domain in your app config.
- **Wrong scheme:** local files need a `file://` URI with an absolute path. `content://` URIs work on Android only.
- **iOS URL parsing:** if iOS cannot parse the string as a URL, `onLoadError` fires with the URI itself as the message. Percent-encode spaces and other special characters, for example with `encodeURI()`.
- **Unsupported format:** the platform player has to support the file. AAC (`.m4a`) and MP3 work on both platforms.

## The waveform stays as flat placeholder bars

Playback works but the bars never take shape. The waveform decoder failed, and `onLoadError` tells you why (for example `Audio track not found` on iOS or `No audio track found` on Android).

- On iOS, remote files are downloaded once more for decoding, so a URL that only allows one request, or that expires quickly, can fail.
- If your server already knows the peaks, pass [`samples`](/guide/playback#pre-computed-samples) and skip decoding entirely.
- With `samples`, values of exactly `0` are drawn at placeholder height. Use a small positive number for silence.

## Audio stops when the app goes to the background

That is the default. Set [`playInBackground`](/guide/background-playback). On iOS you also need the **Audio** background mode; without it the app is suspended and playback stops.

## Android stops when the screen turns off

Add the `WAKE_LOCK` permission to your app manifest (or `android.permissions` in Expo `app.json`). Without it, Logcat shows `playInBackground=true but WAKE_LOCK permission is not granted` from `AudioPlayerEngine`. See [Android setup](/guide/background-playback#android-setup).

## Taps on play or the speed pill do nothing

You set `playing` or `speed`, so the component is controlled. Taps only send `onPlayerStateChange` with the requested value; update your prop in the handler. `play()`, `pause()`, `toggle()` and `setSpeed()` are also ignored while the matching prop is set. See [Controlled mode](/guide/playback#controlled-mode).

## A controlled player starts and stops right away

Your `onPlayerStateChange` handler copies `isPlaying: false` back to `playing` while the source is still loading. Snapshots in the `loading` state report `isPlaying: false` even when a start is queued. Ignore `false` while `state` is `loading` or `idle`, as in the [controlled mode example](/guide/playback#controlled-mode).

## Several voice notes play at the same time

Each component has its own native player. To allow only one at a time, control `playing` from a shared "active note" state, as shown in [One voice note at a time](/guide/playback#one-at-a-time).

## Play starts from the beginning after the end

After `onEnd` the state is `ended`, and the next play always starts from `0`, even if you seeked in between. Call `play()` first, then `seekTo()`.

## Swiping the list scrolls the waveform instead

The waveform claims touches as soon as they start, so a parent `ScrollView` cannot steal a drag. This also means a swipe that starts on the waveform scrubs instead of scrolling. Leave some space around the player that users can scroll from.

## On Android, a new source plays at 1x

Changing `source` on Android creates a new player that runs at 1x, while the pill still shows the old speed. Give the component `key={uri}`, or call `setSpeed()` after `onLoad`. See [Changing the source](/guide/platform-notes#changing-the-source).

## The speed label shows 0.8x or 1,5x

The pill shows one decimal place. iOS rounds and Android truncates, and Android uses the device's decimal separator. See [Speed pill label](/guide/platform-notes#speed-pill-label).
