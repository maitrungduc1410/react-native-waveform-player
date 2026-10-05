import { forwardRef, type ForwardedRef } from 'react';
import type { AudioWaveformViewProps, AudioWaveformViewRef } from './types';

function AudioWaveformViewInner(
  _props: AudioWaveformViewProps,
  _ref: ForwardedRef<AudioWaveformViewRef>
): never {
  throw new Error(
    "'react-native-waveform-player' is only supported on native platforms."
  );
}

/**
 * Native voice-note player: a play / pause button, an animated waveform you
 * can scrub, a time label and a speed pill, rendered by a Fabric component
 * on iOS and Android.
 *
 * @example
 * ```tsx
 * <AudioWaveformView
 *   source={{ uri: 'https://example.com/voice-note.m4a' }}
 *   style={{ height: 56 }}
 * />
 * ```
 */
export const AudioWaveformView = forwardRef<
  AudioWaveformViewRef,
  AudioWaveformViewProps
>(AudioWaveformViewInner);
