<script setup lang="ts">
import { useData } from 'vitepress';
import { computed, reactive, ref } from 'vue';
import WaveformPreview from './WaveformPreview.vue';

const props = withDefaults(
  defineProps<{
    /** Show the prop controls and the generated JSX. */
    controls?: boolean;
    /** Show the ref method buttons and the event log. */
    events?: boolean;
  }>(),
  { controls: true, events: true }
);

const strings = {
  en: {
    note: 'Web approximation of the native component, playing a short clip generated in your browser. Layout and behavior follow the iOS implementation; real rendering is native.',
    presets: 'Presets',
    presetDefault: 'Default',
    presetMidnight: 'Midnight',
    presetFuchsia: 'Fuchsia',
    presetLight: 'Light bubble',
    colors: 'Colors',
    bars: 'Bars',
    layout: 'Container and controls',
    opacity: 'opacity',
    auto: 'auto',
    reload: 'Reload source',
    copy: 'Copy',
    copied: 'Copied',
    events: 'Events',
    clear: 'Clear',
    empty: 'Play, scrub or tap the speed pill to see events.',
    refMethods: 'Ref methods',
    speedsHint: 'comma separated',
    labels: { play: 'Play', pause: 'Pause', loading: 'Loading', seek: 'Playback position', speed: 'Playback speed' },
  },
  vi: {
    note: 'Bản mô phỏng trên web của component native, phát một đoạn âm thanh ngắn được tạo ngay trong trình duyệt. Bố cục và hành vi bám theo bản iOS; trên thiết bị, giao diện được vẽ bằng native.',
    presets: 'Mẫu có sẵn',
    presetDefault: 'Mặc định',
    presetMidnight: 'Nền tối',
    presetFuchsia: 'Hồng tím',
    presetLight: 'Bong bóng sáng',
    colors: 'Màu sắc',
    bars: 'Thanh sóng',
    layout: 'Khung và nút điều khiển',
    opacity: 'độ mờ',
    auto: 'tự động',
    reload: 'Tải lại nguồn',
    copy: 'Sao chép',
    copied: 'Đã chép',
    events: 'Sự kiện',
    clear: 'Xóa',
    empty: 'Hãy phát, tua hoặc chạm vào nút tốc độ để xem sự kiện.',
    refMethods: 'Phương thức ref',
    speedsHint: 'cách nhau bằng dấu phẩy',
    labels: { play: 'Phát', pause: 'Tạm dừng', loading: 'Đang tải', seek: 'Vị trí phát', speed: 'Tốc độ phát' },
  },
  zh: {
    note: '原生组件的网页近似效果，播放一段在浏览器中生成的短音频。布局和行为参照 iOS 实现；在设备上由原生代码绘制。',
    presets: '预设',
    presetDefault: '默认',
    presetMidnight: '深色',
    presetFuchsia: '紫红',
    presetLight: '浅色气泡',
    colors: '颜色',
    bars: '波形条',
    layout: '容器与控件',
    opacity: '不透明度',
    auto: '自动',
    reload: '重新加载音频',
    copy: '复制',
    copied: '已复制',
    events: '事件',
    clear: '清空',
    empty: '播放、拖动进度或点击倍速按钮，即可在这里看到事件。',
    refMethods: 'Ref 方法',
    speedsHint: '用逗号分隔',
    labels: { play: '播放', pause: '暂停', loading: '加载中', seek: '播放进度', speed: '播放速度' },
  },
};

const { lang } = useData();
const t = computed(() => {
  const key = lang.value.slice(0, 2) as keyof typeof strings;
  return strings[key] ?? strings.en;
});

type ColorKey =
  | 'playedBarColor'
  | 'unplayedBarColor'
  | 'containerBackgroundColor'
  | 'playButtonColor'
  | 'timeColor'
  | 'speedColor'
  | 'speedBackgroundColor';

type Color = { hex: string; alpha: number };

type Settings = {
  colors: Record<ColorKey, Color>;
  barWidth: number;
  barGap: number;
  barRadius: number;
  autoRadius: boolean;
  barCount: number;
  autoCount: boolean;
  containerBorderRadius: number;
  showBackground: boolean;
  showPlayButton: boolean;
  showTime: boolean;
  timeMode: 'count-up' | 'count-down';
  showSpeedControl: boolean;
  speeds: string;
  defaultSpeed: number;
  loop: boolean;
  height: number;
};

const c = (hex: string, alpha = 1): Color => ({ hex, alpha });

const DEFAULTS: Settings = {
  colors: {
    playedBarColor: c('#ffffff'),
    unplayedBarColor: c('#ffffff', 0.5),
    containerBackgroundColor: c('#3478f6'),
    playButtonColor: c('#ffffff'),
    timeColor: c('#ffffff'),
    speedColor: c('#ffffff'),
    speedBackgroundColor: c('#ffffff', 0.25),
  },
  barWidth: 3,
  barGap: 2,
  barRadius: 1.5,
  autoRadius: true,
  barCount: 40,
  autoCount: true,
  containerBorderRadius: 16,
  showBackground: true,
  showPlayButton: true,
  showTime: true,
  timeMode: 'count-up',
  showSpeedControl: true,
  speeds: '0.5, 1, 1.5, 2',
  defaultSpeed: 1,
  loop: false,
  height: 56,
};

const PRESETS: Record<'default' | 'midnight' | 'fuchsia' | 'light', Partial<Settings>> = {
  default: {},
  midnight: {
    colors: {
      ...DEFAULTS.colors,
      containerBackgroundColor: c('#0f172a'),
      playedBarColor: c('#22d3ee'),
      unplayedBarColor: c('#22d3ee', 0.35),
      playButtonColor: c('#22d3ee'),
      timeColor: c('#a5f3fc'),
      speedColor: c('#0f172a'),
      speedBackgroundColor: c('#22d3ee'),
    },
    containerBorderRadius: 20,
    timeMode: 'count-down',
    speeds: '1, 1.5, 2',
    defaultSpeed: 1.5,
    barWidth: 4,
    barGap: 3,
  },
  fuchsia: {
    colors: {
      ...DEFAULTS.colors,
      containerBackgroundColor: c('#a21caf'),
      unplayedBarColor: c('#f5d0fe', 0.45),
      speedBackgroundColor: c('#ffffff', 0.2),
    },
    barWidth: 2,
    barGap: 2,
    containerBorderRadius: 28,
  },
  light: {
    colors: {
      ...DEFAULTS.colors,
      containerBackgroundColor: c('#eef2f7'),
      playedBarColor: c('#1f2937'),
      unplayedBarColor: c('#1f2937', 0.3),
      playButtonColor: c('#1f2937'),
      timeColor: c('#4b5563'),
      speedColor: c('#1f2937'),
      speedBackgroundColor: c('#1f2937', 0.1),
    },
  },
};

const presetLabels = computed(() => ({
  default: t.value.presetDefault,
  midnight: t.value.presetMidnight,
  fuchsia: t.value.presetFuchsia,
  light: t.value.presetLight,
}));

function clone(s: Settings): Settings {
  return { ...s, colors: Object.fromEntries(Object.entries(s.colors).map(([k, v]) => [k, { ...v }])) as Settings['colors'] };
}

const s = reactive<Settings>(clone(DEFAULTS));
const activePreset = ref<keyof typeof PRESETS>('default');

function applyPreset(name: keyof typeof PRESETS) {
  activePreset.value = name;
  Object.assign(s, clone({ ...DEFAULTS, ...PRESETS[name] } as Settings));
}

function css({ hex, alpha }: Color) {
  if (alpha >= 1) return hex.toUpperCase();
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${Number(alpha.toFixed(2))})`;
}

const speedsList = computed(() => {
  const list = s.speeds
    .split(',')
    .map((v) => Number(v.trim()))
    .filter((v) => Number.isFinite(v) && v > 0);
  return list.length > 0 ? list : [0.5, 1, 1.5, 2];
});

const previewProps = computed(() => ({
  ...Object.fromEntries(
    (Object.keys(s.colors) as ColorKey[]).map((k) => [k, css(s.colors[k])])
  ),
  barWidth: s.barWidth,
  barGap: s.barGap,
  barRadius: s.autoRadius ? -1 : s.barRadius,
  barCount: s.autoCount ? 0 : s.barCount,
  containerBorderRadius: s.containerBorderRadius,
  showBackground: s.showBackground,
  showPlayButton: s.showPlayButton,
  showTime: s.showTime,
  timeMode: s.timeMode,
  showSpeedControl: s.showSpeedControl,
  speeds: speedsList.value,
  defaultSpeed: s.defaultSpeed,
  loop: s.loop,
  height: s.height,
}));

const code = computed(() => {
  const lines: string[] = ["  source={{ uri: 'https://example.com/voice-note.m4a' }}"];
  for (const k of Object.keys(s.colors) as ColorKey[]) {
    const v = css(s.colors[k]);
    if (v !== css(DEFAULTS.colors[k])) lines.push(`  ${k}="${v}"`);
  }
  const num = (k: string, v: number, d: number) => {
    if (v !== d) lines.push(`  ${k}={${v}}`);
  };
  const bool = (k: string, v: boolean, d: boolean) => {
    if (v !== d) lines.push(v ? `  ${k}` : `  ${k}={false}`);
  };
  num('barWidth', s.barWidth, DEFAULTS.barWidth);
  num('barGap', s.barGap, DEFAULTS.barGap);
  if (!s.autoRadius) lines.push(`  barRadius={${s.barRadius}}`);
  if (!s.autoCount) lines.push(`  barCount={${s.barCount}}`);
  bool('showBackground', s.showBackground, true);
  num('containerBorderRadius', s.containerBorderRadius, DEFAULTS.containerBorderRadius);
  bool('showPlayButton', s.showPlayButton, true);
  bool('showTime', s.showTime, true);
  if (s.timeMode !== 'count-up') lines.push(`  timeMode="${s.timeMode}"`);
  bool('showSpeedControl', s.showSpeedControl, true);
  const speeds = speedsList.value.join(', ');
  if (speeds !== '0.5, 1, 1.5, 2') lines.push(`  speeds={[${speeds}]}`);
  num('defaultSpeed', s.defaultSpeed, 1);
  bool('loop', s.loop, false);
  lines.push(`  style={{ height: ${s.height} }}`);
  return `<AudioWaveformView\n${lines.join('\n')}\n/>`;
});

const copied = ref(false);
async function copy() {
  try {
    await navigator.clipboard.writeText(code.value);
    copied.value = true;
    setTimeout(() => (copied.value = false), 1500);
  } catch {
    copied.value = false;
  }
}

const player = ref<InstanceType<typeof WaveformPreview>>();
const previewKey = ref(0);

type LogEntry = { id: number; name: string; payload: string };
const log = ref<LogEntry[]>([]);
const lastTime = ref('');
let nextId = 0;

function record(name: string, payload?: object) {
  log.value = [
    { id: nextId++, name, payload: payload ? JSON.stringify(payload) : '' },
    ...log.value,
  ].slice(0, 8);
}

function reload() {
  previewKey.value++;
  lastTime.value = '';
}
</script>

<template>
  <div class="wp">
    <div class="wp-stage">
      <ClientOnly>
        <WaveformPreview
          :key="previewKey"
          ref="player"
          v-bind="previewProps"
          :labels="t.labels"
          @load="record('onLoad', $event)"
          @player-state-change="record('onPlayerStateChange', $event)"
          @time-update="lastTime = JSON.stringify($event)"
          @seek="record('onSeek', $event)"
          @end="record('onEnd')"
        />
      </ClientOnly>
    </div>
    <p class="wp-note">{{ t.note }}</p>

    <div v-if="props.events" class="wp-events">
      <div class="wp-row" role="group" :aria-label="t.refMethods">
        <span class="wp-label">{{ t.refMethods }}</span>
        <button type="button" @click="player?.play()"><code>play()</code></button>
        <button type="button" @click="player?.pause()"><code>pause()</code></button>
        <button type="button" @click="player?.toggle()"><code>toggle()</code></button>
        <button type="button" @click="player?.seekTo(0)"><code>seekTo(0)</code></button>
        <button type="button" @click="player?.seekTo(4500)"><code>seekTo(4500)</code></button>
        <button type="button" @click="player?.setSpeed(2)"><code>setSpeed(2)</code></button>
        <button type="button" @click="reload">{{ t.reload }}</button>
      </div>
      <div class="wp-log">
        <div class="wp-log-head">
          <span class="wp-label">{{ t.events }}</span>
          <button type="button" @click="log = []">{{ t.clear }}</button>
        </div>
        <p v-if="lastTime" class="wp-log-line"><code>onTimeUpdate</code> <span>{{ lastTime }}</span></p>
        <ol aria-live="polite">
          <li v-for="e in log" :key="e.id" class="wp-log-line">
            <code>{{ e.name }}</code> <span>{{ e.payload }}</span>
          </li>
        </ol>
        <p v-if="log.length === 0 && !lastTime" class="wp-empty">{{ t.empty }}</p>
      </div>
    </div>

    <template v-if="props.controls">
      <div class="wp-row" role="group" :aria-label="t.presets">
        <span class="wp-label">{{ t.presets }}</span>
        <button
          v-for="(label, name) in presetLabels"
          :key="name"
          type="button"
          :aria-pressed="activePreset === name"
          @click="applyPreset(name)"
        >
          {{ label }}
        </button>
      </div>

      <div class="wp-grid">
        <fieldset>
          <legend>{{ t.colors }}</legend>
          <label v-for="k in (Object.keys(s.colors) as ColorKey[])" :key="k" class="wp-color">
            <input v-model="s.colors[k].hex" type="color" />
            <code>{{ k }}</code>
            <span v-if="k === 'unplayedBarColor' || k === 'speedBackgroundColor'" class="wp-alpha">
              <input
                v-model.number="s.colors[k].alpha"
                type="range"
                min="0"
                max="1"
                step="0.05"
                :aria-label="`${k} ${t.opacity}`"
              />
              {{ Math.round(s.colors[k].alpha * 100) }}%
            </span>
          </label>
        </fieldset>

        <fieldset>
          <legend>{{ t.bars }}</legend>
          <label class="wp-range">
            <code>barWidth</code>
            <input v-model.number="s.barWidth" type="range" min="1" max="8" step="0.5" />
            <output>{{ s.barWidth }}</output>
          </label>
          <label class="wp-range">
            <code>barGap</code>
            <input v-model.number="s.barGap" type="range" min="0" max="6" step="0.5" />
            <output>{{ s.barGap }}</output>
          </label>
          <label class="wp-range">
            <code>barRadius</code>
            <input v-model.number="s.barRadius" type="range" min="0" max="4" step="0.5" :disabled="s.autoRadius" />
            <output>{{ s.autoRadius ? s.barWidth / 2 : s.barRadius }}</output>
          </label>
          <label class="wp-check"><input v-model="s.autoRadius" type="checkbox" /> <code>barRadius</code> {{ t.auto }}</label>
          <label class="wp-range">
            <code>barCount</code>
            <input v-model.number="s.barCount" type="range" min="8" max="120" step="1" :disabled="s.autoCount" />
            <output>{{ s.autoCount ? t.auto : s.barCount }}</output>
          </label>
          <label class="wp-check"><input v-model="s.autoCount" type="checkbox" /> <code>barCount</code> {{ t.auto }}</label>
        </fieldset>

        <fieldset>
          <legend>{{ t.layout }}</legend>
          <label class="wp-range">
            <code>style.height</code>
            <input v-model.number="s.height" type="range" min="40" max="96" step="2" />
            <output>{{ s.height }}</output>
          </label>
          <label class="wp-range">
            <code>containerBorderRadius</code>
            <input v-model.number="s.containerBorderRadius" type="range" min="0" max="48" step="1" />
            <output>{{ s.containerBorderRadius }}</output>
          </label>
          <label class="wp-check"><input v-model="s.showBackground" type="checkbox" /> <code>showBackground</code></label>
          <label class="wp-check"><input v-model="s.showPlayButton" type="checkbox" /> <code>showPlayButton</code></label>
          <label class="wp-check"><input v-model="s.showTime" type="checkbox" /> <code>showTime</code></label>
          <label class="wp-check">
            <code>timeMode</code>
            <select v-model="s.timeMode">
              <option value="count-up">count-up</option>
              <option value="count-down">count-down</option>
            </select>
          </label>
          <label class="wp-check"><input v-model="s.showSpeedControl" type="checkbox" /> <code>showSpeedControl</code></label>
          <label class="wp-text">
            <code>speeds</code>
            <input v-model.lazy="s.speeds" type="text" aria-describedby="wp-speeds-hint" />
            <small id="wp-speeds-hint">{{ t.speedsHint }}</small>
          </label>
          <label class="wp-check">
            <code>defaultSpeed</code>
            <select v-model.number="s.defaultSpeed">
              <option v-for="v in speedsList" :key="v" :value="v">{{ v }}</option>
            </select>
          </label>
          <label class="wp-check"><input v-model="s.loop" type="checkbox" /> <code>loop</code></label>
        </fieldset>
      </div>

      <div class="wp-code">
        <button type="button" class="wp-copy" @click="copy">{{ copied ? t.copied : t.copy }}</button>
        <pre><code>{{ code }}</code></pre>
      </div>
    </template>
  </div>
</template>

<style scoped>
.wp {
  margin: 24px 0;
  padding: 20px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
}

.wp-stage {
  max-width: 420px;
  min-height: 56px;
  margin: 8px auto 0;
}

.wp-note {
  margin: 12px 0 16px;
  font-size: 13px;
  line-height: 1.5;
  color: var(--vp-c-text-2);
  text-align: center;
}

.wp-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
  margin: 12px 0;
}

.wp-label,
legend {
  font-size: 13px;
  font-weight: 600;
  color: var(--vp-c-text-1);
}

.wp-label {
  margin-inline-end: 4px;
}

.wp button {
  padding: 4px 10px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  background: var(--vp-c-bg);
  color: var(--vp-c-text-1);
  font-size: 13px;
  cursor: pointer;
}

.wp button:hover {
  border-color: var(--vp-c-brand-1);
}

.wp button[aria-pressed='true'] {
  border-color: var(--vp-c-brand-1);
  color: var(--vp-c-brand-1);
  font-weight: 600;
}

.wp button code {
  padding: 0;
  background: transparent;
  font-size: 12px;
}

.wp-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 16px;
}

fieldset {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
  margin: 0;
  padding: 12px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
}

fieldset label {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}

fieldset code {
  font-size: 12px;
}

.wp-color input[type='color'] {
  width: 28px;
  height: 22px;
  padding: 0;
  border: 1px solid var(--vp-c-divider);
  border-radius: 4px;
  background: none;
  cursor: pointer;
}

.wp-alpha {
  display: flex;
  align-items: center;
  gap: 6px;
  width: 100%;
  padding-inline-start: 36px;
  color: var(--vp-c-text-2);
  font-size: 12px;
}

.wp-alpha input {
  flex: 1;
  min-width: 0;
}

.wp-range code {
  flex: 1 1 100%;
}

.wp-range input {
  flex: 1;
  min-width: 0;
  accent-color: var(--vp-c-brand-1);
}

.wp-range output {
  min-width: 3em;
  font-size: 12px;
  color: var(--vp-c-text-2);
  text-align: end;
}

.wp-check input {
  accent-color: var(--vp-c-brand-1);
}

.wp select,
.wp-text input {
  padding: 2px 6px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 6px;
  background: var(--vp-c-bg);
  color: var(--vp-c-text-1);
  font-size: 13px;
}

.wp-text input {
  flex: 1;
  min-width: 0;
}

.wp-text small {
  flex: 1 1 100%;
  color: var(--vp-c-text-2);
  font-size: 12px;
}

.wp-code {
  position: relative;
  margin-top: 16px;
  border-radius: 8px;
  background: var(--vp-code-block-bg);
}

.wp-code pre {
  margin: 0;
  padding: 16px;
  overflow-x: auto;
  font-size: 13px;
  line-height: 1.6;
}

.wp-code pre code {
  padding: 0;
  background: transparent;
  color: var(--vp-code-block-color);
}

.wp-copy {
  position: absolute;
  top: 8px;
  right: 8px;
}

.wp-events {
  margin-bottom: 8px;
}

.wp-log {
  padding: 12px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  background: var(--vp-c-bg);
}

.wp-log-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.wp-log ol {
  margin: 0;
  padding: 0;
  list-style: none;
}

.wp-log-line {
  margin: 2px 0;
  overflow-wrap: anywhere;
  font-family: var(--vp-font-family-mono);
  font-size: 12px;
  line-height: 1.6;
}

.wp-log-line span {
  color: var(--vp-c-text-2);
}

.wp-empty {
  margin: 0;
  font-size: 13px;
  color: var(--vp-c-text-2);
}
</style>
