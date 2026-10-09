// Synthesizes every sound effect from scratch (sines, noise, filters), so the
// ad carries no licensed audio. Mono, 48 kHz, mixed at the cue times in SFX.

import { writeFile } from "node:fs/promises";

export const SR = 48000;
const TAU = Math.PI * 2;

function rng(seed = 1) {
  let s = seed >>> 0 || 1;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let x = Math.imul(s ^ (s >>> 15), 1 | s);
    x = (x + Math.imul(x ^ (x >>> 7), 61 | x)) ^ x;
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

const buf = (dur) => new Float32Array(Math.ceil(dur * SR));

function tone(out, { at = 0, freq, dur, amp = 1, attack = 0.002, decay = 0.1, harmonics = [] }) {
  const start = Math.floor(at * SR);
  const n = Math.min(out.length - start, Math.ceil(dur * SR));
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const env = (1 - Math.exp(-t / attack)) * Math.exp(-t / decay);
    let v = Math.sin(TAU * freq * t);
    for (const [ratio, a] of harmonics) v += a * Math.sin(TAU * freq * ratio * t);
    out[start + i] += v * env * amp;
  }
}

function sweep(dur, f0, f1, tau, decay, attack = 0.0015) {
  const out = buf(dur);
  let phase = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    const f = f1 + (f0 - f1) * Math.exp(-t / tau);
    phase += (TAU * f) / SR;
    out[i] = Math.sin(phase) * (1 - Math.exp(-t / attack)) * Math.exp(-t / decay);
  }
  return out;
}

function bandNoise(dur, f0, f1, q, seed) {
  const r = rng(seed);
  const out = buf(dur);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  let b0 = 0, b2 = 0, a1 = 0, a2 = 0;
  for (let i = 0; i < out.length; i++) {
    if (i % 32 === 0) {
      const f = f0 * Math.pow(f1 / f0, i / out.length);
      const w = (TAU * f) / SR;
      const alpha = Math.sin(w) / (2 * q);
      const a0 = 1 + alpha;
      b0 = alpha / a0;
      b2 = -alpha / a0;
      a1 = (-2 * Math.cos(w)) / a0;
      a2 = (1 - alpha) / a0;
    }
    const x = r() * 2 - 1;
    const y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    out[i] = y;
  }
  return out;
}

const SYNTHS = {
  tap({ seed = 3 }) {
    const out = buf(0.08);
    const r = rng(seed);
    let prev = 0;
    for (let i = 0; i < out.length; i++) {
      const t = i / SR;
      const n = r() * 2 - 1;
      const click = (n - prev) * Math.exp(-t / 0.004);
      prev = n;
      out[i] = click * 0.5 + Math.sin(TAU * 1500 * t) * Math.exp(-t / 0.007) * 0.5 + Math.sin(TAU * 170 * t) * Math.exp(-t / 0.025) * 0.6;
    }
    return out;
  },

  pop({ pitch = 1 }) {
    return sweep(0.16, 1250 * pitch, 330 * pitch, 0.014, 0.045);
  },

  bloop() {
    const out = buf(0.2);
    let phase = 0;
    for (let i = 0; i < out.length; i++) {
      const t = i / SR;
      const f = 380 + 700 * (1 - Math.exp(-t / 0.045));
      phase += (TAU * f) / SR;
      out[i] = Math.sin(phase) * (1 - Math.exp(-t / 0.002)) * Math.exp(-t / 0.06);
    }
    return out;
  },

  receive() {
    const out = buf(0.4);
    tone(out, { at: 0, freq: 987.8, dur: 0.3, amp: 0.6, decay: 0.08, harmonics: [[2, 0.2]] });
    tone(out, { at: 0.075, freq: 1318.5, dur: 0.3, amp: 0.6, decay: 0.1, harmonics: [[2, 0.2]] });
    return out;
  },

  whoosh({ dur = 0.45, seed = 11 }) {
    const out = bandNoise(dur, 350, 3200, 1.2, seed);
    for (let i = 0; i < out.length; i++) {
      const p = i / out.length;
      out[i] *= 3.2 * Math.pow(Math.sin(Math.PI * Math.pow(p, 0.65)), 2);
    }
    return out;
  },

  buzz() {
    const out = buf(0.36);
    let lp = 0;
    for (let i = 0; i < out.length; i++) {
      const t = i / SR;
      const local = t < 0.15 ? t : t - 0.17;
      const on = t < 0.13 || (t >= 0.17 && t < 0.32);
      const f = 145;
      const saw = 2 * (t * f - Math.floor(t * f + 0.5));
      const sq = Math.sign(Math.sin(TAU * f * 1.01 * t));
      const raw = on ? (saw * 0.6 + sq * 0.4) * (1 - Math.exp(-local / 0.004)) * Math.exp(-local / 0.12) : 0;
      lp += 0.18 * (raw - lp);
      out[i] = lp;
    }
    return out;
  },

  ding() {
    const out = buf(1.6);
    const base = 1318.5;
    const partials = [
      [1, 1, 0.9],
      [2.01, 0.45, 0.5],
      [2.76, 0.28, 0.35],
      [4.07, 0.12, 0.2],
    ];
    for (const [ratio, amp, decay] of partials) tone(out, { freq: base * ratio, dur: 1.6, amp: amp * 0.55, decay, attack: 0.001 });
    return out;
  },

  sparkle() {
    const out = buf(0.8);
    [2093, 2637, 3136, 4186, 3520, 4699].forEach((f, i) => tone(out, { at: i * 0.045, freq: f, dur: 0.5, amp: 0.28, decay: 0.12, attack: 0.001 }));
    return out;
  },

  tick({ seed = 1 }) {
    const out = buf(0.035);
    const r = rng(seed + 101);
    const f = 2800 + r() * 900;
    let prev = 0;
    for (let i = 0; i < out.length; i++) {
      const t = i / SR;
      const n = r() * 2 - 1;
      out[i] = (n - prev) * Math.exp(-t / 0.0025) * 0.6 + Math.sin(TAU * f * t) * Math.exp(-t / 0.003) * 0.4;
      prev = n;
    }
    return out;
  },

  check() {
    const out = buf(0.3);
    tone(out, { at: 0, freq: 1318.5, dur: 0.2, amp: 0.5, decay: 0.05 });
    tone(out, { at: 0.06, freq: 1760, dur: 0.24, amp: 0.55, decay: 0.08 });
    const tap = SYNTHS.tap({ seed: 9 });
    for (let i = 0; i < tap.length; i++) out[i] += tap[i] * 0.6;
    return out;
  },
};

// A countdown beep: short, round, with a soft octave on top.
SYNTHS.beep = ({ pitch = 1 }) => {
  const out = buf(0.18);
  tone(out, { freq: 880 * pitch, dur: 0.18, amp: 0.7, decay: 0.06, attack: 0.002, harmonics: [[2, 0.15]] });
  return out;
};

// A rubber-stamp slam: a low thump plus a dry click.
SYNTHS.thud = ({ seed = 5 }) => {
  const out = buf(0.3);
  const r = rng(seed);
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    const f = 60 + 90 * Math.exp(-t / 0.03);
    out[i] = Math.sin(TAU * f * t) * Math.exp(-t / 0.09) * 0.9 + (r() * 2 - 1) * Math.exp(-t / 0.006) * 0.5;
  }
  return out;
};

export function synthesize(cues, duration) {
  const mix = buf(duration);
  for (const cue of cues) {
    const synth = SYNTHS[cue.kind];
    if (!synth) throw new Error(`Unknown SFX kind: ${cue.kind}`);
    const s = synth(cue);
    const start = Math.floor(cue.t * SR);
    const gain = cue.gain ?? 1;
    for (let i = 0; i < s.length && start + i < mix.length; i++) mix[start + i] += s[i] * gain;
  }
  let peak = 0;
  for (let i = 0; i < mix.length; i++) {
    mix[i] = Math.tanh(mix[i] * 1.1);
    peak = Math.max(peak, Math.abs(mix[i]));
  }
  const norm = peak > 0 ? 0.89 / peak : 1;
  for (let i = 0; i < mix.length; i++) mix[i] *= norm;
  return mix;
}

export async function writeWav(path, samples) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), i * 2);
  const h = Buffer.alloc(44);
  h.write("RIFF", 0);
  h.writeUInt32LE(36 + data.length, 4);
  h.write("WAVE", 8);
  h.write("fmt ", 12);
  h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20);
  h.writeUInt16LE(1, 22);
  h.writeUInt32LE(SR, 24);
  h.writeUInt32LE(SR * 2, 28);
  h.writeUInt16LE(2, 32);
  h.writeUInt16LE(16, 34);
  h.write("data", 36);
  h.writeUInt32LE(data.length, 40);
  await writeFile(path, Buffer.concat([h, data]));
}
