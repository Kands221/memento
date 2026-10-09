// The Memento story, as a pure function of t (seconds). Timing and positions live in timeline.mjs.
import { $, $$, clamp, css, easeBack, easeInOut, easeOut, lerp, prog } from "../kit/anim.js";

// The page's own timeline (memento-story or memento-story-30 share this scene).
const tl = await import(new URL("timeline.mjs", location.href).href);
const { ANCHORS, CHIPS, FPS, PHONE, SCENES, SEGMENTS, SOL, T, VO, WIDTH, HEIGHT } = tl;

let frames = {};
let speech = [];
let shots = [];
let chips = [];
let lastSrc = "";
const probe = document.createElement("canvas");
probe.width = 8;
probe.height = 8;
const probeCtx = probe.getContext("2d", { willReadFrequently: true });

const px = (a) => ({ x: a.x * WIDTH, y: a.y * HEIGHT });

async function decodeRequiredImage(img) {
  try {
    await img.decode();
  } catch (cause) {
    throw new Error(`Required image failed to decode: ${img.src}`, { cause });
  }
}

async function build() {
  frames = await (await fetch("build/frames.json")).json();
  speech = await fetch("build/vo-timing.json").then((r) => (r.ok ? r.json() : null)).catch(() => null)
    ?? VO.map((v) => ({ text: v.text, who: v.who, start: v.from, out: v.to }));
  shots = SCENES.map((s) => {
    const img = document.createElement("img");
    img.className = "shot";
    img.src = `build/art/${s.img}.jpg`;
    $("#world").appendChild(img);
    return { ...s, el: img };
  });
  chips = CHIPS.map((c) => {
    const el = document.createElement("div");
    el.className = "chip";
    el.innerHTML = "<i></i><span></span>";
    el.querySelector("span").textContent = c.text;
    $("#chips").appendChild(el);
    return { ...c, el };
  });
  await document.fonts.ready;
  await Promise.all(["500 64px Newsreader", "italic 500 62px Newsreader"].map((f) => document.fonts.load(f)));
  await Promise.all($$("img")
    .filter((img) => !(img.id === "screen" && !img.getAttribute("src")))
    .map(decodeRequiredImage));
}

// ---------- paper world ----------

// How much a later shot has taken over from s (1 = not yet, 0 = fully).
function fadeOutOf(s, t) {
  const next = shots.find((o) => o !== s && o.from > s.from && o.from < s.to && o.enter !== "unfold");
  return next ? 1 - easeInOut(prog(t, next.from, s.to)) : 1;
}

function shotWeight(s, t) {
  if (t < s.from || t >= s.to) return 0;
  const inW = s.from <= 0 ? 1 : easeInOut(prog(t, s.from, s.from + (s.enter === "unfold" ? 0.8 : 0.6)));
  return Math.min(inW, fadeOutOf(s, t));
}

function renderWorld(t) {
  const j = px(ANCHORS.journal);
  for (const s of shots) {
    const w = shotWeight(s, t);
    const p = prog(t, s.from, s.to);
    const [x0, y0, s0, x1, y1, s1] = s.drift;
    const x = lerp(x0, x1, p), y = lerp(y0, y1, p);
    // The camera scales around 30% 50%; reserve enough image on each side of that origin for the pan.
    const cover = 1 + Math.max(x / 30, -x / 70, Math.abs(y) / 50) + 0.002;
    const tf = `translate(${x.toFixed(3)}%, ${y.toFixed(3)}%) scale(${Math.max(lerp(s0, s1, p), cover).toFixed(4)})`;
    // Keep the clock's digits attached to the face throughout the opening camera move.
    if (s.id === "night") css($("#clock-camera"), { transform: tf });
    if (s.enter === "unfold" || s.exit === "fold") {
      // The flashback opens out of the journal and folds back into it.
      const open = s.enter === "unfold" ? easeInOut(prog(t, s.from, s.from + 0.8)) : 1;
      const close = s.exit === "fold" ? 1 - easeInOut(prog(t, s.to - 0.6, s.to)) : 1;
      const r = Math.min(open, close) * 2300;
      const fade = s.exit === "fold" ? 1 : fadeOutOf(s, t);
      css(s.el, { opacity: t >= s.from && t < s.to ? fade.toFixed(4) : "0", transform: tf, clipPath: `circle(${r.toFixed(1)}px at ${j.x}px ${j.y}px)`, zIndex: "2" });
    } else {
      css(s.el, { opacity: w.toFixed(4), transform: tf, zIndex: "1" });
    }
  }
}

const GRADES = { night: [30, 36, 70, 0.3], dusk: [255, 170, 100, 0.1], dawn: [255, 205, 170, 0.08], day: [255, 255, 255, 0] };

function renderLight(t) {
  // Colour wash follows the dominant shot.
  let r = 0, g = 0, b = 0, a = 0, total = 0, nightWeight = 0, dawnWeight = 0;
  for (const s of shots) {
    const w = s.enter === "unfold" ? (t >= s.from && t < s.to ? easeInOut(prog(t, s.from, s.from + 0.8)) * (1 - easeInOut(prog(t, s.to - 0.6, s.to))) : 0) : shotWeight(s, t);
    if (!w) continue;
    const [gr, gg, gb, ga] = GRADES[s.grade];
    r += gr * w; g += gg * w; b += gb * w; a += ga * w; total += w;
    if (s.grade === "night") nightWeight += w;
    if (s.grade === "dawn") dawnWeight += w;
  }
  if (total) css($("#grade"), { background: `rgba(${(r / total) | 0}, ${(g / total) | 0}, ${(b / total) | 0}, ${(a / total).toFixed(3)})` });
  const night = total ? nightWeight / total : 0;
  const moon = px(ANCHORS.moon);
  css($("#moon"), { left: `${moon.x - 260}px`, top: `${moon.y - 260}px`, opacity: (night * (0.75 + Math.sin(t * 1.3) * 0.12)).toFixed(3) });
  const her = px(t < T.clockOut ? ANCHORS.herNight : ANCHORS.herSitting);
  const glowOn = PHONE.glow ? night * prog(t, SCENES[0].from, SCENES[0].from + 0.6) : 0;
  css($("#glow"), { left: `${her.x - 380}px`, top: `${her.y - 380}px`, opacity: (glowOn * (0.85 + Math.sin(t * 2.4) * 0.08)).toFixed(3) });
  css($("#sunrise"), { opacity: (total ? dawnWeight / total : 0).toFixed(3) });
  const clock = px(ANCHORS.clock);
  css($("#clock"), { left: `${clock.x}px`, top: `${clock.y}px`, opacity: t < T.clockOut ? String(1 - prog(t, T.clockOut - 0.5, T.clockOut)) : "0" });
}

// ---------- Sol ----------

function solAt(t) {
  let k = SOL.length - 1;
  while (k > 0 && SOL[k].t > t) k--;
  const a = SOL[k];
  const b = SOL[k + 1];
  // Enter the outdoor walk at its cut; never interpolate from the nightstand through the furniture.
  const cutToWalk = b?.mode === "walk" && a.mode !== "walk";
  const p = b && !cutToWalk ? (a.mode === "walk" ? prog(t, a.t, b.t) : easeInOut(prog(t, b.t - 0.7, b.t))) : 0;
  const pa = px(ANCHORS[a.at]);
  const pb = b ? px(ANCHORS[b.at]) : pa;
  return { mode: a.mode, pose: a.pose, prevPose: SOL[k - 1]?.pose, since: a.t, x: lerp(pa.x, pb.x, p), y: lerp(pa.y, pb.y, p), w: lerp(a.w, b?.w ?? a.w, p) * WIDTH };
}

const speaking = (t) => speech.some((s) => s.who === "Sol" && t >= s.start && t < s.out);

function renderSol(t) {
  const s = solAt(t);
  const hidden = s.mode === "hidden";
  const talk = speaking(t);
  const bob = s.mode === "walk" ? Math.abs(Math.sin(t * 6)) * -10 : Math.sin(t * 2.1) * 4 + (talk ? Math.sin(t * 7.5) * 2 : 0);
  const tilt = s.mode === "walk" ? Math.sin(t * 6) * 2 : Math.sin(t * 1.2) * 1.2 + (talk ? Math.sin(t * 5.3) * 1.4 : 0);
  // Peek: rise out of the open journal, hidden below the page line.
  const rise = s.mode === "peek" ? easeBack(prog(t, s.since, s.since + 1.0)) : 1;
  const sink = (1 - rise) * s.w * 0.9;
  const clip = s.mode === "peek" ? `inset(0 0 ${(sink / s.w * 100).toFixed(2)}% 0)` : "none";
  css($("#sol"), {
    display: hidden ? "none" : "", left: `${(s.x - s.w / 2).toFixed(1)}px`, top: `${(s.y - s.w).toFixed(1)}px`,
    width: `${s.w.toFixed(1)}px`, height: `${s.w.toFixed(1)}px`, clipPath: clip,
    zIndex: t >= T.end ? "3" : "",
    transform: `translateY(${(bob + sink).toFixed(2)}px) rotate(${tilt.toFixed(2)}deg)`,
  });
  css($("#sol-shadow"), { display: hidden ? "none" : "", left: `${(s.x - s.w * 0.4).toFixed(1)}px`, top: `${(s.y - s.w * 0.06).toFixed(1)}px`,
                          width: `${(s.w * 0.8).toFixed(1)}px`, height: `${(s.w * 0.12).toFixed(1)}px`, opacity: String(rise * 0.9) });
  const f = s.pose === s.prevPose ? 1 : prog(t, s.since, s.since + 0.18);
  for (const img of $$("#sol img")) {
    const pose = img.dataset.pose;
    css(img, { opacity: String(pose === s.pose ? f : pose === s.prevPose && f < 1 ? 1 - f : 0) });
  }
  [$("#wave1"), $("#wave2")].forEach((el, i) => {
    const phase = (t * 1.6 + i * 0.5) % 1;
    const size = s.w * (0.18 + phase * 0.16);
    css(el, { left: `${(s.x + s.w * 0.34 - size / 2).toFixed(1)}px`, top: `${(s.y - s.w * 0.86 - size / 2).toFixed(1)}px`,
              width: `${size.toFixed(1)}px`, height: `${size.toFixed(1)}px`, transform: "rotate(45deg)",
              opacity: talk && !hidden ? String((1 - phase) * 0.8) : "0" });
  });
}

// ---------- phone ----------

const segAt = (t) => SEGMENTS.find((s) => t >= s.at && t < s.to);

async function renderPhone(t) {
  const h = PHONE.h * HEIGHT;
  const w = h * 0.4677;
  const inP = easeOut(prog(t, PHONE.in, PHONE.in + 0.7));
  const outP = easeInOut(prog(t, PHONE.out, PHONE.out + 0.7));
  const shown = inP > 0 && outP < 1;
  const zoom = 1 + 0.12 * Math.max(0, ...T.zoomWindows.map((window) =>
    easeInOut(prog(t, window.in, window.in + 0.8)) * (1 - easeInOut(prog(t, window.out, window.out + 0.5)))));
  const away = (1 - inP + outP) * 900;
  css($("#phone"), {
    display: shown ? "" : "none", width: `${w.toFixed(1)}px`, height: `${h.toFixed(1)}px`,
    left: `${(PHONE.x * WIDTH - w / 2).toFixed(1)}px`, top: `${(PHONE.y * HEIGHT - h / 2).toFixed(1)}px`,
    transformOrigin: "50% 66%", transform: `translateX(${away.toFixed(1)}px) perspective(2400px) rotateY(${PHONE.tilt}deg) scale(${zoom.toFixed(4)})`,
  });
  // The exit outlives the footage; hold its final frame even on a direct seek.
  const exiting = t >= PHONE.out;
  const seg = exiting ? SEGMENTS.at(-1) : segAt(t);
  if (!shown || !seg) return;
  const sw = w - 22;
  const sh = sw * (1440 / 662);
  // The journal chip, as fractions of the screen (measured in v1).
  const ringP = prog(t, T.chip, T.chip + 0.35);
  const ringOut = T.zoomWindows.find((window) => window.id === "journal").out;
  css($("#ring"), { left: `${(0.154 * sw).toFixed(1)}px`, top: `${(0.653 * sh).toFixed(1)}px`, width: `${(0.544 * sw).toFixed(1)}px`,
                    height: `${(0.0444 * sh).toFixed(1)}px`, opacity: String(Math.min(1, ringP * 1.4) * (1 - prog(t, ringOut - 0.2, ringOut + 0.2))),
                    transform: `scale(${lerp(1.25, 1, easeBack(ringP)).toFixed(3)})` });
  // The status bar says 2:04, like the story: paint over the recorded 9:41 in the screen's own colour.
  // Recorded glyphs occupy x=116..184, y=54..80 in the 828×1800 extracted frames; include a small margin.
  css($("#statusfix"), { left: `${(108 / 828 * sw).toFixed(1)}px`, top: `${(45 / 1800 * sh).toFixed(1)}px`, width: `${(86 / 828 * sw).toFixed(1)}px`,
                         height: `${(44 / 1800 * sh).toFixed(1)}px`, fontSize: `${(36 / 828 * sw).toFixed(1)}px` });
  const n = frames[seg.id];
  const i = exiting ? n : clamp(Math.floor((t - seg.at) * FPS), 0, n - 1) + 1;
  const src = `build/frames/${seg.id}/${String(i).padStart(5, "0")}.jpg`;
  if (src !== lastSrc) {
    const img = $("#screen");
    img.src = src;
    lastSrc = src;
    await decodeRequiredImage(img);
    probeCtx.drawImage(img, img.naturalWidth * 0.02, img.naturalHeight * 0.008, 4, 4, 0, 0, 8, 8);
    const [r, g, b] = probeCtx.getImageData(4, 4, 1, 1).data;
    css($("#statusfix"), { background: `rgb(${r}, ${g}, ${b})`, color: r + g + b > 384 ? "#000" : "#fff" });
  }
}

// ---------- text ----------

export function subtitleAt(t) {
  return speech.find((s) => t >= s.start - 0.05 && t < s.out + 0.3)?.text ?? "";
}

function renderText(t) {
  for (const c of chips) {
    const on = t >= c.from && t < c.to;
    const p = on ? easeOut(prog(t, c.from, c.from + 0.35)) * (1 - prog(t, c.to - 0.25, c.to)) : 0;
    css(c.el, { left: `${PHONE.x * WIDTH - 470}px`, top: `${HEIGHT * 0.12}px`, opacity: p.toFixed(3), transform: `translateX(${((1 - p) * 30).toFixed(1)}px)` });
  }
  const wm = easeOut(prog(t, T.wordmarkIn, T.wordmarkIn + 0.5)) * (1 - prog(t, T.wordmarkOut - 0.4, T.wordmarkOut));
  css($("#wordmark"), { opacity: wm.toFixed(3) });
  const end = easeOut(prog(t, T.end + 0.2, T.end + 0.9));
  css($("#veil"), { opacity: (end * 0.9).toFixed(3) });
  css($("#endcard"), { opacity: end.toFixed(3), transform: `translateY(${((1 - end) * 24).toFixed(1)}px)` });
  const text = subtitleAt(t);
  const span = $("#subs span");
  if (span.textContent !== text) span.textContent = text;
  css($("#subs"), { opacity: text ? "1" : "0" });
}

async function render(t) {
  renderWorld(t);
  renderLight(t);
  renderSol(t);
  renderText(t);
  await renderPhone(t);
}

window.__ready = build().then(async () => {
  window.renderAt = async (t) => {
    await render(t);
    return true;
  };
  window.subtitleAt = subtitleAt;
  const params = new URLSearchParams(location.search);
  await render(Number(params.get("t") || 0));
  return true;
});
