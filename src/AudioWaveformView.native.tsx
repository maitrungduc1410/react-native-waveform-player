import {
  forwardRef,
  useImperativeHandle,
  useMemo,
  useRef,
  type ForwardedRef,
} from 'react';
import {
  type ColorValue,
  type NativeSyntheticEvent,
  type ViewProps,
} from 'react-native';
import NativeAudioWaveformView, {
  Commands,
} from './AudioWaveformViewNativeComponent';

export type AudioWaveformPlayerState =
  | 'idle'
  | 'loading'
  | 'ready'
  | 'ended'
  | 'error';

export type AudioWaveformTimeMode = 'count-up' | 'count-down';

export type AudioWaveformSource = { uri: string };

export type AudioWaveformPlayerStateEvent = {
  state: AudioWaveformPlayerState;
  isPlaying: boolean;
  speed: number;
  error?: string;
};

export type AudioWaveformTimeUpdateEvent = {
  currentTimeMs: number;
  durationMs: number;
};

export type AudioWaveformSeekEvent = {
  positionMs: number;
};

export type AudioWaveformLoadEvent = {
  durationMs: number;
};

export type AudioWaveformLoadErrorEvent = {
  message: string;
};

export type AudioWaveformViewProps = Omit<ViewProps, 'children'> & {
  source: AudioWaveformSource;

  /** Pre-computed amplitudes in [0, 1]. When provided, native decode is skipped. */
  samples?: ReadonlyArray<number>;

  /** Highlighted bar color (the "played" portion). */
  playedBarColor?: ColorValue;
  /** Bar color for the not-yet-played portion. */
  unplayedBarColor?: ColorValue;

  /** Bar thickness (default 3). */
  barWidth?: number;
  /** Gap between bars (default 2). */
  barGap?: number;
  /** Bar corner radius (default = barWidth / 2). */
  barRadius?: number;
  /** Force a specific number of bars; default auto from view width. */
  barCount?: number;

  /** Background of the rounded container (default light blue). Has no effect when showBackground={false}. */
  containerBackgroundColor?: ColorValue;
  /** Container corner radius (default 16). Has no effect when showBackground={false}. */
  containerBorderRadius?: number;
  /** Whether to draw the rounded container background. Default true. */
  showBackground?: boolean;

  /** Show the play/pause button. Default true. */
  showPlayButton?: boolean;
  playButtonColor?: ColorValue;

  /** Show the time label. Default true. */
  showTime?: boolean;
  timeColor?: ColorValue;
  /** count-up: 0:00 -> duration. count-down: duration -> 0:00. Default count-up. */
  timeMode?: AudioWaveformTimeMode;

  /** Show the playback-speed pill. Default true. */
  showSpeedControl?: boolean;
  speedColor?: ColorValue;
  speedBackgroundColor?: ColorValue;
  /** Available speeds the pill cycles through (default [0.5, 1, 1.5, 2]). */
  speeds?: ReadonlyArray<number>;
  /** Initial speed when the component mounts. Default 1. */
  defaultSpeed?: number;

  /** Begin playback as soon as the source is ready. Default false. */
  autoPlay?: boolean;
  /** Seek to this position immediately on load (milliseconds). Default 0. */
  initialPositionMs?: number;
  /** Restart from the beginning when playback ends. Default false. */
  loop?: boolean;

  /**
   * Allow audio to keep playing when the host app is backgrounded.
   * Default `false` — playback is paused on `didEnterBackground` (iOS) /
   * `onHostPause` (Android).
   *
   * When `true`:
   * - **iOS**: the host app must enable the "Audio, AirPlay, and Picture in
   *   Picture" Background Mode (Xcode → Signing & Capabilities → +Capability
   *   → Background Modes, or add `UIBackgroundModes: [audio]` to
   *   `Info.plist`). The library will configure `AVAudioSession` to
   *   `.playback` and activate it when the source is set.
   * - **Android**: no host configuration is required for typical use.
   *   `MediaPlayer` keeps playing through `Activity.onPause` already.
   *   Optionally add `<uses-permission android:name="android.permission.WAKE_LOCK"/>`
   *   to your app manifest if you need playback to survive device sleep —
   *   the library will then call `MediaPlayer.setWakeMode` automatically.
   */
  playInBackground?: boolean;

  /**
   * When the app is backgrounded, skip the cheap-but-pointless waveform /
   * time-label refreshes that would otherwise piggy-back on every 30 Hz
   * progress tick (the OS already skips the actual GPU painting).
   *
   * Default `true` — there is no visible effect since the view is
   * offscreen, and we save a small amount of CPU per tick. The
   * `onTimeUpdate` JS event keeps firing regardless so you can still
   * drive Now Playing / Lock Screen / analytics from background.
   *
   * Set to `false` if you want the bars + time label to stay refreshed in
   * background for some reason (rare).
   */
  pauseUiUpdatesInBackground?: boolean;

  /** When defined, the component is fully controlled — internal taps fire onPlayerStateChange but do not toggle play state. */
  playing?: boolean;
  /** When defined, the component is fully controlled — speed pill taps fire onPlayerStateChange but do not change speed. */
  speed?: number;

  onLoad?: (event: AudioWaveformLoadEvent) => void;
  onLoadError?: (event: AudioWaveformLoadErrorEvent) => void;
  onPlayerStateChange?: (event: AudioWaveformPlayerStateEvent) => void;
  onTimeUpdate?: (event: AudioWaveformTimeUpdateEvent) => void;
  onSeek?: (event: AudioWaveformSeekEvent) => void;
  onEnd?: () => void;
};

export type AudioWaveformViewRef = {
  play: () => void;
  pause: () => void;
  toggle: () => void;
  seekTo: (positionMs: number) => void;
  setSpeed: (speed: number) => void;
};

function AudioWaveformViewInner(
  props: AudioWaveformViewProps,
  ref: ForwardedRef<AudioWaveformViewRef>
) {
  const nativeRef = useRef<React.ComponentRef<
    typeof NativeAudioWaveformView
  > | null>(null);

  const {
    playing,
    speed,
    onLoad,
    onLoadError,
    onPlayerStateChange,
    onTimeUpdate,
    onSeek,
    onEnd,
    ...rest
  } = props;

  // Translate the React-style controlled props (boolean/number/undefined) into
  // the Fabric-friendly Int32/Float sentinels: -1 = uncontrolled.
  const controlledPlaying = useMemo(() => {
    if (playing === undefined) return -1;
    return playing ? 1 : 0;
  }, [playing]);

  const controlledSpeed = useMemo(() => {
    if (speed === undefined || !Number.isFinite(speed) || speed < 0) {
      return -1;
    }
    return speed;
  }, [speed]);

  useImperativeHandle(
    ref,
    () => ({
      play: () => {
        if (nativeRef.current) Commands.play(nativeRef.current);
      },
      pause: () => {
        if (nativeRef.current) Commands.pause(nativeRef.current);
      },
      toggle: () => {
        if (nativeRef.current) Commands.toggle(nativeRef.current);
      },
      seekTo: (positionMs: number) => {
        if (nativeRef.current) {
          Commands.seekTo(
            nativeRef.current,
            Math.max(0, Math.round(positionMs))
          );
        }
      },
      setSpeed: (s: number) => {
        if (nativeRef.current) Commands.setSpeed(nativeRef.current, s);
      },
    }),
    []
  );

  return (
    <NativeAudioWaveformView
      ref={nativeRef}
      {...rest}
      controlledPlaying={controlledPlaying}
      controlledSpeed={controlledSpeed}
      onLoad={
        onLoad
          ? (e: NativeSyntheticEvent<AudioWaveformLoadEvent>) =>
              onLoad(e.nativeEvent)
          : undefined
      }
      onLoadError={
        onLoadError
          ? (e: NativeSyntheticEvent<AudioWaveformLoadErrorEvent>) =>
              onLoadError(e.nativeEvent)
          : undefined
      }
      onPlayerStateChange={
        onPlayerStateChange
          ? (
              e: NativeSyntheticEvent<{
                state: string;
                isPlaying: boolean;
                speed: number;
                error: string;
              }>
            ) => {
              const { state, isPlaying, speed: spd, error } = e.nativeEvent;
              onPlayerStateChange({
                state: state as AudioWaveformPlayerState,
                isPlaying,
                speed: spd,
                error: error && error.length > 0 ? error : undefined,
              });
            }
          : undefined
      }
      onTimeUpdate={
        onTimeUpdate
          ? (e: NativeSyntheticEvent<AudioWaveformTimeUpdateEvent>) =>
              onTimeUpdate(e.nativeEvent)
          : undefined
      }
      onSeek={
        onSeek
          ? (e: NativeSyntheticEvent<AudioWaveformSeekEvent>) =>
              onSeek(e.nativeEvent)
          : undefined
      }
      onEnd={onEnd ? () => onEnd() : undefined}
    />
  );
}

export const AudioWaveformView = forwardRef<
  AudioWaveformViewRef,
  AudioWaveformViewProps
>(AudioWaveformViewInner);

AudioWaveformView.displayName = 'AudioWaveformView';
