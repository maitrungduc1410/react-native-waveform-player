---
description: "Speeds, autoplay, start position, looping, scrubbing, controlled mode, one voice note at a time and pre-computed samples in react-native-waveform-player."
---

# Speed and playback

## Speed {#speed}

The speed pill shows the current speed, for example `1x` or `1.5x`. Each tap moves to the **first value in `speeds` that is larger than the current speed**, and wraps to the first value after the largest one. List the speeds in ascending order; with an unsorted list the pill can skip values or get stuck.

```tsx
<AudioWaveformView
  source={{ uri }}
  speeds={[1, 1.25, 1.5, 2]}
  defaultSpeed={1}
  style={{ height: 56 }}
/>
```

- **`defaultSpeed`** is the speed the pill starts with. It is applied once: after the first speed is applied (by `defaultSpeed` itself, a tap or `setSpeed()`), later changes to `defaultSpeed` are ignored. To change the speed afterwards, call [`setSpeed()`](/guide/ref-methods#setspeed-speed) or use the controlled [`speed`](#controlled-mode) prop.
- **Range.** The native players clamp the speed to 0.25 to 4. The pill and the events still show the value you set, so stay inside that range.
- **Labels** show one decimal place. iOS rounds (`0.75` shows `0.8x`) while Android truncates (`0.75` shows `0.7x`), so prefer speeds with at most one decimal. See [Platform notes](/guide/platform-notes#speed-pill-label).

## Autoplay and start position

```tsx
<AudioWaveformView
  source={{ uri }}
  autoPlay
  initialPositionMs={12_000}
  style={{ height: 56 }}
/>
```

Both are applied when the source becomes ready (right after `onLoad`), once per source. `autoPlay` is ignored when the `playing` prop is set; set `playing={true}` instead.

## Looping

With `loop`, playback jumps back to `0` at the end and continues. `onEnd` does not fire and the state stays `ready`.

## Tapping play while loading

You do not have to wait for `onLoad`. A tap on the play button, a `play()` call or `playing={true}` during loading is remembered, and playback starts the moment the source is ready. The spinner stays until then.

## Scrubbing {#scrubbing}

Press anywhere on the waveform and the playhead jumps there, with no delay. Drag to move it.

- While the finger is down, playback pauses and `onTimeUpdate` stops.
- On release, the player seeks to the final position, `onSeek` fires, and playback resumes if it was playing before. It does not resume if the system cancelled the touch, or if `playing` is controlled and `false`.
- The waveform claims the touch as soon as it starts, so a parent `ScrollView` or `FlatList` cannot steal a horizontal drag. A vertical swipe that starts on the waveform scrubs instead of scrolling the list.
- Before the source is ready, the duration is unknown and dragging cannot seek.

## The end of playback

When the audio reaches the end with `loop` off, the playhead stays full, the button shows the play icon, the state is `ended` and `onEnd` fires. The next play starts from `0`, even if you seek in between. To start from another position, play first and then seek.

## Controlled mode {#controlled-mode}

By default the component manages playing and speed itself. Set `playing` and/or `speed` to manage them from your state instead:

- A tap on the play button or speed pill **does not change playback**. It sends `onPlayerStateChange` with the **requested** value.
- You decide whether to apply it by updating the prop.
- `play()`, `pause()` and `toggle()` do nothing while `playing` is set, and `setSpeed()` does nothing while `speed` is set. `seekTo()` keeps working.

```tsx
const [playing, setPlaying] = useState(false);
const [speed, setSpeed] = useState(1);

<AudioWaveformView
  source={{ uri }}
  playing={playing}
  speed={speed}
  onPlayerStateChange={(e) => {
    // While loading, snapshots report isPlaying: false even when a start is queued.
    if (e.isPlaying || (e.state !== 'loading' && e.state !== 'idle')) {
      setPlaying(e.isPlaying);
    }
    setSpeed(e.speed);
  }}
  style={{ height: 56 }}
/>;
```

The check on `state` matters. Setting `playing={true}` while the source is still loading queues the start, but the snapshot that follows still says `isPlaying: false`. Copying that value back would set `playing` to `false` and cancel the queued start.

### One voice note at a time {#one-at-a-time}

Each `AudioWaveformView` has its own native player, so several can play at the same time. In a chat you usually want starting one note to stop the others. Keep the active note's id in state and control `playing`:

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

Tapping play on a note makes it active and pauses the previous one. Pausing it, or reaching the end, clears `activeId`.

## Pre-computed samples {#pre-computed-samples}

By default the component decodes the audio on the device to draw the waveform. For remote files this means a second download next to the player's own streaming (see [Platform notes](/guide/platform-notes#waveform-decoding)). If your backend already stores peaks, pass them as `samples` and the decoder is skipped:

```tsx
<AudioWaveformView
  source={{ uri: message.audioUrl }}
  samples={message.peaks} // for example 64 values between 0 and 1
  style={{ height: 56 }}
/>
```

- Values should be in `[0, 1]`. If any value is above `1`, the whole array is divided by its largest value.
- The array is resampled to the number of bars, so 50 to 100 values are plenty for a chat bubble.
- A value of exactly `0` is drawn at placeholder height. Use a small positive number for silence.
- The waveform shows immediately, with no placeholder phase.

## Changing the source

Changing `source.uri` on a mounted component stops playback and loads the new file; `autoPlay` and `initialPositionMs` apply again. On iOS the speed carries over. On Android, the speed and the old waveform behave differently, see [Platform notes](/guide/platform-notes#changing-the-source). If you want every file to start from a clean state, give the component `key={uri}` so React mounts a new native view per source.
