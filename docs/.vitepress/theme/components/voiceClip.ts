/**
 * A short voice-note-like clip generated in the browser, so the docs ship no
 * audio file. Syllables are harmonic tones with a vowel-like spectral tilt
 * and a soft attack, grouped into words with pauses.
 */

export type VoiceClip = {
  samples: Float32Array;
  sampleRate: number;
  durationMs: number;
  url: string;
};

const SAMPLE_RATE = 22050;
const DURATION_S = 9;

let cached: VoiceClip | undefined;

function mulberry32(seed: number) {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function synthesize(): Float32Array {
  const rand = mulberry32(1410);
  const total = SAMPLE_RATE * DURATION_S;
  const out = new Float32Array(total);
  let t = 0.25;
  while (t < DURATION_S - 0.4) {
    const syllables = 2 + Math.floor(rand() * 4);
    for (let s = 0; s < syllables && t < DURATION_S - 0.4; s++) {
      const len = 0.12 + rand() * 0.24;
      const gain = 0.35 + rand() * 0.65;
      const f0 = 130 + rand() * 90;
      const glide = (rand() - 0.5) * 40;
      const tilt = 0.45 + rand() * 0.35;
      const start = Math.floor(t * SAMPLE_RATE);
      const n = Math.floor(len * SAMPLE_RATE);
      let phase = 0;
      for (let i = 0; i < n && start + i < total; i++) {
        const x = i / n;
        const env = Math.min(1, x / 0.12) * Math.pow(1 - x, 1.4);
        const f = f0 + glide * x;
        phase += (2 * Math.PI * f) / SAMPLE_RATE;
        let v = 0;
        let w = 1;
        for (let h = 1; h <= 7; h++) {
          v += w * Math.sin(phase * h);
          w *= tilt;
        }
        const breath = x < 0.08 ? (rand() - 0.5) * 0.6 : 0;
        out[start + i] += (v * 0.32 + breath) * env * gain;
      }
      t += len + 0.03 + rand() * 0.08;
    }
    t += 0.18 + rand() * 0.35;
  }
  let peak = 0;
  for (let i = 0; i < total; i++) peak = Math.max(peak, Math.abs(out[i]));
  const scale = peak > 0 ? 0.85 / peak : 1;
  for (let i = 0; i < total; i++) {
    out[i] = out[i] * scale + (rand() - 0.5) * 0.002;
  }
  return out;
}

function encodeWav(samples: Float32Array, sampleRate: number): Blob {
  const buffer = new ArrayBuffer(44 + samples.length * 2);
  const view = new DataView(buffer);
  const writeString = (offset: number, s: string) => {
    for (let i = 0; i < s.length; i++) view.setUint8(offset + i, s.charCodeAt(i));
  };
  writeString(0, 'RIFF');
  view.setUint32(4, 36 + samples.length * 2, true);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeString(36, 'data');
  view.setUint32(40, samples.length * 2, true);
  for (let i = 0; i < samples.length; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    view.setInt16(44 + i * 2, v * 0x7fff, true);
  }
  return new Blob([buffer], { type: 'audio/wav' });
}

export function getVoiceClip(): VoiceClip {
  if (!cached) {
    const samples = synthesize();
    cached = {
      samples,
      sampleRate: SAMPLE_RATE,
      durationMs: DURATION_S * 1000,
      url: URL.createObjectURL(encodeWav(samples, SAMPLE_RATE)),
    };
  }
  return cached;
}

/**
 * Same reduction as the native decoders: each bar covers a fixed time
 * window, holds the RMS of its samples, and the array is normalised against
 * the loudest bar.
 */
export function amplitudesFor(clip: VoiceClip, barCount: number): number[] {
  if (barCount <= 0) return [];
  const sumSquares = new Float64Array(barCount);
  const counts = new Uint32Array(barCount);
  const { samples } = clip;
  for (let i = 0; i < samples.length; i++) {
    const bar = Math.min(barCount - 1, Math.floor((i * barCount) / samples.length));
    sumSquares[bar] += samples[i] * samples[i];
    counts[bar] += 1;
  }
  const rms = Array.from(sumSquares, (s, i) =>
    counts[i] > 0 ? Math.sqrt(s / counts[i]) : 0
  );
  const max = Math.max(...rms);
  return max > 0 ? rms.map((v) => v / max) : rms;
}
