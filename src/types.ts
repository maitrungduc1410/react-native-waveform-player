import type { ColorValue, ViewProps } from 'react-native';

/**
 * Playback state reported in {@link AudioWaveformPlayerStateEvent.state}.
 *
 * - `idle`: no source loaded.
 * - `loading`: the source is set and the native player is buffering it.
 * - `ready`: the player can play; check `isPlaying` to see whether it is.
 * - `ended`: playback reached the end and `loop` is off.
 * - `error`: the native player failed to load or play the source.
 */
export type AudioWaveformPlayerState =
  | 'idle'
  | 'loading'
  | 'ready'
  | 'ended'
  | 'error';

/**
 * What the time label shows: elapsed time (`count-up`) or remaining time
 * (`count-down`), formatted as `m:ss`.
 */
export type AudioWaveformTimeMode = 'count-up' | 'count-down';

/**
 * Audio to play. `file://` and `https://` work on both platforms;
 * `content://` URIs work on Android.
 */
export type AudioWaveformSource = { uri: string };

/** Payload of the `onPlayerStateChange` prop of {@link AudioWaveformView}. */
export type AudioWaveformPlayerStateEvent = {
  /** Current player state. */
  state: AudioWaveformPlayerState;
  /**
   * Whether audio is playing. In controlled mode, a tap on the play button
   * reports the requested value here without changing playback.
   */
  isPlaying: boolean;
  /**
   * Current playback rate. In controlled mode, a tap on the speed pill
   * reports the requested next speed here without changing playback.
   */
  speed: number;
  /** Native error message, present only when the player failed. */
  error?: string;
};

/** Payload of the `onTimeUpdate` prop of {@link AudioWaveformView}. */
export type AudioWaveformTimeUpdateEvent = {
  /** Playback position in milliseconds. */
  currentTimeMs: number;
  /** Duration of the source in milliseconds. */
  durationMs: number;
};

/** Payload of the `onSeek` prop of {@link AudioWaveformView}. */
export type AudioWaveformSeekEvent = {
  /** Position the player seeked to, in milliseconds. */
  positionMs: number;
};

/** Payload of the `onLoad` prop of {@link AudioWaveformView}. */
export type AudioWaveformLoadEvent = {
  /** Duration of the source in milliseconds, or `0` if it is unknown. */
  durationMs: number;
};

/** Payload of the `onLoadError` prop of {@link AudioWaveformView}. */
export type AudioWaveformLoadErrorEvent = {
  /** Native error message from the player or the waveform decoder. */
  message: string;
};

/**
 * Props of {@link AudioWaveformView}. Standard `View` props such as `style`
 * and `testID` are accepted too (except `children`). Give the view a height
 * in `style`, because it has no intrinsic size.
 */
export type AudioWaveformViewProps = Omit<ViewProps, 'children'> & {
  /**
   * Audio to play. Changing `uri` stops playback and loads the new source.
   */
  source: AudioWaveformSource;

  /**
   * Pre-computed amplitudes in `[0, 1]`, resampled to the bar count. When
   * non-empty, native waveform decoding is skipped. Arrays with values above
   * `1` are normalised against the largest value.
   */
  samples?: ReadonlyArray<number>;

  /**
   * Color of the played part of the bars, left of the playhead.
   * Defaults to `'#FFFFFF'`.
   */
  playedBarColor?: ColorValue;
  /**
   * Color of the part of the bars that has not been played yet.
   * Defaults to `'rgba(255, 255, 255, 0.5)'`.
   */
  unplayedBarColor?: ColorValue;

  /**
   * Bar width in points (iOS) or dp (Android).
   * Defaults to `3`.
   */
  barWidth?: number;
  /**
   * Gap between bars in points (iOS) or dp (Android).
   * Defaults to `2`.
   */
  barGap?: number;
  /**
   * Bar corner radius in points (iOS) or dp (Android).
   * Defaults to `barWidth / 2`.
   */
  barRadius?: number;
  /**
   * Fixed number of bars. By default, as many bars as fit the available
   * width. A larger value is capped to what fits.
   */
  barCount?: number;

  /**
   * Background color of the rounded container. Ignored when
   * `showBackground` is `false`.
   * Defaults to `'#3478F6'`.
   */
  containerBackgroundColor?: ColorValue;
  /**
   * Corner radius of the container. Ignored when `showBackground` is `false`.
   * Defaults to `16`.
   */
  containerBorderRadius?: number;
  /**
   * Whether to draw the rounded container background.
   * Defaults to `true`.
   */
  showBackground?: boolean;

  /**
   * Whether to show the play / pause button.
   * Defaults to `true`.
   */
  showPlayButton?: boolean;
  /**
   * Tint of the play / pause icon and of the loading spinner.
   * Defaults to `'#FFFFFF'`.
   */
  playButtonColor?: ColorValue;

  /**
   * Whether to show the time label.
   * Defaults to `true`.
   */
  showTime?: boolean;
  /**
   * Text color of the time label.
   * Defaults to `'#FFFFFF'`.
   */
  timeColor?: ColorValue;
  /**
   * Show elapsed time (`count-up`) or remaining time (`count-down`).
   * Defaults to `'count-up'`.
   */
  timeMode?: AudioWaveformTimeMode;

  /**
   * Whether to show the speed pill.
   * Defaults to `true`.
   */
  showSpeedControl?: boolean;
  /**
   * Text color of the speed pill.
   * Defaults to `'#FFFFFF'`.
   */
  speedColor?: ColorValue;
  /**
   * Background color of the speed pill.
   * Defaults to `'rgba(255, 255, 255, 0.25)'`.
   */
  speedBackgroundColor?: ColorValue;
  /**
   * Speeds the pill cycles through on tap. Each tap picks the first value
   * greater than the current speed and wraps to the first value, so list
   * them in ascending order. An empty array falls back to the default.
   * Defaults to `[0.5, 1, 1.5, 2]`.
   */
  speeds?: ReadonlyArray<number>;
  /**
   * Initial playback speed. Applied until the speed is changed by a tap,
   * `setSpeed()` or the `speed` prop.
   * Defaults to `1`.
   */
  defaultSpeed?: number;

  /**
   * Start playing as soon as the source is ready. Ignored when `playing` is
   * set.
   * Defaults to `false`.
   */
  autoPlay?: boolean;
  /**
   * Position to seek to once the source is ready, in milliseconds.
   * Defaults to `0`.
   */
  initialPositionMs?: number;
  /**
   * Restart from the beginning when playback ends. `onEnd` does not fire
   * while looping.
   * Defaults to `false`.
   */
  loop?: boolean;

  /**
   * Keep playing when the host app goes to the background. When `false`,
   * playback pauses on `didEnterBackground` (iOS) or `onHostPause`
   * (Android) and does not resume by itself.
   *
   * On iOS, the host app must enable the "Audio, AirPlay, and Picture in
   * Picture" Background Mode (`UIBackgroundModes: [audio]` in `Info.plist`).
   * When playback starts, the library sets the shared `AVAudioSession`
   * category to `.playback` and activates it, unless the category is
   * already `.playback` or `.playAndRecord`. On Android, nothing is required
   * for typical use; add the `WAKE_LOCK` permission if playback must survive
   * device sleep.
   * Defaults to `false`.
   */
  playInBackground?: boolean;

  /**
   * iOS only. Play even when the Ring / Silent switch is set to silent.
   * When playback starts, the library sets the shared `AVAudioSession`
   * category to `.playback` and activates it, unless the category is
   * already `.playback` or `.playAndRecord`. This interrupts audio from
   * other apps, such as a music app. When `false`, the library leaves the
   * session alone and your app's category applies; the iOS default category
   * is muted by the switch. No effect on Android, where the ringer mode
   * does not mute media playback.
   * Defaults to `false`.
   */
  ignoreSilentSwitch?: boolean;

  /**
   * While the app is in the background, skip the bar and time label
   * refreshes that run on every progress tick (about 30 per second). The UI
   * snaps to the current position when the app returns. `onTimeUpdate`
   * keeps firing either way.
   * Defaults to `true`.
   */
  pauseUiUpdatesInBackground?: boolean;

  /**
   * Controlled playing state. When set, the play button and the `play()`,
   * `pause()` and `toggle()` ref methods no longer change playback: a tap
   * fires `onPlayerStateChange` with the requested `isPlaying`, and you
   * update this prop.
   */
  playing?: boolean;
  /**
   * Controlled speed. When set, the speed pill and `setSpeed()` no longer
   * change the speed: a tap fires `onPlayerStateChange` with the requested
   * `speed`, and you update this prop.
   */
  speed?: number;

  /** Fired once the source is ready to play. */
  onLoad?: (event: AudioWaveformLoadEvent) => void;
  /**
   * Fired when the source cannot be loaded or played, and when the waveform
   * cannot be decoded (playback may still work in that case).
   */
  onLoadError?: (event: AudioWaveformLoadErrorEvent) => void;
  /**
   * Fired with a full snapshot on every state transition: loading, ready,
   * play, pause, speed change, end and error. The same values can arrive
   * more than once, so compare them with your own state.
   */
  onPlayerStateChange?: (event: AudioWaveformPlayerStateEvent) => void;
  /**
   * Fired about 30 times per second while playing, and once more at the end.
   * Not fired while the user is scrubbing.
   */
  onTimeUpdate?: (event: AudioWaveformTimeUpdateEvent) => void;
  /** Fired when a scrub gesture ends and after every `seekTo()` call. */
  onSeek?: (event: AudioWaveformSeekEvent) => void;
  /** Fired when playback reaches the end, unless `loop` is on. */
  onEnd?: () => void;
};

/** Methods available on a ref to {@link AudioWaveformView}. */
export type AudioWaveformViewRef = {
  /**
   * Start playback. Called while the source is loading, playback starts as
   * soon as it is ready. No effect when `playing` is controlled.
   */
  play: () => void;
  /** Pause playback. No effect when `playing` is controlled. */
  pause: () => void;
  /** Play if paused, pause if playing. No effect when `playing` is controlled. */
  toggle: () => void;
  /**
   * Seek to a position in milliseconds, clamped to the duration. Works in
   * controlled mode too and fires `onSeek`.
   */
  seekTo: (positionMs: number) => void;
  /**
   * Set the playback speed. The native players clamp it to 0.25 to 4. No
   * effect when `speed` is controlled.
   */
  setSpeed: (speed: number) => void;
};
