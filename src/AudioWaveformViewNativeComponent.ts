import {
  codegenNativeComponent,
  codegenNativeCommands,
  type ColorValue,
  type HostComponent,
  type ViewProps,
} from 'react-native';

import type {
  DirectEventHandler,
  Float,
  Int32,
  WithDefault,
} from './codegenTypes';

type Source = Readonly<{ uri: string }>;

type OnLoadEvent = Readonly<{ durationMs: Int32 }>;
type OnLoadErrorEvent = Readonly<{ message: string }>;
type OnPlayerStateChangeEvent = Readonly<{
  state: string;
  isPlaying: boolean;
  speed: Float;
  error: string;
}>;
type OnTimeUpdateEvent = Readonly<{
  currentTimeMs: Int32;
  durationMs: Int32;
}>;
type OnSeekEvent = Readonly<{ positionMs: Int32 }>;
type OnEndEvent = Readonly<{}>;

export interface NativeProps extends ViewProps {
  source: Source;
  samples?: ReadonlyArray<Float>;

  playedBarColor?: ColorValue;
  unplayedBarColor?: ColorValue;

  barWidth?: WithDefault<Float, 3.0>;
  barGap?: WithDefault<Float, 2.0>;
  // -1 sentinel = "auto" (barWidth / 2)
  barRadius?: WithDefault<Float, -1.0>;
  // 0 sentinel = "auto from width"
  barCount?: WithDefault<Int32, 0>;

  containerBackgroundColor?: ColorValue;
  containerBorderRadius?: WithDefault<Float, 16.0>;
  showBackground?: WithDefault<boolean, true>;

  showPlayButton?: WithDefault<boolean, true>;
  playButtonColor?: ColorValue;

  showTime?: WithDefault<boolean, true>;
  timeColor?: ColorValue;
  timeMode?: WithDefault<'count-up' | 'count-down', 'count-up'>;

  showSpeedControl?: WithDefault<boolean, true>;
  speedColor?: ColorValue;
  speedBackgroundColor?: ColorValue;
  speeds?: ReadonlyArray<Float>;
  defaultSpeed?: WithDefault<Float, 1.0>;

  autoPlay?: WithDefault<boolean, false>;
  initialPositionMs?: WithDefault<Int32, 0>;
  loop?: WithDefault<boolean, false>;
  playInBackground?: WithDefault<boolean, false>;
  ignoreSilentSwitch?: WithDefault<boolean, false>;
  pauseUiUpdatesInBackground?: WithDefault<boolean, true>;

  // -1 sentinel = "uncontrolled" — internal state drives playback.
  controlledPlaying?: WithDefault<Int32, -1>;
  // -1 sentinel = "uncontrolled" — internal state drives speed.
  controlledSpeed?: WithDefault<Float, -1.0>;

  onLoad?: DirectEventHandler<OnLoadEvent>;
  onLoadError?: DirectEventHandler<OnLoadErrorEvent>;
  onPlayerStateChange?: DirectEventHandler<OnPlayerStateChangeEvent>;
  onTimeUpdate?: DirectEventHandler<OnTimeUpdateEvent>;
  onSeek?: DirectEventHandler<OnSeekEvent>;
  onEnd?: DirectEventHandler<OnEndEvent>;
}

interface NativeCommands {
  play: (viewRef: React.ElementRef<HostComponent<NativeProps>>) => void;
  pause: (viewRef: React.ElementRef<HostComponent<NativeProps>>) => void;
  toggle: (viewRef: React.ElementRef<HostComponent<NativeProps>>) => void;
  seekTo: (
    viewRef: React.ElementRef<HostComponent<NativeProps>>,
    positionMs: Int32
  ) => void;
  setSpeed: (
    viewRef: React.ElementRef<HostComponent<NativeProps>>,
    speed: Float
  ) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['play', 'pause', 'toggle', 'seekTo', 'setSpeed'],
});

export default codegenNativeComponent<NativeProps>('AudioWaveformView');
