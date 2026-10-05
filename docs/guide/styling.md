---
description: "Style AudioWaveformView: layout of the button, bars, time label and speed pill, colors, bar geometry, hiding parts, light and dark themes, and a playground."
---

# Styling

## Playground {#playground}

Every control below maps to a real prop, and the code under it updates as you go. This is a web approximation built from the iOS layout numbers; on a device the component is drawn natively, with the platform's own font and icons.

<WaveformPlayground :events="false" />

## Layout

From left to right, inside the container:

1. **12 pt of padding**, on both sides.
2. **Play button**, a square. On iOS it is 60 % of the view height, up to 36 pt. On Android it is 32 dp.
3. **8 pt gap**, then the **bars area**, which takes all the remaining width and the full height.
4. **8 pt gap**, then a column with the **time label** (13 pt, semibold) above the **speed pill** (44 × 22, fully rounded, 12 pt text). On iOS the column is 56 pt wide; on Android it is as wide as its content.

Hiding the play button, or both the time label and the speed pill, gives that space to the bars. The component never sets its own height: set one in `style`.

```tsx
<AudioWaveformView source={{ uri }} style={{ height: 56, marginVertical: 4 }} />
```

## Bars

- The number of bars is `floor(barsAreaWidth / (barWidth + barGap))`, unless you set `barCount` lower. Bars start at the left edge, so up to one bar step stays empty on the right.
- Each bar is centered vertically. The bars area keeps `barWidth × 1.5` free at the top and the bottom, and the loudest bar fills the rest.
- The shortest bar is `barWidth` tall. With the default radius (`barWidth / 2`), quiet parts show as round dots.
- While the audio loads, all bars are drawn at 20 % height. When the waveform arrives, they grow to their real height over about 200 ms.

```tsx
// Thin, dense bars
<AudioWaveformView source={{ uri }} barWidth={2} barGap={1.5} style={{ height: 48 }} />

// Chunky square bars
<AudioWaveformView source={{ uri }} barWidth={5} barGap={3} barRadius={0} style={{ height: 64 }} />

// Always 40 bars, whatever the width
<AudioWaveformView source={{ uri }} barCount={40} style={{ height: 56 }} />
```

## Colors

| Part | Props |
| --- | --- |
| Container | `containerBackgroundColor`, `containerBorderRadius` |
| Bars | `playedBarColor`, `unplayedBarColor` |
| Play button and spinner | `playButtonColor` |
| Time label | `timeColor` |
| Speed pill | `speedColor` (text), `speedBackgroundColor` |

A translucent version of the played color usually works well for `unplayedBarColor`, as in the defaults (`#FFFFFF` and `rgba(255, 255, 255, 0.5)`).

## Hiding parts {#hiding-parts}

Each part has its own switch: `showPlayButton`, `showTime`, `showSpeedControl` and `showBackground`. With everything off you get a bare waveform that still supports dragging to seek, which is handy when you build your own controls around it with [ref methods](/guide/ref-methods):

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

## Light and dark themes

Props are plain values, so switch them with `useColorScheme()`:

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

## Sent and received bubbles

Chat apps often style the sender's notes differently. Pass a different palette per message and keep the geometry the same so the bubbles line up:

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
