import {
  codegenNativeComponent,
  codegenNativeCommands,
  type CodegenTypes,
  type ColorValue,
  type HostComponent,
  type ViewProps,
} from 'react-native';

type Source = Readonly<{ uri: string }>;

type OnLoadEvent = Readonly<{ durationMs: CodegenTypes.Int32 }>;
type OnLoadErrorEvent = Readonly<{ message: string }>;
type OnPlayerStateChangeEvent = Readonly<{
  state: string;
  isPlaying: boolean;
  speed: CodegenTypes.Float;
  error: string;
}>;
type OnTimeUpdateEvent = Readonly<{
  currentTimeMs: CodegenTypes.Int32;
  durationMs: CodegenTypes.Int32;
}>;
type OnSeekEvent = Readonly<{ positionMs: CodegenTypes.Int32 }>;
type OnEndEvent = Readonly<{}>;

export interface NativeProps extends ViewProps {
  source: Source;
  samples?: ReadonlyArray<CodegenTypes.Float>;

  playedBarColor?: ColorValue;
  unplayedBarColor?: ColorValue;

  barWidth?: CodegenTypes.WithDefault<CodegenTypes.Float, 3.0>;
  barGap?: CodegenTypes.WithDefault<CodegenTypes.Float, 2.0>;
  // -1 sentinel = "auto" (barWidth / 2)
  barRadius?: CodegenTypes.WithDefault<CodegenTypes.Float, -1.0>;
  // 0 sentinel = "auto from width"
  barCount?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;

  containerBackgroundColor?: ColorValue;
  containerBorderRadius?: CodegenTypes.WithDefault<CodegenTypes.Float, 16.0>;
  showBackground?: CodegenTypes.WithDefault<boolean, true>;

  showPlayButton?: CodegenTypes.WithDefault<boolean, true>;
  playButtonColor?: ColorValue;

  showTime?: CodegenTypes.WithDefault<boolean, true>;
  timeColor?: ColorValue;
  timeMode?: CodegenTypes.WithDefault<'count-up' | 'count-down', 'count-up'>;

  showSpeedControl?: CodegenTypes.WithDefault<boolean, true>;
  speedColor?: ColorValue;
  speedBackgroundColor?: ColorValue;
  speeds?: ReadonlyArray<CodegenTypes.Float>;
  defaultSpeed?: CodegenTypes.WithDefault<CodegenTypes.Float, 1.0>;

  autoPlay?: CodegenTypes.WithDefault<boolean, false>;
  initialPositionMs?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  loop?: CodegenTypes.WithDefault<boolean, false>;
  playInBackground?: CodegenTypes.WithDefault<boolean, false>;
  pauseUiUpdatesInBackground?: CodegenTypes.WithDefault<boolean, true>;

  // -1 sentinel = "uncontrolled" — internal state drives playback.
  controlledPlaying?: CodegenTypes.WithDefault<CodegenTypes.Int32, -1>;
  // -1 sentinel = "uncontrolled" — internal state drives speed.
  controlledSpeed?: CodegenTypes.WithDefault<CodegenTypes.Float, -1.0>;

  onLoad?: CodegenTypes.DirectEventHandler<OnLoadEvent>;
  onLoadError?: CodegenTypes.DirectEventHandler<OnLoadErrorEvent>;
  onPlayerStateChange?: CodegenTypes.DirectEventHandler<OnPlayerStateChangeEvent>;
  onTimeUpdate?: CodegenTypes.DirectEventHandler<OnTimeUpdateEvent>;
  onSeek?: CodegenTypes.DirectEventHandler<OnSeekEvent>;
  onEnd?: CodegenTypes.DirectEventHandler<OnEndEvent>;
}

interface NativeCommands {
  play: (viewRef: React.ElementRef<HostComponent<NativeProps>>) => void;
  pause: (viewRef: React.ElementRef<HostComponent<NativeProps>>) => void;
  toggle: (viewRef: React.ElementRef<HostComponent<NativeProps>>) => void;
  seekTo: (
    viewRef: React.ElementRef<HostComponent<NativeProps>>,
    positionMs: CodegenTypes.Int32
  ) => void;
  setSpeed: (
    viewRef: React.ElementRef<HostComponent<NativeProps>>,
    speed: CodegenTypes.Float
  ) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['play', 'pause', 'toggle', 'seekTo', 'setSpeed'],
});

export default codegenNativeComponent<NativeProps>('AudioWaveformView');
