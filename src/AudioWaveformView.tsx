import { forwardRef, type ForwardedRef } from 'react';
import type { ViewProps, ColorValue } from 'react-native';

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
  samples?: ReadonlyArray<number>;
  playedBarColor?: ColorValue;
  unplayedBarColor?: ColorValue;
  barWidth?: number;
  barGap?: number;
  barRadius?: number;
  barCount?: number;
  containerBackgroundColor?: ColorValue;
  containerBorderRadius?: number;
  showBackground?: boolean;
  showPlayButton?: boolean;
  playButtonColor?: ColorValue;
  showTime?: boolean;
  timeColor?: ColorValue;
  timeMode?: AudioWaveformTimeMode;
  showSpeedControl?: boolean;
  speedColor?: ColorValue;
  speedBackgroundColor?: ColorValue;
  speeds?: ReadonlyArray<number>;
  defaultSpeed?: number;
  autoPlay?: boolean;
  initialPositionMs?: number;
  loop?: boolean;
  playInBackground?: boolean;
  pauseUiUpdatesInBackground?: boolean;
  playing?: boolean;
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
  _props: AudioWaveformViewProps,
  _ref: ForwardedRef<AudioWaveformViewRef>
): never {
  throw new Error(
    "'react-native-waveform-player' is only supported on native platforms."
  );
}

export const AudioWaveformView = forwardRef<
  AudioWaveformViewRef,
  AudioWaveformViewProps
>(AudioWaveformViewInner);
