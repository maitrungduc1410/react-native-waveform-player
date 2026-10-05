import {
  forwardRef,
  useImperativeHandle,
  useMemo,
  useRef,
  type ForwardedRef,
} from 'react';
import { type NativeSyntheticEvent } from 'react-native';
import NativeAudioWaveformView, {
  Commands,
} from './AudioWaveformViewNativeComponent';
import type {
  AudioWaveformLoadErrorEvent,
  AudioWaveformLoadEvent,
  AudioWaveformPlayerState,
  AudioWaveformSeekEvent,
  AudioWaveformTimeUpdateEvent,
  AudioWaveformViewProps,
  AudioWaveformViewRef,
} from './types';

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
