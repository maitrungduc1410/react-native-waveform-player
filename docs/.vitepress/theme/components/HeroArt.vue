<script setup lang="ts">
import { useData } from 'vitepress';
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

const LABELS: Record<string, string> = {
  en: 'Voice notes in a chat: a fuchsia bubble with a play button, a waveform that fills as it plays, a time label and a 1.5x speed pill',
  vi: 'Tin nhắn thoại trong khung chat: bong bóng màu hồng tím có nút phát, dạng sóng tô màu dần khi phát, nhãn thời gian và nút tốc độ 1.5x',
  zh: '聊天中的语音消息：紫红色气泡里有播放按钮、随播放逐渐填充的波形、时间标签和 1.5x 倍速按钮',
};
const { lang } = useData();
const label = computed(() => LABELS[lang.value.slice(0, 2)] ?? LABELS.en);

const BARS = [
  0.18, 0.3, 0.55, 0.8, 0.62, 0.35, 0.22, 0.48, 0.9, 1, 0.72, 0.4, 0.2, 0.16, 0.34, 0.66, 0.84,
  0.58, 0.3, 0.18, 0.42, 0.7, 0.52, 0.26, 0.14, 0.24, 0.5, 0.76, 0.6, 0.32, 0.2, 0.12,
];
const SMALL = [0.3, 0.6, 0.9, 0.5, 0.25, 0.7, 1, 0.65, 0.35, 0.2, 0.45, 0.8, 0.55, 0.3, 0.6, 0.4, 0.2, 0.35];

function bars(amps: number[], x0: number, cy: number, h: number, w: number, gap: number) {
  return amps.map((a, i) => {
    const bh = Math.max(w, a * h);
    return { x: x0 + i * (w + gap), y: cy - bh / 2, w, h: bh };
  });
}

const main = bars(BARS, 92, 168, 52, 5, 3.5);
const mainStart = 92;
const mainWidth = BARS.length * 8.5 - 3.5;
const incoming = bars(SMALL, 76, 70, 28, 4, 3);

const progress = ref(0.42);
let raf: number | undefined;

onMounted(() => {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const start = performance.now();
  const loop = (now: number) => {
    progress.value = ((now - start) / 7000) % 1;
    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);
});

onBeforeUnmount(() => {
  if (raf !== undefined) cancelAnimationFrame(raf);
});
</script>

<template>
  <svg
    class="hero-art"
    viewBox="0 0 400 300"
    role="img"
    :aria-label="label"
  >
    <defs>
      <linearGradient id="ha-bubble" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#d946ef" />
        <stop offset="1" stop-color="#db2777" />
      </linearGradient>
      <clipPath id="ha-played">
        <rect :x="mainStart" y="120" :width="mainWidth * progress" height="100" />
      </clipPath>
    </defs>

    <!-- incoming message -->
    <g class="ha-in">
      <rect x="24" y="38" width="236" height="64" rx="22" class="ha-in-bg" />
      <path d="M44 52v36l26-18z" class="ha-in-fg" transform="translate(-4 0) scale(0.92)" />
      <rect
        v-for="(b, i) in incoming"
        :key="`in${i}`"
        :x="b.x"
        :y="b.y"
        :width="b.w"
        :height="b.h"
        :rx="b.w / 2"
        class="ha-in-fg"
      />
      <text x="244" y="76" text-anchor="end" class="ha-in-time">0:09</text>
    </g>

    <!-- outgoing message, playing -->
    <g>
      <rect x="40" y="128" width="340" height="80" rx="26" fill="url(#ha-bubble)" />
      <g fill="#fff">
        <rect x="58" y="153" width="9" height="30" rx="3" />
        <rect x="73" y="153" width="9" height="30" rx="3" />
      </g>
      <g fill="#fff" fill-opacity="0.45">
        <rect v-for="(b, i) in main" :key="`u${i}`" :x="b.x" :y="b.y" :width="b.w" :height="b.h" :rx="b.w / 2" />
      </g>
      <g fill="#fff" clip-path="url(#ha-played)">
        <rect v-for="(b, i) in main" :key="`p${i}`" :x="b.x" :y="b.y" :width="b.w" :height="b.h" :rx="b.w / 2" />
      </g>
      <text x="362" y="160" text-anchor="end" class="ha-time">0:{{ String(Math.floor(progress * 37)).padStart(2, '0') }}</text>
      <rect x="320" y="170" width="44" height="22" rx="11" fill="#fff" fill-opacity="0.25" />
      <text x="342" y="185.5" text-anchor="middle" class="ha-pill">1.5x</text>
    </g>

    <!-- read receipt dots -->
    <g class="ha-dots">
      <circle cx="350" cy="232" r="3" />
      <circle cx="362" cy="232" r="3" />
    </g>
  </svg>
</template>

<style scoped>
.hero-art {
  width: 100%;
  max-width: 420px;
  height: auto;
  font-family: -apple-system, BlinkMacSystemFont, system-ui, 'Segoe UI', Roboto, sans-serif;
}

.ha-in-bg {
  fill: var(--vp-c-bg-soft);
  stroke: var(--vp-c-divider);
}

.ha-in-fg {
  fill: var(--vp-c-brand-1);
}

.ha-in-time {
  font-size: 12px;
  font-weight: 600;
  fill: var(--vp-c-text-2);
}

.ha-time {
  font-size: 13px;
  font-weight: 600;
  fill: #fff;
  font-variant-numeric: tabular-nums;
}

.ha-pill {
  font-size: 12px;
  font-weight: 600;
  fill: #fff;
}

.ha-dots circle {
  fill: var(--vp-c-brand-1);
  opacity: 0.6;
}
</style>
