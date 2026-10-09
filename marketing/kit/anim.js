// Browser-side helpers shared by every ad scene. Every visual is a pure
// function of t (seconds), so the renderer can seek to any frame and get the
// same pixels: nothing here uses CSS transitions or wall clocks.

import { EMOJI, forVariant, tokenize } from "./text.mjs";

export const $ = (s, root = document) => root.querySelector(s);
export const $$ = (s, root = document) => [...root.querySelectorAll(s)];
export const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const prog = (t, a, b) => clamp((t - a) / (b - a));
export const lerp = (a, b, p) => a + (b - a) * p;
export const easeOut = (p) => 1 - Math.pow(1 - p, 3);
export const easeIn = (p) => p * p * p;
export const easeInOut = (p) => (p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2);
export const easeBack = (p) => {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * Math.pow(p - 1, 3) + c1 * Math.pow(p - 1, 2);
};

export const emojiSrc = (code) => `/public/openmoji/${code}.svg`;
export const variant = new URLSearchParams(location.search).get("variant");

// Writes only the style properties that changed since the last frame.
export function css(el, props) {
  const cache = (el.__css ||= {});
  for (const k in props) {
    const v = props[k];
    if (cache[k] !== v) {
      el.style[k] = v;
      cache[k] = v;
    }
  }
}

export const show = (el, on) => css(el, { display: on ? "" : "none" });

export function posIn(el, root) {
  let x = 0;
  let y = 0;
  let n = el;
  while (n && n !== root) {
    x += n.offsetLeft;
    y += n.offsetTop;
    n = n.offsetParent;
  }
  return { x: x + el.offsetWidth / 2, y: y + el.offsetHeight / 2 };
}

export function popIn(t, at, dur = 0.22, from = 0.85) {
  if (t < at) return { on: false };
  const p = prog(t, at, at + dur);
  return { on: true, scale: lerp(from, 1, easeBack(p)), opacity: Math.min(1, p * 2.5) };
}

// ---------- rich text ----------

export function buildRich(el, text) {
  el.textContent = "";
  el.__units = tokenize(text).map((u) => {
    let node;
    if (u.kind === "break") {
      node = document.createElement("span");
      node.className = "br";
    } else if (u.kind === "emoji") {
      node = document.createElement("img");
      node.className = "emo";
      node.src = emojiSrc(u.code);
    } else {
      node = document.createElement(u.style === "bold" ? "strong" : "span");
      if (u.style === "hl") node.className = "hl";
      node.textContent = u.ch;
    }
    el.appendChild(node);
    return node;
  });
  el.__shown = el.__units.length;
}

export function reveal(el, n) {
  const units = el.__units;
  n = clamp(Math.floor(n), 0, units.length);
  if (n === el.__shown) return;
  const [a, b] = n < el.__shown ? [n, el.__shown] : [el.__shown, n];
  for (let i = a; i < b; i++) units[i].style.display = i < n ? "" : "none";
  el.__shown = n;
}

// ---------- captions ----------

function buildCaptionLine(text) {
  const span = document.createElement("span");
  span.className = "cline";
  const parts = text.split(/(\*[^*]+\*|:[a-z_]+:)/g).filter(Boolean);
  for (const p of parts) {
    if (p.startsWith("*")) {
      const hl = document.createElement("span");
      hl.className = "hl";
      hl.textContent = p.slice(1, -1);
      span.appendChild(hl);
    } else if (/^:[a-z_]+:$/.test(p) && EMOJI[p.slice(1, -1)]) {
      const img = document.createElement("img");
      img.className = "emo";
      img.src = emojiSrc(EMOJI[p.slice(1, -1)]);
      span.appendChild(img);
    } else {
      span.appendChild(document.createTextNode(p));
    }
  }
  return span;
}

export function buildCaptions(root, captions) {
  return forVariant(captions, variant).map((c, i) => {
    const el = document.createElement("div");
    el.className = "caption";
    const lines = c.lines.map((l, j) => {
      const line = buildCaptionLine(l);
      line.__tilt = (i + j) % 2 === 0 ? -1.4 : 1.2;
      el.appendChild(line);
      return line;
    });
    root.appendChild(el);
    return { ...c, el, lines };
  });
}

// Shrinks any caption line that would overflow the safe width. Run after fonts load.
export function fitCaptions(captionEls, maxWidth = 980) {
  for (const c of captionEls) {
    c.el.style.opacity = "1";
    for (const line of c.lines) {
      const w = line.offsetWidth;
      const size = parseFloat(getComputedStyle(line).fontSize);
      if (w > maxWidth) line.style.fontSize = `${Math.floor((size * maxWidth) / w)}px`;
    }
    c.el.style.opacity = "0";
  }
}

export function renderCaptions(t, captionEls, duration) {
  for (const c of captionEls) {
    const on = t >= c.from && t < c.to;
    if (!on) {
      css(c.el, { opacity: "0", display: "none" });
      continue;
    }
    const out = c.to >= duration - 0.01 ? 1 : 1 - prog(t, c.to - 0.12, c.to);
    css(c.el, { display: "", opacity: String(out) });
    c.lines.forEach((line, j) => {
      const p = prog(t, c.from + j * 0.07, c.from + j * 0.07 + 0.3);
      const s = lerp(0.6, 1, easeBack(p));
      css(line, { transform: `rotate(${line.__tilt}deg) scale(${s.toFixed(4)})`, opacity: String(Math.min(1, p * 3)) });
    });
  }
}

// ---------- Gabby art ----------

let SPRITES;
const spriteEls = [];

function buildAvatar(el) {
  const size = parseFloat(el.style.width);
  const meta = SPRITES[el.dataset.avatar];
  const img = document.createElement("img");
  img.src = meta.url;
  const h = size * 1.3;
  css(img, { height: `${h}px`, width: `${(h * meta.w) / meta.h}px`, top: `${size * 0.08}px` });
  el.appendChild(img);
}

function buildSprite(el) {
  const size = parseFloat(el.style.width);
  const meta = SPRITES[el.dataset.sprite];
  const s = document.createElement("div");
  s.className = "sprite";
  const h = size * 1.3;
  css(s, {
    height: `${h}px`,
    width: `${(h * meta.fw) / meta.fh}px`,
    top: `${size * 0.08}px`,
    backgroundImage: `url(${meta.url})`,
    backgroundSize: `${meta.cols * 100}% ${meta.rows * 100}%`,
  });
  el.appendChild(s);
  spriteEls.push({ el: s, meta, offset: spriteEls.length * 0.37 });
}

// Fills img[data-src], img[data-emoji], [data-avatar] and [data-sprite] from
// the sprite sheets render.mjs cut from public/gabby.
export async function buildArt() {
  SPRITES = await (await fetch("build/sprites.json")).json();
  $$("img[data-src]").forEach((img) => (img.src = SPRITES[img.dataset.src].url));
  $$("img[data-emoji]").forEach((img) => (img.src = emojiSrc(EMOJI[img.dataset.emoji])));
  $$("[data-avatar]").forEach(buildAvatar);
  $$("[data-sprite]").forEach(buildSprite);
  return SPRITES;
}

export function renderSprites(t) {
  for (const s of spriteEls) {
    const i = Math.floor((t + s.offset) * s.meta.fps) % s.meta.frames;
    const col = i % s.meta.cols;
    const row = Math.floor(i / s.meta.cols);
    css(s.el, {
      backgroundPosition: `${(col / (s.meta.cols - 1)) * 100}% ${(row / Math.max(1, s.meta.rows - 1)) * 100}%`,
    });
  }
}

// ---------- the app's illustrated icons ----------

// Fills <span data-si="flame" data-size="40"> with the StudyIcon artwork that
// render.mjs reads out of components/study/StudyIcon.tsx.
export async function buildStudyIcons() {
  const icons = await (await fetch("build/study-icons.json")).json();
  for (const el of $$("[data-si]")) {
    const icon = icons[el.dataset.si];
    if (!icon) throw new Error(`Unknown StudyIcon "${el.dataset.si}"`);
    const size = Number(el.dataset.size || 44);
    el.classList.add("si", `t-${icon.tone}`);
    css(el, { width: `${size}px`, height: `${size}px` });
    el.innerHTML = `<svg viewBox="0 0 48 48">${icon.svg}</svg>`;
  }
}

// ---------- tactile press ----------

// How far a ledge button is pushed in at time t for a tap at `at`: 0 = resting
// on its ledge, 1 = sunk flush. Down fast, back up with a little spring.
export function pressDepth(t, at) {
  if (t < at - 0.06 || t > at + 0.3) return 0;
  if (t < at) return prog(t, at - 0.06, at);
  return 1 - easeBack(prog(t, at + 0.04, at + 0.3));
}

// ---------- confetti ----------

const CONFETTI = ["#f97316", "#fbbf24", "#34d399", "#60a5fa", "#f472b6", "#a78bfa"];

// A seeded burst, so every render of a frame throws the same pieces.
export function createConfetti(root, count, seed = 1) {
  let s = seed;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  return Array.from({ length: count }, (_, i) => {
    const el = document.createElement("i");
    const w = 12 + rnd() * 14;
    css(el, {
      position: "absolute", left: "0", top: "0", width: `${w}px`, height: `${w * (0.4 + rnd() * 0.5)}px`,
      background: CONFETTI[i % CONFETTI.length], borderRadius: rnd() < 0.3 ? "50%" : "3px", display: "none",
    });
    root.appendChild(el);
    const ang = -Math.PI / 2 + (rnd() - 0.5) * 2.2;
    const speed = 900 + rnd() * 1100;
    return { el, vx: Math.cos(ang) * speed, vy: Math.sin(ang) * speed, spin: (rnd() - 0.5) * 1400, wobble: rnd() * 6.28 };
  });
}

export function renderConfetti(t, pieces, at, x, y, life = 1.6) {
  const dt = t - at;
  for (const p of pieces) {
    if (dt < 0 || dt > life) {
      css(p.el, { display: "none" });
      continue;
    }
    const drag = Math.exp(-dt * 1.6);
    const px = x + (p.vx * (1 - drag)) / 1.6 + Math.sin(dt * 7 + p.wobble) * 18;
    const py = y + (p.vy * (1 - drag)) / 1.6 + 900 * dt * dt;
    css(p.el, {
      display: "",
      transform: `translate(${px.toFixed(1)}px, ${py.toFixed(1)}px) rotate(${(p.spin * dt).toFixed(1)}deg) scaleX(${Math.cos(dt * 9 + p.wobble).toFixed(3)})`,
      opacity: String(Math.min(1, (life - dt) / 0.4)),
    });
  }
}

// ---------- finger taps ----------

// taps: [{ t, el }]; tap/ring live inside `root`, positioned in its coordinates.
export function renderTap(t, taps, root, tap, ring) {
  const active = taps.find((k) => t >= k.t - 0.18 && t <= k.t + 0.4);
  if (!active) {
    css(tap, { opacity: "0" });
    css(ring, { opacity: "0" });
    return;
  }
  const { x, y } = posIn(active.el, root);
  const pin = prog(t, active.t - 0.18, active.t);
  const pout = prog(t, active.t + 0.05, active.t + 0.3);
  css(tap, {
    left: `${x}px`,
    top: `${y}px`,
    opacity: String(Math.min(pin * 1.5, 1 - pout)),
    transform: `scale(${lerp(1.35, 0.9, easeOut(pin)).toFixed(3)})`,
  });
  const pr = prog(t, active.t, active.t + 0.4);
  css(ring, {
    left: `${x}px`,
    top: `${y}px`,
    opacity: t < active.t ? "0" : String(1 - pr),
    transform: `scale(${lerp(1, 2.3, easeOut(pr)).toFixed(3)})`,
  });
}

// ---------- boot ----------

export async function settle(fonts) {
  await document.fonts.ready;
  await Promise.all(fonts.map((f) => document.fonts.load(f)));
}

export async function decodeImages() {
  const urls = new Set([
    ...$$("img").map((i) => i.src),
    ...Object.values(SPRITES ?? {}).map((s) => new URL(s.url, location.href).href),
  ]);
  await Promise.all(
    [...urls].map((u) => {
      const im = new Image();
      im.src = u;
      return im.decode().catch(() => {});
    }),
  );
  await Promise.all($$("img").map((i) => i.decode().catch(() => {})));
}

// Exposes window.__ready / window.renderAt for render.mjs; ?play runs it live,
// ?t=12.3 holds one frame.
export function boot(build, render, duration) {
  window.__ready = build().then(() => {
    window.renderAt = (t) => {
      render(t);
      return true;
    };
    const params = new URLSearchParams(location.search);
    if (params.has("play")) {
      const start = performance.now() - Number(params.get("play") || 0) * 1000;
      const loop = () => {
        render(((performance.now() - start) / 1000) % duration);
        requestAnimationFrame(loop);
      };
      loop();
    } else {
      render(Number(params.get("t") || 0));
    }
    return true;
  });
}
