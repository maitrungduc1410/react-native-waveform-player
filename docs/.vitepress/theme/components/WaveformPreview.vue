<script setup lang="ts">
/*
 * Browser approximation of <AudioWaveformView />. Layout numbers, bar
 * geometry, the two-pass played/unplayed fill, placeholder bars, speed
 * cycling, scrubbing and the state machine follow the iOS implementation
 * (ios/AudioWaveformViewImpl.swift, WaveformBarsView.swift,
 * AudioPlayerEngine.swift).
 */
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { amplitudesFor, getVoiceClip, type VoiceClip } from './voiceClip';

export type PlayerState = 'idle' | 'loading' | 'ready' | 'ended' | 'error';

const props = withDefaults(
  defineProps<{
    playedBarColor?: string;
    unplayedBarColor?: string;
    barWidth?: number;
    barGap?: number;
    /** Negative means auto (barWidth / 2), like the native sentinel. */
    barRadius?: number;
    /** 0 means auto from width, like the native sentinel. */
    barCount?: number;
    containerBackgroundColor?: string;
    containerBorderRadius?: number;
    showBackground?: boolean;
    showPlayButton?: boolean;
    playButtonColor?: string;
    showTime?: boolean;
    timeColor?: string;
    timeMode?: 'count-up' | 'count-down';
    showSpeedControl?: boolean;
    speedColor?: string;
    speedBackgroundColor?: string;
    speeds?: number[];
    defaultSpeed?: number;
    loop?: boolean;
    height?: number;
    labels?: { play: string; pause: string; loading: string; seek: string; speed: string };
  }>(),
  {
    playedBarColor: '#FFFFFF',
    unplayedBarColor: 'rgba(255, 255, 255, 0.5)',
    barWidth: 3,
    barGap: 2,
    barRadius: -1,
    barCount: 0,
    containerBackgroundColor: '#3478F6',
    containerBorderRadius: 16,
    showBackground: true,
    showPlayButton: true,
    playButtonColor: '#FFFFFF',
    showTime: true,
    timeColor: '#FFFFFF',
    timeMode: 'count-up',
    showSpeedControl: true,
    speedColor: '#FFFFFF',
    speedBackgroundColor: 'rgba(255, 255, 255, 0.25)',
    speeds: () => [0.5, 1, 1.5, 2],
    defaultSpeed: 1,
    loop: false,
    height: 56,
    labels: () => ({
      play: 'Play',
      pause: 'Pause',
      loading: 'Loading',
      seek: 'Playback position',
      speed: 'Playback speed',
    }),
  }
);

const emit = defineEmits<{
  load: [{ durationMs: number }];
  playerStateChange: [{ state: PlayerState; isPlaying: boolean; speed: number }];
  timeUpdate: [{ currentTimeMs: number; durationMs: number }];
  seek: [{ positionMs: number }];
  end: [];
}>();

const PLACEHOLDER = 0.2;
const INSET = 12;
const SPACING = 8;
const RIGHT_WIDTH = 56;
const LOAD_DELAY_MS = 700;

const state = ref<PlayerState>('idle');
const isPlaying = ref(false);
const currentMs = ref(0);
const durationMs = ref(0);
const internalSpeed = ref(1);
const progress = ref(0);
const scrubbing = ref(false);

let clip: VoiceClip | undefined;
let audio: HTMLAudioElement | undefined;
let pendingStart = false;
let resumeAfterScrub = false;
let defaultSpeedApplied = false;
let loadTimer: number | undefined;
let rafId: number | undefined;
let lastTimeEvent = 0;
let animId: number | undefined;

const canvas = ref<HTMLCanvasElement>();
const barsBox = ref<HTMLElement>();
const barsWidth = ref(0);
let resizeObserver: ResizeObserver | undefined;

let displayed: number[] = [];
let target: number[] = [];

const buttonSize = computed(() => Math.min(props.height * 0.6, 36));
const hasRight = computed(() => props.showTime || props.showSpeedControl);

const step = computed(() => props.barWidth + props.barGap);
const renderBarCount = computed(() => {
  if (step.value <= 0 || barsWidth.value <= 0) return 0;
  const auto = Math.floor(barsWidth.value / step.value);
  return props.barCount > 0 ? Math.min(props.barCount, auto) : auto;
});

function formatTime(ms: number) {
  const total = Math.floor(Math.max(0, ms) / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

const timeText = computed(() =>
  formatTime(
    props.timeMode === 'count-down'
      ? Math.max(0, durationMs.value - currentMs.value)
      : currentMs.value
  )
);

/** Matches SpeedPillView.setSpeed on iOS: one decimal, trailing ".0" dropped. */
function speedLabel(speed: number) {
  const rounded = Math.round(speed * 10) / 10;
  return Number.isInteger(rounded) ? `${rounded}x` : `${rounded.toFixed(1)}x`;
}

const speedText = computed(() => speedLabel(internalSpeed.value));

function emitState() {
  emit('playerStateChange', {
    state: state.value,
    isPlaying: isPlaying.value,
    speed: internalSpeed.value,
  });
}

function setState(next: PlayerState) {
  if (state.value === next) return;
  state.value = next;
  if (next === 'ready' && pendingStart) {
    pendingStart = false;
    startPlayback();
  }
  emitState();
}

function startPlayback() {
  if (!audio) return;
  audio.playbackRate = clampRate(internalSpeed.value);
  void audio.play().catch(() => {
    isPlaying.value = false;
    emitState();
  });
  isPlaying.value = true;
  startTick();
}

function clampRate(rate: number) {
  return Math.max(0.25, Math.min(4, rate));
}

function play() {
  if (state.value === 'loading') {
    pendingStart = true;
    return;
  }
  if (state.value !== 'ready' && state.value !== 'ended') return;
  if (isPlaying.value && state.value === 'ready') return;
  pendingStart = false;
  if (state.value === 'ended' && audio) {
    audio.currentTime = 0;
    currentMs.value = 0;
    state.value = 'ready';
  }
  startPlayback();
  emitState();
}

function pause() {
  pendingStart = false;
  if (!isPlaying.value) return;
  isPlaying.value = false;
  audio?.pause();
  stopTick();
  emitState();
}

function toggle() {
  if (isPlaying.value) pause();
  else play();
}

function seekTo(ms: number) {
  const clamped = Math.max(0, Math.min(durationMs.value, Math.round(ms)));
  currentMs.value = clamped;
  if (audio) audio.currentTime = clamped / 1000;
  if (durationMs.value > 0) progress.value = clamped / durationMs.value;
  emit('seek', { positionMs: clamped });
}

function setSpeed(speed: number) {
  internalSpeed.value = speed;
  defaultSpeedApplied = true;
  if (audio && isPlaying.value) audio.playbackRate = clampRate(speed);
  emitState();
}

function nextSpeed(current: number) {
  const list = props.speeds.length > 0 ? props.speeds : [0.5, 1, 1.5, 2];
  return list.find((s) => s > current + 0.001) ?? list[0] ?? 1;
}

function onSpeedTap() {
  setSpeed(nextSpeed(internalSpeed.value));
}

function startTick() {
  if (rafId !== undefined) return;
  const tick = (now: number) => {
    rafId = requestAnimationFrame(tick);
    if (!audio || scrubbing.value) return;
    currentMs.value = Math.min(durationMs.value, Math.floor(audio.currentTime * 1000));
    progress.value = durationMs.value > 0 ? currentMs.value / durationMs.value : 0;
    if (now - lastTimeEvent >= 33) {
      lastTimeEvent = now;
      emit('timeUpdate', { currentTimeMs: currentMs.value, durationMs: durationMs.value });
    }
  };
  rafId = requestAnimationFrame(tick);
}

function stopTick() {
  if (rafId !== undefined) cancelAnimationFrame(rafId);
  rafId = undefined;
}

function handleEnded() {
  isPlaying.value = false;
  stopTick();
  currentMs.value = durationMs.value;
  progress.value = 1;
  setState('ended');
  emit('timeUpdate', { currentTimeMs: currentMs.value, durationMs: durationMs.value });
  emit('end');
  emitState();
}

/** Simulates a fresh source: loading spinner and placeholder bars, then ready. */
function load() {
  teardownAudio();
  clip ??= getVoiceClip();
  audio = new Audio(clip.url);
  audio.preload = 'auto';
  audio.loop = props.loop;
  audio.addEventListener('ended', handleEnded);
  pendingStart = false;
  isPlaying.value = false;
  currentMs.value = 0;
  durationMs.value = 0;
  progress.value = 0;
  if (!defaultSpeedApplied) internalSpeed.value = props.defaultSpeed;
  target = [];
  displayed = [];
  draw();
  setState('loading');
  loadTimer = window.setTimeout(() => {
    durationMs.value = clip!.durationMs;
    setState('ready');
    emit('load', { durationMs: durationMs.value });
    emitState();
    setTargetAmplitudes();
  }, LOAD_DELAY_MS);
}

function teardownAudio() {
  window.clearTimeout(loadTimer);
  stopTick();
  if (audio) {
    audio.pause();
    audio.removeEventListener('ended', handleEnded);
    audio.removeAttribute('src');
    audio.load();
  }
  audio = undefined;
}

function reload() {
  defaultSpeedApplied = false;
  load();
}

defineExpose({ play, pause, toggle, seekTo, setSpeed, reload });

// Bars: amplitude animation from the current values to the decoded ones
// over 200 ms with an ease-out cubic, like WaveformBarsView.

function setTargetAmplitudes() {
  if (!clip || state.value === 'loading' || state.value === 'idle') return;
  const count = renderBarCount.value;
  if (count <= 0) return;
  const next = amplitudesFor(clip, count).map((v) => (v > 0 ? v : PLACEHOLDER));
  if (displayed.length !== next.length) displayed = next.map(() => PLACEHOLDER);
  const start = displayed.slice();
  target = next;
  const t0 = performance.now();
  if (animId !== undefined) cancelAnimationFrame(animId);
  const frame = (now: number) => {
    const t = Math.min(1, (now - t0) / 200);
    const eased = 1 - Math.pow(1 - t, 3);
    displayed = start.map((s, i) => s + ((target[i] ?? s) - s) * eased);
    draw();
    animId = t < 1 ? requestAnimationFrame(frame) : undefined;
  };
  animId = requestAnimationFrame(frame);
}

function roundedRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
) {
  const radius = Math.max(0, Math.min(r, w / 2, h / 2));
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

function draw() {
  const el = canvas.value;
  if (!el) return;
  const width = barsWidth.value;
  const height = props.height;
  const dpr = window.devicePixelRatio || 1;
  if (el.width !== Math.round(width * dpr) || el.height !== Math.round(height * dpr)) {
    el.width = Math.round(width * dpr);
    el.height = Math.round(height * dpr);
  }
  const ctx = el.getContext('2d');
  if (!ctx) return;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, width, height);
  const count = renderBarCount.value;
  const verticalPadding = props.barWidth * 1.5;
  const drawable = height - verticalPadding * 2;
  if (count <= 0 || drawable <= 0) return;
  const radius = props.barRadius < 0 ? props.barWidth / 2 : props.barRadius;
  const usePlaceholder = displayed.length === 0;
  const path = () => {
    ctx.beginPath();
    for (let i = 0; i < count; i++) {
      const amp = usePlaceholder
        ? PLACEHOLDER
        : displayed[Math.min(Math.floor((i * displayed.length) / count), displayed.length - 1)]!;
      const barHeight = Math.max(props.barWidth, amp * drawable);
      const x = i * step.value;
      const y = verticalPadding + (drawable - barHeight) / 2;
      roundedRect(ctx, x, y, props.barWidth, barHeight, radius);
    }
  };
  path();
  ctx.fillStyle = props.unplayedBarColor;
  ctx.fill();
  const progressX = Math.max(0, Math.min(1, progress.value)) * width;
  if (progressX <= 0) return;
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, progressX, height);
  ctx.clip();
  path();
  ctx.fillStyle = props.playedBarColor;
  ctx.fill();
  ctx.restore();
}

// Scrubbing: press anywhere on the bars, drag, release. Playback pauses
// during the drag and resumes on release if it was playing.

function fractionAt(event: PointerEvent) {
  const rect = barsBox.value!.getBoundingClientRect();
  return rect.width > 0 ? Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width)) : 0;
}

function positionFromFraction(f: number) {
  return durationMs.value > 0 ? Math.floor(f * durationMs.value) : 0;
}

function scrubTo(f: number) {
  progress.value = f;
  const ms = positionFromFraction(f);
  currentMs.value = Math.min(ms, durationMs.value);
  if (audio && durationMs.value > 0) audio.currentTime = ms / 1000;
}

function onPointerDown(event: PointerEvent) {
  if (event.button !== 0) return;
  barsBox.value!.setPointerCapture(event.pointerId);
  scrubbing.value = true;
  resumeAfterScrub = isPlaying.value;
  if (isPlaying.value) pause();
  scrubTo(fractionAt(event));
}

function onPointerMove(event: PointerEvent) {
  if (scrubbing.value) scrubTo(fractionAt(event));
}

function onPointerUp(event: PointerEvent, cancelled = false) {
  if (!scrubbing.value) return;
  scrubbing.value = false;
  const f = cancelled ? progress.value : fractionAt(event);
  scrubTo(f);
  emit('seek', { positionMs: positionFromFraction(f) });
  if (!cancelled && resumeAfterScrub) play();
}

function onKeydown(event: KeyboardEvent) {
  if (durationMs.value <= 0) return;
  const stepMs = durationMs.value / 20;
  const keys: Record<string, number> = {
    ArrowRight: currentMs.value + stepMs,
    ArrowUp: currentMs.value + stepMs,
    ArrowLeft: currentMs.value - stepMs,
    ArrowDown: currentMs.value - stepMs,
    Home: 0,
    End: durationMs.value,
  };
  const next = keys[event.key];
  if (next === undefined) return;
  event.preventDefault();
  seekTo(next);
}

watch(
  () => [
    props.barWidth,
    props.barGap,
    props.barRadius,
    props.barCount,
    props.height,
    props.playedBarColor,
    props.unplayedBarColor,
    barsWidth.value,
  ],
  () => draw(),
  { flush: 'post' }
);
watch(progress, () => draw());
watch(renderBarCount, () => setTargetAmplitudes(), { flush: 'post' });
watch(
  () => props.loop,
  (loop) => {
    if (audio) audio.loop = loop;
  }
);
watch(
  () => props.defaultSpeed,
  (speed) => {
    if (!defaultSpeedApplied) {
      internalSpeed.value = speed;
      if (audio && isPlaying.value) audio.playbackRate = clampRate(speed);
    }
  }
);

onMounted(() => {
  resizeObserver = new ResizeObserver(([entry]) => {
    if (entry) barsWidth.value = Math.floor(entry.contentRect.width);
  });
  if (barsBox.value) resizeObserver.observe(barsBox.value);
  load();
});

onBeforeUnmount(() => {
  resizeObserver?.disconnect();
  if (animId !== undefined) cancelAnimationFrame(animId);
  teardownAudio();
});
</script>

<template>
  <div
    class="awv"
    :style="{
      height: `${height}px`,
      borderRadius: showBackground ? `${containerBorderRadius}px` : undefined,
      background: showBackground ? containerBackgroundColor : 'transparent',
      paddingInline: `${INSET}px`,
    }"
  >
    <button
      v-if="showPlayButton"
      type="button"
      class="awv-button"
      :style="{ width: `${buttonSize}px`, height: `${buttonSize}px`, color: playButtonColor, marginInlineEnd: `${SPACING}px` }"
      :aria-label="state === 'loading' ? labels.loading : isPlaying ? labels.pause : labels.play"
      @click="toggle"
    >
      <span v-if="state === 'loading'" class="awv-spinner" aria-hidden="true" />
      <svg v-else-if="isPlaying" viewBox="0 0 24 24" aria-hidden="true">
        <rect x="5.5" y="4" width="4.6" height="16" rx="1.4" fill="currentColor" />
        <rect x="13.9" y="4" width="4.6" height="16" rx="1.4" fill="currentColor" />
      </svg>
      <svg v-else viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M7 4.9v14.2c0 1 1.1 1.6 1.9 1.1l11.4-7.1c.8-.5.8-1.7 0-2.2L8.9 3.8C8.1 3.3 7 3.9 7 4.9z"
          fill="currentColor"
        />
      </svg>
    </button>
    <div
      ref="barsBox"
      class="awv-bars"
      role="slider"
      tabindex="0"
      :aria-label="labels.seek"
      :aria-valuemin="0"
      :aria-valuemax="Math.round(durationMs / 1000)"
      :aria-valuenow="Math.round(currentMs / 1000)"
      :aria-valuetext="`${formatTime(currentMs)} / ${formatTime(durationMs)}`"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp($event)"
      @pointercancel="onPointerUp($event, true)"
      @keydown="onKeydown"
    >
      <canvas ref="canvas" :style="{ width: `${barsWidth}px`, height: `${height}px` }" />
    </div>
    <div
      v-if="hasRight"
      class="awv-right"
      :style="{ width: `${RIGHT_WIDTH}px`, marginInlineStart: `${SPACING}px` }"
    >
      <span v-if="showTime" class="awv-time" :style="{ color: timeColor }">{{ timeText }}</span>
      <button
        v-if="showSpeedControl"
        type="button"
        class="awv-pill"
        :style="{ color: speedColor, background: speedBackgroundColor, marginTop: showTime ? '4px' : undefined }"
        :aria-label="`${labels.speed}: ${speedText}`"
        @click="onSpeedTap"
      >
        {{ speedText }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.awv {
  display: flex;
  align-items: center;
  box-sizing: border-box;
  width: 100%;
  overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, 'Segoe UI', Roboto,
    sans-serif;
  user-select: none;
  -webkit-user-select: none;
}

.awv-button {
  display: grid;
  place-items: center;
  flex: none;
  padding: 4px;
  border: 0;
  background: transparent;
  cursor: pointer;
}

.awv-button svg {
  width: 100%;
  height: 100%;
}

.awv-button:active,
.awv-pill:active {
  opacity: 0.6;
}

.awv-spinner {
  width: 60%;
  height: 60%;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: awv-spin 0.8s linear infinite;
}

@keyframes awv-spin {
  to {
    transform: rotate(360deg);
  }
}

.awv-bars {
  flex: 1 1 auto;
  min-width: 0;
  height: 100%;
  cursor: pointer;
  touch-action: none;
}

.awv-bars canvas {
  display: block;
}

.awv-right {
  display: flex;
  flex: none;
  flex-direction: column;
  align-items: flex-end;
  justify-content: center;
}

.awv-time {
  height: 18px;
  font-size: 13px;
  font-weight: 600;
  line-height: 18px;
  font-variant-numeric: tabular-nums;
}

.awv-pill {
  width: 44px;
  height: 22px;
  padding: 0 6px;
  border: 0;
  border-radius: 11px;
  font: inherit;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}

.awv-button:focus-visible,
.awv-pill:focus-visible,
.awv-bars:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: 2px;
}

@media (prefers-reduced-motion: reduce) {
  .awv-spinner {
    animation-duration: 2.4s;
  }
}
</style>
