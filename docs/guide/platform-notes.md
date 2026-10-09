---
description: "How react-native-waveform-player differs on iOS and Android: sources, waveform decoding, source changes, speed labels, layout, background and audio focus."
---

# Platform notes

The two implementations are kept in step, but they sit on different platform players. This page lists the differences you can notice.

## At a glance

| | iOS | Android |
| --- | --- | --- |
| Player | `AVPlayer` | `MediaPlayer` |
| Waveform decoder | `AVAssetReader` | `MediaExtractor` + `MediaCodec` |
| Remote waveform | Downloads the file after the player is ready, then decodes it | Streams and decodes from the URL, in parallel with the player |
| Sources | `file://`, `https://` | `file://`, `https://`, `http://`, `content://` |
| Play button | 60 % of the height, up to 36 pt | 32 dp |
| Speed label | Rounded to one decimal | Truncated to one decimal, device locale |
| Pauses in background on | `didEnterBackground` | `onHostPause` (`Activity.onPause`) |
| Speed after a source change | Kept | Reset to 1x in the player |

## Sources {#sources}

- **iOS** plays anything `AVPlayer` can open from a URL: local `file://` URIs and `https://` URLs. Plain `http://` needs an App Transport Security exception in your app.
- **Android** passes `http://` and `https://` URLs to `MediaPlayer` directly, and everything else (`file://`, `content://`, ...) through `Uri.parse`. Since Android 9, cleartext `http://` is blocked unless your app allows it.
- Supported formats are whatever the platform player supports. AAC in `.m4a` and MP3 work on both.

## Waveform decoding {#waveform-decoding}

Both decoders produce the same data: each bar covers an equal slice of time and holds the RMS of the samples in it, normalised against the loudest bar. Partial results arrive while decoding runs, so the bars fill in from left to right.

- **iOS** cannot decode a remote URL directly, so it downloads the whole file with `URLSession` and decodes the local copy. To keep the network free for the player's initial buffering, the download starts only after `onLoad`. The file extension is taken from the server's suggested filename, the MIME type or the URL, falling back to `m4a`, so links without an extension still decode.
- **Android** reads the URL with `MediaExtractor`, which streams over HTTP. Decoding starts right away, alongside `MediaPlayer`'s own loading.

On both platforms a remote file is therefore fetched twice: once by the player and once by the decoder. Pass [`samples`](/guide/playback#pre-computed-samples) to skip the decoder when bandwidth matters.

## Changing the source {#changing-the-source}

When `source.uri` changes on a mounted view:

- **iOS** pauses, shows placeholder bars, and loads the new file. The playback speed carries over.
- **Android** releases the old `MediaPlayer` and creates a new one, which plays at 1x even though the speed pill keeps showing the previous speed. The previous waveform and playhead also stay on screen until new data arrives.

To get the same clean start on both platforms, give the component `key={uri}` so each source gets a new native view, or call `setSpeed()` again after `onLoad`.

## Speed pill label {#speed-pill-label}

The pill shows the speed with at most one decimal place:

- **iOS** rounds: `0.75` shows `0.8x`, `1.25` shows `1.3x`.
- **Android** truncates: `0.75` shows `0.7x`, `1.25` shows `1.2x`. It also formats with the device locale, so a phone set to a language that uses a decimal comma, such as Vietnamese, shows `1,5x`.

Speeds with one decimal place (`0.5`, `1`, `1.5`, `2`) show the same digits on both, apart from the decimal separator.

## Layout and look

- The play button is 60 % of the view height, up to 36 pt, on iOS, and a fixed 32 dp on Android.
- The right column (time label and speed pill) is 56 pt wide on iOS and sized to its content on Android.
- Icons are SF Symbols (`play.fill`, `pause.fill`) on iOS and vector drawables on Android. The loading spinner is `UIActivityIndicatorView` on iOS and `ProgressBar` on Android, both tinted with `playButtonColor`.
- The time label is semibold on iOS and bold on Android, both at 13 pt/sp.

## Background

- **iOS** pauses on `didEnterBackground`. Background audio needs the Audio background mode, and the library switches `AVAudioSession` to `.playback` when `playInBackground` is on.
- **Android** pauses on `onHostPause`, which also fires when another activity covers yours. Device sleep needs the optional `WAKE_LOCK` permission.

Details in [Background playback](/guide/background-playback).

## Audio focus and other apps

- **iOS:** with `playInBackground` or `ignoreSilentSwitch`, the `.playback` session interrupts other apps' audio when playback starts. Without them, the library leaves the session alone and your app's category applies. With the iOS default category (`soloAmbient`), the silent switch mutes playback.
- **Android:** the library does not request audio focus, so other apps are not asked to pause or lower their volume when a voice note starts.

## seekTo() while paused

On Android, calling `seekTo()` while paused updates the time label right away, but the played part of the waveform only catches up when playback resumes. Dragging on the waveform updates both immediately on both platforms.

## Unmounting

- **iOS:** Fabric reuses native views. When the component unmounts, the library stops the player and resets the view before it goes back to the pool, so no audio keeps playing.
- **Android:** the player is released when the view is detached from the window.

## Accessibility

The built-in play button, speed pill and waveform do not set accessibility labels or actions yet, on either platform. If screen reader support matters, consider hiding the built-in controls and adding your own accessible buttons that call the [ref methods](/guide/ref-methods).

## Not supported

- **Old Architecture:** the component is Fabric only.
- **Web:** importing the package works (so shared code type-checks), but rendering `AudioWaveformView` on web throws `'react-native-waveform-player' is only supported on native platforms.`
