---
description: "Render a voice note with AudioWaveformView in a few lines: a remote or local source, a height, a custom theme, events and the imperative ref."
---

# Quick start

## Your first voice note

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

Two things are required:

- **`source`** with a `uri`. Remote `https://` URLs and local `file://` URIs work on both platforms.
- **A height.** The native view has no intrinsic size, so without a height in `style` (or a parent that stretches it) it renders nothing. 48 to 64 works well for a chat bubble.

The component is uncontrolled by default: the play button, the speed pill and dragging on the waveform all work without any code from you.

## Play a local file

Pass an absolute `file://` URI, for example a file you recorded or downloaded:

```tsx
<AudioWaveformView
  source={{ uri: 'file:///path/to/Documents/note-42.m4a' }}
  style={{ height: 56 }}
/>
```

Local files load in a few milliseconds, so the spinner barely shows. On Android, `content://` URIs work as well.

## Match your theme

Every color and the bar geometry are props:

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

Try the values live in the [styling playground](/guide/styling#playground).

## Listen to events

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

`onPlayerStateChange` sends a full snapshot on every change, so compare it with your own state instead of counting events. See [Events](/guide/events).

## Control it from code

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

All methods are listed in [Ref methods](/guide/ref-methods).

## Next steps

- [Props](/guide/props): every prop with its default
- [Speed and playback](/guide/playback): speeds, looping, controlled mode, one voice note at a time
- [Background playback](/guide/background-playback): keep playing when the app is in the background
