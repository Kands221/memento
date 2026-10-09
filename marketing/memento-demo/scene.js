// The Memento demo, as a pure function of t: render(t) draws the frame at t seconds, so the kit can capture
// any frame on its own. Timing lives in timeline.mjs.

import { $, $$, clamp, css, easeBack, easeInOut, easeOut, lerp, prog } from "../kit/anim.js";
import { BULLETS, CAPTIONS, DURATION, FPS, POSES, SEGMENTS, T, VO } from "./timeline.mjs";

let frames = {};
let caps = [];
let bullets = [];
let lastSrc = "";

// Sol's place: big in the opening and the close, small beside the phone in between.
const BIG = { x: 540, y: 1420, w: 800 };
const HOST = { x: 108, y: 1895, w: 226 };
const OUTRO = { x: 540, y: 1060, w: 560 };
const END = { x: 540, y: 1100, w: 520 };

function buildCaptions() {
  const root = $("#captions");
  caps = CAPTIONS.map((c) => {
    const el = document.createElement("div");
    el.className = "cap";
    el.innerHTML =
      c.lines.map((l) => `<span class="l">${l.replace(/\*([^*]+)\*/g, '<span class="hl">$1</span>')}</span>`).join("") +
      (c.sub ? `<span class="sub">${c.sub}</span>` : "");
    root.appendChild(el);
    return { ...c, el };
  });
}

async function build() {
  frames = await (await fetch("build/frames.json")).json();
  buildCaptions();
  bullets = BULLETS.map((text) => {
    const el = document.createElement("div");
    el.className = "bul";
    el.innerHTML = `<i></i><span></span>`;
    el.querySelector("span").textContent = text;
    $("#bullets").appendChild(el);
    return el;
  });
  await document.fonts.ready;
  await Promise.all(["500 86px Newsreader", "italic 500 86px Newsreader", "italic 400 64px Newsreader"].map((f) => document.fonts.load(f)));
  await Promise.all($$("img").map((i) => i.decode().catch(() => {})));
}

// ---------- pieces ----------

function renderBackground(t) {
  css($("#glow1"), { transform: `translate(${-180 + Math.sin(t * 0.35) * 70}px, ${120 + Math.cos(t * 0.3) * 60}px)` });
  css($("#glow2"), { transform: `translate(${560 + Math.cos(t * 0.28) * 80}px, ${1200 + Math.sin(t * 0.33) * 70}px)` });
}

function renderCaptions(t) {
  for (const c of caps) {
    const on = t >= c.from && t < c.to;
    if (!on) {
      css(c.el, { opacity: "0" });
      continue;
    }
    const pin = easeOut(prog(t, c.from, c.from + 0.4));
    const pout = c.to >= DURATION - 0.01 ? 0 : prog(t, c.to - 0.18, c.to);
    css(c.el, { opacity: String(pin * (1 - pout)), transform: `translateY(${(1 - pin) * 26}px)` });
  }
}

const segAt = (t) => SEGMENTS.find((s) => t >= s.at && t < s.to);

async function renderPhone(t) {
  const inP = easeOut(prog(t, T.phoneIn, T.phoneIn + 0.8));
  const outP = easeInOut(prog(t, T.phoneOut, T.phoneOut + 0.7));
  const shown = inP > 0 && outP < 1;
  // A gentle push-in on Sol's memory, centred on his reply.
  const zin = easeInOut(prog(t, T.zoomIn, T.zoomIn + 0.9));
  const zout = easeInOut(prog(t, T.zoomOut, T.zoomOut + 0.5));
  const zoom = 1 + 0.13 * zin * (1 - zout);
  const y = (1 - inP) * 1500 + outP * 1500;
  css($("#phone"), { display: shown ? "" : "none", transform: `translateY(${y.toFixed(1)}px) scale(${zoom.toFixed(4)})`, transformOrigin: "50% 66%" });

  // The chip that cites the journal gets a soft ring.
  const ringP = prog(t, T.chip, T.chip + 0.35);
  const ringOut = prog(t, T.zoomOut - 0.2, T.zoomOut + 0.2);
  css($("#ring"), {
    left: "102px", top: "940px", width: "360px", height: "64px",
    opacity: String(Math.min(1, ringP * 1.4) * (1 - ringOut)), transform: `scale(${lerp(1.25, 1, easeBack(ringP)).toFixed(3)})`,
  });

  const seg = segAt(t);
  if (!shown || !seg) return;
  const n = frames[seg.id];
  const i = clamp(Math.floor((t - seg.at) * FPS), 0, n - 1) + 1;
  const src = `build/frames/${seg.id}/${String(i).padStart(5, "0")}.jpg`;
  if (src !== lastSrc) {
    const img = $("#screen");
    img.src = src;
    lastSrc = src;
    await img.decode().catch(() => {});
  }
}

const poseAt = (t) => [...POSES].reverse().find((p) => t >= p.from).pose;
const solSpeaking = (t) => VO.some((v) => v.who === "Sol" && t >= v.from && t < v.to);

function place(t) {
  const toHost = easeInOut(prog(t, T.phoneIn, T.phoneIn + 0.8));
  const toOutro = easeInOut(prog(t, T.phoneOut, T.phoneOut + 0.8));
  const toEnd = easeInOut(prog(t, T.end, T.end + 0.6));
  const mix = (a, b, p) => ({ x: lerp(a.x, b.x, p), y: lerp(a.y, b.y, p), w: lerp(a.w, b.w, p) });
  let p = mix(BIG, HOST, toHost);
  if (toOutro > 0) p = mix(HOST, OUTRO, toOutro);
  if (toEnd > 0) p = mix(OUTRO, END, toEnd);
  return p;
}

function renderSol(t) {
  const { x, y, w } = place(t);
  const pop = easeBack(prog(t, 0.1, 0.7));
  const speaking = solSpeaking(t);
  const bob = Math.sin(t * 2.1) * 7 + (speaking ? Math.sin(t * 7.5) * 3 : 0);
  const tilt = Math.sin(t * 1.2) * 1.4 + (speaking ? Math.sin(t * 5.3) * 1.6 : 0);
  const breathe = 1 + Math.sin(t * 2.1 + 1) * 0.008;
  const h = w; // the cutouts are roughly square
  css($("#sol"), {
    left: `${(x - w / 2).toFixed(1)}px`, top: `${(y - h).toFixed(1)}px`, width: `${w.toFixed(1)}px`, height: `${h.toFixed(1)}px`,
    transform: `translateY(${bob.toFixed(2)}px) rotate(${tilt.toFixed(2)}deg) scale(${(pop * breathe).toFixed(4)})`,
  });
  css($("#sol-shadow"), {
    left: `${(x - w * 0.42).toFixed(1)}px`, top: `${(y - w * 0.07).toFixed(1)}px`, width: `${(w * 0.84).toFixed(1)}px`, height: `${(w * 0.13).toFixed(1)}px`,
    opacity: String(pop * (0.9 - bob * 0.01)),
  });

  // Cross-fade between poses.
  const current = poseAt(t);
  const change = [...POSES].reverse().find((p) => t >= p.from);
  const prev = POSES[POSES.indexOf(change) - 1]?.pose;
  const f = prog(t, change.from, change.from + 0.18);
  for (const img of $$("#sol img")) {
    const pose = img.dataset.pose;
    css(img, { opacity: String(pose === current ? f : pose === prev && f < 1 ? 1 - f : 0) });
  }

  // Speaking ripples by his head while his voice plays.
  const waves = [$("#wave1"), $("#wave2")];
  waves.forEach((el, i) => {
    const phase = ((t * 1.6 + i * 0.5) % 1);
    const size = w * (0.16 + phase * 0.14);
    css(el, {
      left: `${(x + w * 0.36 - size / 2).toFixed(1)}px`, top: `${(y - h * 0.86 - size / 2).toFixed(1)}px`,
      width: `${size.toFixed(1)}px`, height: `${size.toFixed(1)}px`, transform: "rotate(45deg)",
      // Only when he's big enough for the ripples to read as his voice.
      opacity: speaking && w > 450 ? String((1 - phase) * 0.75) : "0",
    });
  });
}

function renderOutro(t) {
  const why = easeOut(prog(t, T.why, T.why + 0.45)) * (1 - prog(t, T.end - 0.2, T.end + 0.1));
  css($("#why"), { opacity: String(why), transform: `translateY(${(1 - Math.min(1, why * 2)) * 24}px)` });
  bullets.forEach((el, i) => {
    const p = easeBack(prog(t, T.bullets[i], T.bullets[i] + 0.35));
    const out = prog(t, T.end - 0.2, T.end + 0.1);
    css(el, { opacity: String(Math.min(1, p * 2) * (1 - out)), transform: `translateX(${((1 - p) * -60).toFixed(1)}px)` });
  });
  const end = easeOut(prog(t, T.end + 0.15, T.end + 0.75));
  css($("#endcard"), { opacity: String(end), transform: `translateY(${(1 - end) * 30}px)` });
}

async function render(t) {
  renderBackground(t);
  renderCaptions(t);
  renderSol(t);
  renderOutro(t);
  await renderPhone(t);
}

window.__ready = build().then(async () => {
  window.renderAt = async (t) => {
    await render(t);
    return true;
  };
  const params = new URLSearchParams(location.search);
  if (params.has("play")) {
    const start = performance.now() - Number(params.get("play") || 0) * 1000;
    const loop = async () => {
      await render(((performance.now() - start) / 1000) % DURATION);
      requestAnimationFrame(loop);
    };
    loop();
  } else {
    await render(Number(params.get("t") || 0));
  }
  return true;
});
