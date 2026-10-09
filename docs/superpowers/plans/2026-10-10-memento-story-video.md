# Memento Story Video (v2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a 60 s and a 30 s landscape (1920×1080) story video of Memento: a paper-cut night-to-morning story with Sol as a character, the real app on a phone, ElevenLabs voices and score.

**Architecture:**
- Each video is an ad folder under `marketing/`, rendered by the existing kit: HTML frames in headless Chromium, synthesized SFX, then ElevenLabs voice and a mix.
- New shared kit pieces: a timeline checker, a media verifier, art and footage helpers, per-voice settings, and speech timings for subtitles.
- The story ad (`memento-story`) owns the scene; the 30 s ad (`memento-story-30`) reuses that scene with its own timeline.

**Tech Stack:** Node 24 (ESM, `node:test`), Playwright Chromium, sharp, ffmpeg/ffprobe, ElevenLabs TTS and Music APIs, Codex image generation via the Orca orchestration skill.

**Spec:** `docs/superpowers/specs/2026-10-10-memento-story-video-design.md`

## Global Constraints

- **Output:** 1920×1080, 30 fps, H.264 (kit settings), AAC 48 kHz stereo.
- **Durations:** 60.0 s (master) and 30.0 s (cut-down), within ±0.05 s.
- **Loudness:** integrated −16 LUFS (±1 LU); true peak ≤ −1.0 dBTP.
- **Voices:** ElevenLabs model `eleven_multilingual_v2`.
  - Sol: Grandfather Joe `0lp4RIz96WD1RUtvEu3Q`.
  - Her: Jessica `cgSgspJ2msm6clMCkdW9`.
  - Target tempo 1.0x; the kit refuses above 1.25x, and this plan treats anything above 1.10x as a script problem to fix.
- **Art:**
  - Follows `design-assets/STYLE.md`, with the spec's exceptions for this set only: faceless paper figures, full scenes, and a night slate-indigo palette.
  - No text, numbers or UI in any image; the clock digits and "2:04" are HTML.
  - Codex image generation is run only through the orchestration skill (`~/.claude/skills/orchestration`), never with raw `codex exec`.
- **Footage:**
  - Real app recordings with live on-device AI only.
  - Spoken input simulated (simulator).
  - No Paint this day and no airplane mode.
- **Repo hygiene:**
  - Recordings, renders, `build/`, `out/` and `final/` stay git-ignored; source, briefs and scripts are committed.
  - Never print or commit API keys. The ElevenLabs key lives in the session scratchpad file `.eleven` and is passed only as `ELEVENLABS_API_KEY`.
- **Commits:**
  - Gate on the test command's own exit status (`cmd && git commit`), never on a downstream `grep`/`tail`.
  - End each commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Plan deviation from the spec (flagged for review):**
  - The spec says re-record the writing and Sol scenes with the status bar at 2:04.
  - This plan keeps the approved takes (`Scene2Write`, `Scene4SolC`) and draws "2:04" over the status bar in the scene, sampling the app's background colour per frame.
  - Re-recording (Task 5, Step 7) is the fallback if the overlay shows.

## Review Focus

1. **Sol's voice doesn't match the screen** (tag line names tags the footage doesn't show; memory line date ≠ the chip's date) → Task 4 pins the tag and date constants to what Task 5's stills show.
2. **Sol's cut-out halos on dark night scenes** (cream fringe from the paper flood fill) → Task 1 adds `defringe` and Task 5 inspects a 3× crop at night.
3. **Blank or black frames at a scene or segment boundary** (frame index past the extracted frames; gap between shots) → Task 1's `checkTimeline` rejects gaps; `verify.mjs` runs `blackdetect`; Task 6 verifies the master.
4. **Subtitles out of sync with speech** (slot times instead of real speech times) → Task 2 writes `vo-timing.json`; Task 5 asserts `subtitleAt(mid)` for every line.
5. **Music masking the voice, or clipping** → Task 2 lowers the limiter; `verify.mjs` checks LUFS and true peak; Task 6 includes a listening pass.

---

### Task 1: Kit checks and shared art/footage helpers

**Files:**
- Create: `marketing/kit/check.mjs`, `marketing/kit/check.test.mjs`, `marketing/kit/verify.mjs`, `marketing/kit/art.mjs`, `marketing/kit/footage.mjs`
- Modify: `marketing/memento-demo/prep.mjs` (use the helpers), `marketing/package.json` (test script)

**Interfaces:**
- Produces:
  - `checkTimeline(tl) → string[]` (problems; empty when valid)
  - `cutout(src, dst, { defringe = false })`
  - `paper(dst, width, height)`
  - `extractFrames({ build, footageDir, segments, fps, width = 828 }) → Promise<Record<string, number>>` (frame counts per segment id; also writes `build/frames.json`)
  - CLI `node kit/verify.mjs <mp4> --duration <s> [--lufs -16] [--size 1920x1080]` (exit 0 when all checks pass)

- [ ] **Step 1: Write the failing tests** — `marketing/kit/check.test.mjs`

```js
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import test from "node:test";
import { checkTimeline } from "./check.mjs";

const base = {
  DURATION: 10,
  VOICES: { Sol: { id: "a" }, Her: { id: "b" } },
  SCENES: [{ id: "night", from: 0, to: 10 }],
  SEGMENTS: [{ id: "x", at: 2, to: 4, src: 0, rate: 1 }, { id: "y", at: 4, to: 6, src: 0, rate: 1 }],
  VO: [{ from: 0.5, to: 3, who: "Her" }, { from: 3.2, to: 6, who: "Sol" }],
  SFX: [{ t: 1 }],
};

test("a clean timeline passes", () => assert.deepEqual(checkTimeline(base), []));
test("a gap between scenes is caught", () => {
  const tl = { ...base, SCENES: [{ id: "a", from: 0, to: 4 }, { id: "b", from: 4.5, to: 10 }] };
  assert.match(checkTimeline(tl).join("\n"), /gap/);
});
test("scenes must cover the whole duration", () => {
  assert.match(checkTimeline({ ...base, SCENES: [{ id: "a", from: 0, to: 9 }] }).join("\n"), /end/);
});
test("a gap between footage segments is caught", () => {
  const tl = { ...base, SEGMENTS: [{ id: "x", at: 2, to: 4, src: 0, rate: 1 }, { id: "y", at: 4.2, to: 6, src: 0, rate: 1 }] };
  assert.match(checkTimeline(tl).join("\n"), /segments x\/y/);
});
test("overlapping voice lines and unknown speakers are caught", () => {
  const tl = { ...base, VO: [{ from: 0.5, to: 4, who: "Her" }, { from: 3, to: 6, who: "Narrator" }] };
  const out = checkTimeline(tl).join("\n");
  assert.match(out, /overlap/);
  assert.match(out, /Narrator/);
});
test("cues outside the video are caught", () => {
  assert.match(checkTimeline({ ...base, SFX: [{ t: 12 }] }).join("\n"), /SFX/);
});
for (const ad of ["memento-demo", "memento-story", "memento-story-30"]) {
  const file = new URL(`../${ad}/timeline.mjs`, import.meta.url);
  test(`${ad} timeline is valid`, { skip: !existsSync(file) }, async () => {
    assert.deepEqual(checkTimeline(await import(file.href)), []);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd marketing && node --test kit/`
Expected: FAIL with `Cannot find module '.../kit/check.mjs'`.

- [ ] **Step 3: Implement `marketing/kit/check.mjs`**

```js
// Invariants every ad timeline must hold, checked by check.test.mjs and before a render:
// scenes cover the whole video without gaps, footage segments are contiguous, voice lines don't overlap and
// have known speakers, and every cue lies inside the video.

const EPS = 0.001;

export function checkTimeline(tl) {
  const problems = [];
  const D = tl.DURATION;
  const inside = (t) => t >= -EPS && t <= D + EPS;

  const scenes = [...(tl.SCENES ?? [])].sort((a, b) => a.from - b.from);
  if (scenes.length) {
    if (scenes[0].from > EPS) problems.push(`SCENES start at ${scenes[0].from}s, not 0`);
    const end = Math.max(...scenes.map((s) => s.to));
    if (end < D - EPS) problems.push(`SCENES end at ${end}s, before the video's end (${D}s)`);
    scenes.forEach((s, i) => {
      if (!(s.to > s.from)) problems.push(`scene ${s.id}: to must be after from`);
      const next = scenes[i + 1];
      const covered = Math.max(...scenes.slice(0, i + 1).map((x) => x.to));
      if (next && next.from > covered + EPS) problems.push(`gap between scenes before ${next.id} (${covered}s to ${next.from}s)`);
    });
  }

  const segs = [...(tl.SEGMENTS ?? [])].sort((a, b) => a.at - b.at);
  segs.forEach((s, i) => {
    if (!(s.to > s.at)) problems.push(`segment ${s.id}: to must be after at`);
    if (!inside(s.at) || !inside(s.to)) problems.push(`segment ${s.id}: outside 0 to ${D}s`);
    if (!(s.rate > 0)) problems.push(`segment ${s.id}: rate must be positive`);
    const next = segs[i + 1];
    if (next && Math.abs(next.at - s.to) > EPS) problems.push(`segments ${s.id}/${next.id} are not contiguous (${s.to}s vs ${next.at}s)`);
  });

  const vo = tl.VO ?? [];
  vo.forEach((v, i) => {
    if (!tl.VOICES?.[v.who]) problems.push(`VO line ${i + 1}: unknown speaker ${v.who}`);
    if (!(v.to > v.from)) problems.push(`VO line ${i + 1}: to must be after from`);
    if (!inside(v.from) || !inside(v.to)) problems.push(`VO line ${i + 1}: outside 0 to ${D}s`);
    const next = vo[i + 1];
    if (next && next.from < v.to - EPS) problems.push(`VO lines ${i + 1} and ${i + 2} overlap`);
  });

  for (const [name, list, key] of [["SFX", tl.SFX, "t"], ["CHIPS", tl.CHIPS, "from"], ["CAPTIONS", tl.CAPTIONS, "from"]]) {
    for (const cue of list ?? []) if (!inside(cue[key])) problems.push(`${name} cue at ${cue[key]}s is outside the video`);
  }
  return problems;
}
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `cd marketing && node --test kit/`
Expected: PASS. The `memento-story` tests show as skipped until Task 4.

- [ ] **Step 5: Render a baseline still of v1, before refactoring**

```bash
cd marketing && node kit/render.mjs memento-demo --still 34.9 && cp memento-demo/build/stills/t-34.90.png "$SCRATCH/baseline-t-34.90.png"
```

- [ ] **Step 6: Extract the art and footage helpers.** Create `marketing/kit/art.mjs` by moving `cutout` out of `marketing/memento-demo/prep.mjs` and adding `defringe` and `paper`:

```js
// Art helpers shared by ads: cut a paper-backed illustration out of its paper, and a paper texture plate.
import path from "node:path";
import sharp from "sharp";
import { ROOT } from "./render.mjs";

// Flood-fills the paper from the edges (so cream inside the subject stays), feathering the boundary.
// `defringe` drops the faint outer band so a light halo doesn't show on dark scenes.
export async function cutout(src, dst, { defringe = false } = {}) {
  const { data, info } = await sharp(src).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const px = (x, y) => (y * w + x) * 4;
  const border = [];
  for (let x = 0; x < w; x += 4) border.push(px(x, 0), px(x, h - 1));
  for (let y = 0; y < h; y += 4) border.push(px(0, y), px(w - 1, y));
  const med = (k) => border.map((i) => data[i + k]).sort((a, b) => a - b)[border.length >> 1];
  const bg = [med(0), med(1), med(2)];
  const dist = (i) => Math.hypot(data[i] - bg[0], data[i + 1] - bg[1], data[i + 2] - bg[2]);
  const SOFT = 34;
  const HARD = 14;
  const seen = new Uint8Array(w * h);
  const queue = [];
  for (let x = 0; x < w; x++) queue.push(x, (h - 1) * w + x);
  for (let y = 0; y < h; y++) queue.push(y * w, y * w + w - 1);
  while (queue.length) {
    const p = queue.pop();
    if (seen[p]) continue;
    const d = dist(p * 4);
    if (d >= SOFT) continue;
    seen[p] = 1;
    let a = d <= HARD ? 0 : Math.round(((d - HARD) / (SOFT - HARD)) * 255);
    if (defringe && a < 170) a = 0;
    data[p * 4 + 3] = a;
    const x = p % w;
    const y = (p / w) | 0;
    if (x > 0) queue.push(p - 1);
    if (x < w - 1) queue.push(p + 1);
    if (y > 0) queue.push(p - w);
    if (y < h - 1) queue.push(p + w);
  }
  await sharp(data, { raw: { width: w, height: h, channels: 4 } }).trim({ threshold: 1 }).png().toFile(dst);
}

export async function paper(dst, width, height) {
  await sharp(path.join(ROOT, "design-assets/generated/paper-grain.png")).resize(width, height, { fit: "cover" }).jpeg({ quality: 88 }).toFile(dst);
}
```

Create `marketing/kit/footage.mjs`:

```js
// Extracts each footage segment of a timeline to JPEG frames (cached; rebuilt only when missing).
import { mkdir, readdir, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { run } from "./render.mjs";

const exists = (f) => stat(f).then(() => true, () => false);

export async function extractFrames({ build, footageDir, segments, fps, width = 828 }) {
  const counts = {};
  for (const seg of segments) {
    const dir = path.join(build, "frames", seg.id);
    const n = Math.round((seg.to - seg.at) * fps);
    counts[seg.id] = n;
    if ((await exists(dir)) && (await readdir(dir)).length >= n) continue;
    await mkdir(dir, { recursive: true });
    const srcDur = ((seg.to - seg.at) * seg.rate + 0.5).toFixed(3);
    await run("ffmpeg", [
      "-y", "-loglevel", "error", "-ss", String(seg.src), "-t", srcDur, "-i", path.join(footageDir, `${seg.clip}.mov`),
      "-vf", `setpts=(PTS-STARTPTS)/${seg.rate},fps=${fps},scale=${width}:-2:flags=lanczos`,
      "-q:v", "2", "-frames:v", String(n), path.join(dir, "%05d.jpg"),
    ]).done;
    const got = (await readdir(dir)).length;
    if (got < n) throw new Error(`Segment ${seg.id}: only ${got} of ${n} frames (is ${seg.clip}.mov long enough after ${seg.src}s?)`);
  }
  await writeFile(path.join(build, "frames.json"), JSON.stringify(counts, null, 2));
  return counts;
}
```

Replace the body of `marketing/memento-demo/prep.mjs` with:

```js
// Builds what the scene needs, before rendering: Sol's poses cut out of their paper (1024 px originals), the paper
// texture, and the footage frames for each segment in timeline.mjs. Cached in build/.
import { mkdir, stat } from "node:fs/promises";
import path from "node:path";
import { cutout, paper } from "../kit/art.mjs";
import { extractFrames } from "../kit/footage.mjs";
import { ROOT } from "../kit/render.mjs";
import { FPS, SEGMENTS } from "./timeline.mjs";

const exists = (f) => stat(f).then(() => true, () => false);
export const POSES = ["hello", "listening", "thinking", "mark", "reflect", "resting"];

export async function prepArt(ad, { defringe = false } = {}) {
  const dir = path.join(ad.build, "art");
  await mkdir(dir, { recursive: true });
  for (const pose of POSES) {
    const dst = path.join(dir, `sol-${pose}.png`);
    if (!(await exists(dst))) await cutout(path.join(ROOT, "design-assets/generated/tortoise", `sol-${pose}.png`), dst, { defringe });
  }
  const grain = path.join(dir, "paper.jpg");
  if (!(await exists(grain))) await paper(grain, ad.tl.WIDTH, ad.tl.HEIGHT);
}

export default async function prep(ad) {
  await mkdir(ad.build, { recursive: true });
  await prepArt(ad);
  await extractFrames({ build: ad.build, footageDir: ad.footage ?? path.join(ad.dir, "footage"), segments: SEGMENTS, fps: FPS });
}
```

- [ ] **Step 7: Create `marketing/kit/verify.mjs`**

```js
// Checks a finished video: size, duration, loudness, true peak and no black frames.
//   node kit/verify.mjs <file.mp4> --duration 60 [--lufs -16] [--size 1920x1080]
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const exec = promisify(execFile);
const args = process.argv.slice(2);
const file = args[0];
const opt = (k, d) => (args.includes(`--${k}`) ? args[args.indexOf(`--${k}`) + 1] : d);
const duration = Number(opt("duration"));
const lufs = Number(opt("lufs", "-16"));
const size = opt("size", "1920x1080");

const fails = [];
const { stdout: probe } = await exec("ffprobe", ["-v", "error", "-show_entries", "stream=codec_type,width,height", "-show_entries", "format=duration", "-of", "json", file]);
const info = JSON.parse(probe);
const v = info.streams.find((s) => s.codec_type === "video");
if (`${v.width}x${v.height}` !== size) fails.push(`size ${v.width}x${v.height}, expected ${size}`);
const d = Number(info.format.duration);
if (Math.abs(d - duration) > 0.05) fails.push(`duration ${d.toFixed(2)}s, expected ${duration}s`);
if (!info.streams.some((s) => s.codec_type === "audio")) fails.push("no audio stream");

const { stderr: loud } = await exec("ffmpeg", ["-hide_banner", "-nostats", "-i", file, "-af", "ebur128=peak=true", "-f", "null", "-"], { maxBuffer: 64 << 20 });
const summary = loud.slice(loud.lastIndexOf("Summary:"));
const I = Number(summary.match(/I:\s+(-?[\d.]+) LUFS/)?.[1]);
const peak = Number(summary.match(/Peak:\s+(-?[\d.]+) dBFS/)?.[1]);
if (!(Math.abs(I - lufs) <= 1)) fails.push(`loudness ${I} LUFS, expected ${lufs} ±1`);
if (!(peak <= -1.0)) fails.push(`true peak ${peak} dBTP, expected ≤ -1.0`);

const { stderr: black } = await exec("ffmpeg", ["-hide_banner", "-nostats", "-i", file, "-vf", "blackdetect=d=0.1:pix_th=0.02", "-an", "-f", "null", "-"], { maxBuffer: 64 << 20 });
const spans = [...black.matchAll(/black_start:([\d.]+) black_end:([\d.]+)/g)].map((m) => `${m[1]}–${m[2]}s`);
if (spans.length) fails.push(`black frames at ${spans.join(", ")}`);

console.log(`${file}\n  ${v.width}x${v.height} · ${d.toFixed(2)}s · ${I} LUFS · peak ${peak} dBTP${spans.length ? "" : " · no black frames"}`);
if (fails.length) {
  console.error(fails.map((f) => `  FAIL ${f}`).join("\n"));
  process.exit(1);
}
console.log("  OK");
```

Add to `marketing/package.json`: `"scripts": { "test": "node --test kit/" }`.

- [ ] **Step 8: Prove the refactor kept v1 identical, and the verifier works**

```bash
cd marketing && npm test && node kit/render.mjs memento-demo --still 34.9 \
  && magick compare -metric AE memento-demo/build/stills/t-34.90.png "$SCRATCH/baseline-t-34.90.png" null: ; echo \
  && node kit/verify.mjs "final/Memento demo - landscape 16x9.mp4" --duration 58 || echo "verify exit $?"
```
Expected:
- the tests pass
- `compare` prints `0` (identical pixels)
- the verifier prints size, duration and loudness, then **FAIL true peak** (v1 used limiter 0.95; Task 2 lowers it). That failure proves the check works.

- [ ] **Step 9: Commit**

```bash
cd marketing && npm test && cd .. && git add marketing/kit marketing/memento-demo/prep.mjs marketing/package.json \
  && git commit -m "Kit: timeline checks, media verifier, shared art and footage helpers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Kit voice — per-voice settings, real speech timings, safer limiter

**Files:**
- Modify: `marketing/kit/voice.mjs`
- Test: `marketing/kit/voice.test.mjs`

**Interfaces:**
- Consumes: `VOICES[who].settings` (optional per voice), else `VOICES.settings`.
- Produces:
  - `node kit/voice.mjs <ad> --clips-only` generates or reuses clips without a render and writes `<ad>/build/vo-timing.json`: `[{ index, who, text, start, out }]`, where `start` is when speech begins and `out` when it ends, in seconds.
  - The final mix is limited at 0.85 (about −1.4 dBFS).

- [ ] **Step 1: Write the failing test** — `marketing/kit/voice.test.mjs`

```js
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import test from "node:test";

// memento-demo's clips are cached in build/vo, so this spends no ElevenLabs characters.
test("--clips-only writes speech timings without a render", () => {
  execFileSync("node", ["kit/voice.mjs", "memento-demo", "--clips-only"], { env: { ...process.env, ELEVENLABS_API_KEY: process.env.ELEVENLABS_API_KEY ?? "cached-only" } });
  const timing = JSON.parse(readFileSync("memento-demo/build/vo-timing.json", "utf8"));
  assert.equal(timing.length, 9);
  for (const line of timing) {
    assert.ok(line.out > line.start, `line ${line.index} ends after it starts`);
    assert.equal(typeof line.text, "string");
  }
  assert.equal(timing[0].who, "Sol");
});
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd marketing && node --test kit/voice.test.mjs`
Expected: FAIL. The current CLI ignores `--clips-only`, demands a render, and writes no `vo-timing.json`.

- [ ] **Step 3: Implement.** In `marketing/kit/voice.mjs`:
  - In `synthesize`, use `voice_settings: voice.settings ?? VOICES.settings`.
  - In `clipFor`'s hash, use `[VOICES.model, VOICES[line.who].settings ?? VOICES.settings, VOICES[line.who].id, line.say]`.
  - At the end of `ttsClips`, before `return clips`, add:

```js
  await writeFile(path.join(ad.build, "vo-timing.json"), JSON.stringify(
    clips.map((c, i) => ({ index: i + 1, who: c.line.who, text: c.line.text, start: Number(c.start.toFixed(3)), out: Number(c.out.toFixed(3)) })), null, 2));
```

  - In `main`, before the `requireRender` loop:

```js
  if (flag("clips-only") !== undefined) {
    for (const cut of ad.cuts) await ttsClips(ad, cut);
    console.log(`[${ad.folder}] speech timings → build/vo-timing.json`);
    return;
  }
```

  - In `mixCut`, change both `alimiter=limit=0.95` to `alimiter=limit=0.85`.

- [ ] **Step 4: Run the tests and see them pass**

Run: `cd marketing && ELEVENLABS_API_KEY="$(cat "$SCRATCH/.eleven")" npm test` (`$SCRATCH` is the session scratchpad).
Expected: PASS, with `characters spent: 0` in the output.

- [ ] **Step 5: Commit**

```bash
cd marketing && npm test && cd .. && git add marketing/kit/voice.mjs marketing/kit/voice.test.mjs \
  && git commit -m "Kit voice: per-voice settings, speech timings for subtitles, -1 dBTP limiter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Paper-cut story art (Codex via Orca)

**Files:**
- Create: `design-assets/briefs/wave5-story.md`
- Modify: `design-assets/RUN.md` (verdicts)
- Output (git-ignored): `design-assets/generated/story/*.png`, accepted copies in `design-assets/accepted/story-*.png`

**Interfaces:**
- Produces five accepted images, `story-night.png`, `story-writing.png`, `story-dusk.png`, `story-dawn.png` and `story-morning.png`, each ≥ 1536 px wide. Composition anchors match the brief within ±4% of frame width and height; Task 4 uses those anchors.

- [ ] **Step 1: Write the brief** — `design-assets/briefs/wave5-story.md`. It must contain exactly the following:

```markdown
# Wave 5: the story video's paper world (5 images)

Style: follow design-assets/STYLE.md (layered cut paper, visible fibre, soft contact shadows, matte light),
with these exceptions for this wave only:
- Faceless paper-cut people are allowed: simple head shapes, no eyes/nose/mouth, simplified mitten hands.
- Full scenes edge to edge (no flat cream background).
- Night images may use deep slate-indigo paper (#2E3550 to #3E4766) and a pale moon (#F2EEE2).
Everything else in STYLE.md still holds: palette, no text, no numbers, no letters, no UI, no logos, no photorealism.

Format: landscape 1536×1024. The video crops to 16:9 (1536×864, centred), so keep everything important between
y = 80 and y = 944. Keep the RIGHT THIRD (x > 1024) quiet: plain wall / sky / meadow only. A phone is placed there.

The same bedroom appears in images 1, 2 and 4: same camera, same furniture in the same places.

1. story-night: night bedroom. A woman (late 20s, faceless paper figure, dark hair) lies awake in bed, head on the
   pillow at about (430, 590), turned toward the ceiling. A small nightstand at the left (x 110–300, y 620–880) holds a
   closed cloth journal at about (230, 640) and a small round paper clock with a BLANK face at about (290, 605). A window
   at upper left shows a pale crescent moon at about (460, 180). A soft warm glow from a phone lying on the duvet.
2. story-writing: the same room and camera. She sits up against the headboard, head at about (480, 430), holding a
   glowing phone. The journal lies OPEN on the nightstand at about (230, 650), pages up, with empty space above it.
3. story-dusk: a dusk walk. Two faceless women walk side by side along a paper path under autumn trees, at about
   x 380–620, y 520–900, facing right. Low sunset band in terracotta and sand, long soft shadows.
4. story-dawn: the same bedroom and camera as 1–2 at sunrise. The bed is made and empty; warm peach light pours through
   the window; the journal is closed on the nightstand.
5. story-morning: a morning path across the lower third from left to right. The same two women walk away to the
   right, at about x 640–820, y 470–880. Open path behind them at the left (x 120–420, y 820–880) with nothing on it.
   Fresh sage meadow, small paper wildflowers, soft morning sun.
```

- [ ] **Step 2: Dispatch generation through the orchestration skill.** Invoke the `orchestration` skill and follow its dispatch procedure:
  - one Codex image worker for the brief file
  - output directory `design-assets/generated/story/`
  - two variants per image
  - record the run and task ids in `design-assets/RUN.md`, as with earlier waves

  Wait for completion with the skill's check command. Do not run `codex exec` directly.

- [ ] **Step 3: Review every image against its brief.** Make a contact sheet:

```bash
cd design-assets/generated/story && magick story-*.png -resize 640x +append -crop 3200x427 +repage /private/tmp/claude-501/-Users-kands-orca-workspaces-memento-app/171e0a96-d442-450d-b371-a43ae3a8a435/scratchpad/story-sheet.png
```

Open it and check each image. If any check fails, reply through the orchestration skill asking for a regeneration of that image, quoting the failed check. A check passes only if all of these hold:
  1. no text, numbers or faces
  2. palette per the brief
  3. right third quiet
  4. anchors within ±60 px of the brief's coordinates
  5. bedroom images 1, 2 and 4 show the same room
  6. style matches the app's paper art

- [ ] **Step 4: Accept.** Copy the chosen variants to `design-assets/accepted/story-<name>.png`, and write each verdict (accepted, or regenerated and why) in `design-assets/RUN.md`.

- [ ] **Step 5: Commit the brief and verdicts** (the images stay git-ignored)

```bash
git add design-assets/briefs/wave5-story.md design-assets/RUN.md && git commit -m "Art wave 5: paper-cut story scenes (brief and review verdicts)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Story timeline (60 s)

**Files:**
- Create: `marketing/memento-story/timeline.mjs`
- Test: `marketing/kit/check.test.mjs` (its `memento-story` case now runs)

**Interfaces:**
- Consumes: `checkTimeline` (Task 1); the anchors from Task 3's brief.
- Produces the exports used by the Task 5 scene:
  - `NAME`, `FPS`, `DURATION`, `WIDTH`, `HEIGHT`, `COVER_T`, `DOC`
  - `SCENES`, `SEGMENTS`, `PHONE`, `ANCHORS`, `SOL`, `CHIPS`, `T`, `SFX`, `VOICES`, `VO`
  - `TAGS_ON_SCREEN`, `MEMORY_DATE`

  Units: seconds; positions as fractions of the 1920×1080 frame.

- [ ] **Step 1: See the test case still skipped**

Run: `cd marketing && npm test`
Expected: `memento-story timeline is valid` reported as skipped.

- [ ] **Step 2: Write `marketing/memento-story/timeline.mjs`**

```js
// The Memento story (v2), 60 s, 1920×1080: every shot, footage cut, Sol move, cue and line is timed here.
// Footage: the approved simulator takes (Scene2Write, Scene4SolC) with live on-device AI; spoken input simulated.

export const NAME = "memento-story";
export const FPS = 30;
export const DURATION = 60;
export const WIDTH = 1920;
export const HEIGHT = 1080;
export const COVER_T = 26.9;

export const DOC = {
  title: "Memento story",
  notes: ["Her is the writer's inner voice; Sol is the paper tortoise. Footage is the real app with live on-device AI."],
  rules: [
    "Only show what the app does live; voice lines quote only what is on screen.",
    "No Paint this day, no airplane mode, no claims about other phones.",
    "No em-dashes in visible copy.",
  ],
};

// What the footage shows (checked against stills in Task 5). Sol's lines must agree with these.
export const TAGS_ON_SCREEN = ["Drained", "Walking helped", "Work"];
export const MEMORY_DATE = "Sep 13";

// Paper-world anchors, as fractions of the frame (from design-assets/briefs/wave5-story.md, 1536×864 crop).
export const ANCHORS = {
  journal: { x: 0.150, y: 0.655 },
  clock: { x: 0.189, y: 0.607 },
  moon: { x: 0.300, y: 0.115 },
  herNight: { x: 0.280, y: 0.590 },
  herSitting: { x: 0.312, y: 0.405 },
  besideHer: { x: 0.235, y: 0.700 },
  flashCorner: { x: 0.110, y: 0.930 },
  pathStart: { x: 0.080, y: 0.880 },
  pathEnd: { x: 0.260, y: 0.880 },
  endSol: { x: 0.300, y: 0.860 },
};

// Paper-world shots. `enter`/`exit`: "fade" or the flashback's "unfold"/"fold" (from the open journal).
export const SCENES = [
  { id: "night", img: "story-night", from: 0, to: 5.6, drift: [0, 0, 1.0, -1, 0, 1.04], grade: "night" },
  { id: "writing", img: "story-writing", from: 5.0, to: 22.8, drift: [-1, 0, 1.04, 0, -1, 1.07], grade: "night", enter: "fade" },
  { id: "dusk", img: "story-dusk", from: 22.0, to: 34.6, drift: [1, 0, 1.06, -1, 0, 1.0], grade: "dusk", enter: "unfold", exit: "fold" },
  { id: "writing2", img: "story-writing", from: 34.0, to: 43.6, drift: [0, -1, 1.07, 0, 0, 1.05], grade: "night" },
  { id: "dawn", img: "story-dawn", from: 42.4, to: 47.8, drift: [0, 0, 1.05, 1, 0, 1.02], grade: "dawn", enter: "fade" },
  { id: "morning", img: "story-morning", from: 47.0, to: 60, drift: [-2, 0, 1.0, 1, 0, 1.06], grade: "day", enter: "fade" },
];

// The phone (right third). Footage segments must be contiguous from PHONE.in to PHONE.out.
export const PHONE = { in: 5.2, out: 42.6, x: 0.785, y: 0.5, h: 0.89, tilt: -7, glow: true };

// Measured by eye on the approved takes (see Task 5, Step 2, to re-measure after any re-record).
export const SEGMENTS = [
  { id: "writeOpen", clip: "Scene2Write", at: 5.2, to: 6.8, src: 12.6, rate: 2.0 },
  { id: "typing", clip: "Scene2Write", at: 6.8, to: 10.6, src: 16.4, rate: 8.5 },
  { id: "finding", clip: "Scene2Write", at: 10.6, to: 11.8, src: 50.2, rate: 1 },
  { id: "tags", clip: "Scene2Write", at: 11.8, to: 16.2, src: 51.5, rate: 1 },
  { id: "solOpen", clip: "Scene4SolC", at: 16.2, to: 17.8, src: 20.2, rate: 1 },
  { id: "solListen", clip: "Scene4SolC", at: 17.8, to: 21.6, src: 23.6, rate: 1 },
  { id: "solThink", clip: "Scene4SolC", at: 21.6, to: 22.6, src: 28.2, rate: 1 },
  { id: "solReply", clip: "Scene4SolC", at: 22.6, to: 29.0, src: 31.3, rate: 1 },
  { id: "solHold", clip: "Scene4SolC", at: 29.0, to: 33.6, src: 37.3, rate: 0.45 },
  { id: "solSecond", clip: "Scene4SolC", at: 33.6, to: 37.4, src: 39.4, rate: 1 },
  { id: "solReply2", clip: "Scene4SolC", at: 37.4, to: 40.0, src: 53.5, rate: 1 },
  { id: "reflection", clip: "Scene4SolC", at: 40.0, to: 42.6, src: 65.4, rate: 1 },
];

// Sol in the world: keyframes, interpolated between `t`s. `mode`: "hidden", "peek" (rising from the journal), "idle",
// "walk". Positions are his feet (bottom centre).
export const SOL = [
  { t: 0, mode: "hidden", pose: "listening", at: "journal", w: 0.10 },
  { t: 9.2, mode: "peek", pose: "listening", at: "journal", w: 0.10 },
  { t: 10.4, mode: "idle", pose: "mark", at: "journal", w: 0.10 },
  { t: 16.2, mode: "idle", pose: "listening", at: "besideHer", w: 0.115 },
  { t: 21.6, mode: "idle", pose: "thinking", at: "besideHer", w: 0.115 },
  { t: 22.4, mode: "idle", pose: "reflect", at: "flashCorner", w: 0.13 },
  { t: 34.4, mode: "idle", pose: "listening", at: "besideHer", w: 0.115 },
  { t: 37.6, mode: "idle", pose: "mark", at: "besideHer", w: 0.115 },
  { t: 42.4, mode: "idle", pose: "resting", at: "journal", w: 0.10 },
  { t: 47.4, mode: "walk", pose: "mark", at: "pathStart", w: 0.095 },
  { t: 55.0, mode: "walk", pose: "mark", at: "pathEnd", w: 0.095 },
  { t: 55.4, mode: "idle", pose: "hello", at: "endSol", w: 0.21 },
];

// Small feature chips beside the phone.
export const CHIPS = [
  { from: 11.8, to: 16.2, text: "Tags from your words · on device" },
  { from: 22.6, to: 29.0, text: "Sol remembers" },
  { from: 40.0, to: 42.6, text: "A reflection in your words" },
];

export const T = { clockOut: 5.6, wordmarkIn: 16.4, wordmarkOut: 21.0, chip: 26.8, zoomIn: 25.9, zoomOut: 28.8, end: 55.2 };

// kind: tap | pop | bloop | receive | whoosh | buzz | ding | sparkle | tick | check
export const SFX = [
  ...[0.3, 1.3, 2.3, 3.3, 4.3].map((t) => ({ t, kind: "tick", gain: 0.22 })),
  { t: 5.35, kind: "tap", gain: 0.4 },
  { t: 9.2, kind: "whoosh", gain: 0.22, dur: 0.35 },
  { t: 11.85, kind: "ding", gain: 0.28 },
  { t: 17.85, kind: "tap", gain: 0.4 },
  { t: 22.0, kind: "whoosh", gain: 0.3, dur: 0.7 },
  { t: T.chip, kind: "sparkle", gain: 0.35 },
  { t: 33.65, kind: "tap", gain: 0.4 },
  { t: 34.0, kind: "whoosh", gain: 0.26, dur: 0.6 },
  { t: 42.6, kind: "whoosh", gain: 0.3, dur: 0.5 },
  { t: T.end + 0.2, kind: "ding", gain: 0.4 },
];

export const VOICES = {
  model: "eleven_multilingual_v2",
  settings: { stability: 0.5, similarity_boost: 0.8, style: 0.3, use_speaker_boost: true, speed: 1.0 },
  Sol: { id: "0lp4RIz96WD1RUtvEu3Q", name: "Grandfather Joe, Gentle, Warm" },
  Her: { id: "cgSgspJ2msm6clMCkdW9", name: "Jessica, Playful, Bright, Warm",
         settings: { stability: 0.35, similarity_boost: 0.8, style: 0.45, use_speaker_boost: true, speed: 0.95 } },
};

export const VO = [
  { from: 0.4, to: 5.0, who: "Her", note: "2 a.m., tired, quiet, to herself",
    text: "It's 2 a.m. Work's been a lot, and I can't switch off.",
    say: "It's two a.m. Work's been a lot, and I can't switch off." },
  { from: 11.9, to: 17.9, who: "Sol", note: "gentle, noticing",
    text: "Drained. Work. And a walk with Priya that helped. Shall we keep those?",
    say: "Drained. Work. And a walk with Priya that helped. Shall we keep those?" },
  { from: 18.5, to: 22.4, who: "Her", note: "honest, to a friend",
    text: "Work stress is back this week. What helped me last time?",
    say: "Work stress is back this week. What helped me last time?" },
  { from: 22.7, to: 33.9, who: "Sol", note: "remembering fondly",
    text: "On Sep 13, you wrote: “Long walk with Priya after work.”",
    say: "On September thirteenth, you wrote: long walk with Priya, after work." },
  { from: 34.1, to: 37.5, who: "Her", note: "a small smile",
    text: "Maybe I'll text Priya. We can walk tomorrow.",
    say: "Maybe I'll text Priya. We can walk tomorrow." },
  { from: 37.6, to: 42.8, who: "Sol", note: "warm",
    text: "A kind next step, I think.",
    say: "A kind next step, I think." },
  { from: 43.0, to: 55.2, who: "Sol", note: "sincere, the heart of it",
    text: "A journal holds your most private words. So everything I do stays on your iPhone. No servers, no account. Even offline.",
    say: "A journal holds your most private words. So everything I do stays on your iPhone. No servers, no account. Even offline." },
  { from: 55.4, to: 59.6, who: "Sol", note: "warm close",
    text: "Your words stay yours.",
    say: "Your words stay yours." },
];
```

- [ ] **Step 3: Pin Sol's lines to the screen** — `marketing/memento-story/timeline.test.mjs`

```js
import assert from "node:assert/strict";
import test from "node:test";

for (const ad of ["memento-story", "memento-story-30"]) {
  test(`${ad}: Sol only names what the footage shows`, async () => {
    let tl;
    try { tl = await import(`../${ad}/timeline.mjs`); } catch { return; }
    const sol = tl.VO.filter((v) => v.who === "Sol").map((v) => v.text);
    const tagLine = sol.find((t) => t.includes("Priya") && !t.includes("wrote"));
    assert.ok(tagLine, "a tag line mentions Priya");
    assert.ok(tagLine.includes(tl.TAGS_ON_SCREEN[0]), `tag line names ${tl.TAGS_ON_SCREEN[0]}`);
    assert.ok(sol.some((t) => t.includes(`On ${tl.MEMORY_DATE}, you wrote`)), `memory line quotes ${tl.MEMORY_DATE}`);
  });
}
```

Update `marketing/package.json`'s test script to `node --test kit/ memento-story/timeline.test.mjs`.

- [ ] **Step 4: Run the checks**

Run: `cd marketing && npm test`
Expected: PASS, with `memento-story timeline is valid` and `memento-story: Sol only names what the footage shows` now running.

- [ ] **Step 5: Commit**

```bash
cd marketing && npm test && cd .. && git add marketing/memento-story/timeline.mjs marketing/memento-story/timeline.test.mjs marketing/package.json \
  && git commit -m "Story video: 60 s timeline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Story scene (paper world, Sol, phone, subtitles)

**Files:**
- Create: `marketing/memento-story/prep.mjs`, `marketing/memento-story/scene.html`, `marketing/memento-story/scene.js`
- Test: `marketing/memento-story/scene.test.mjs`

**Interfaces:**
- Consumes:
  - the timeline (Task 4)
  - `cutout`, `paper` (Task 1) and `extractFrames` (Task 1)
  - `build/vo-timing.json` (Task 2)
  - the accepted art (Task 3)
- Produces:
  - `window.renderAt(t)` (async) for the kit
  - `window.subtitleAt(t) → string` for tests

- [ ] **Step 1: Write the failing test** — `marketing/memento-story/scene.test.mjs`

```js
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { chromium } from "@playwright/test";
import { loadAd } from "../kit/render.mjs";

// Opens the scene through the kit's static server and checks pure-function behaviour at given times.
async function withScene(fn) {
  const { serveForTest } = await import("../kit/render.mjs");
  const ad = await loadAd("memento-story");
  const { server, base } = await serveForTest(ad.folder);
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.goto(`${base}?t=0`, { waitUntil: "networkidle" });
    await page.evaluate(() => window.__ready);
    await fn(page);
    assert.deepEqual(errors, []);
  } finally {
    await browser.close();
    server.close();
  }
}

test("every voice line's subtitle shows at its middle", async () => {
  const timing = JSON.parse(readFileSync(new URL("./build/vo-timing.json", import.meta.url), "utf8"));
  await withScene(async (page) => {
    for (const line of timing) {
      const mid = (line.start + line.out) / 2;
      assert.equal(await page.evaluate((t) => window.subtitleAt(t), mid), line.text);
    }
  });
});

test("every half second renders without errors and with a phone frame while the phone is up", async () => {
  await withScene(async (page) => {
    for (let t = 0; t < 60; t += 0.5) {
      await page.evaluate((x) => window.renderAt(x), t);
      const src = await page.evaluate(() => document.querySelector("#screen").getAttribute("src") ?? "");
      if (t >= 5.6 && t < 42.4) assert.match(src, /build\/frames\//, `phone frame at ${t}s`);
    }
  });
});
```

Add to `marketing/kit/render.mjs`, next to `serve`, so tests can open a scene:

```js
export const serveForTest = serve;
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd marketing && node --test memento-story/scene.test.mjs`
Expected: FAIL (`scene.html` not found or `subtitleAt` undefined).

- [ ] **Step 3: Write `marketing/memento-story/prep.mjs`**

```js
// Story art (scenes cropped to 1920×1080), Sol's cut-outs (defringed for night), and footage frames.
import { mkdir, stat } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import { extractFrames } from "../kit/footage.mjs";
import { ROOT } from "../kit/render.mjs";
import { prepArt } from "../memento-demo/prep.mjs";

const exists = (f) => stat(f).then(() => true, () => false);

// Reads the ad's own timeline, so the 30 s cut reuses this file unchanged.
export default async function prep(ad) {
  const { FPS, SCENES, SEGMENTS, WIDTH, HEIGHT } = ad.tl;
  await mkdir(path.join(ad.build, "art"), { recursive: true });
  await prepArt(ad, { defringe: true });
  for (const img of new Set(SCENES.map((s) => s.img))) {
    const dst = path.join(ad.build, "art", `${img}.jpg`);
    if (await exists(dst)) continue;
    await sharp(path.join(ROOT, "design-assets/accepted", `${img}.png`))
      .resize(WIDTH, HEIGHT, { fit: "cover", position: "centre", kernel: "lanczos3" })
      .jpeg({ quality: 92 }).toFile(dst);
  }
  await extractFrames({ build: ad.build, footageDir: path.join(ad.dir, "..", "memento-demo", "footage"), segments: SEGMENTS, fps: FPS });
}
```

- [ ] **Step 4: Write `marketing/memento-story/scene.html`**

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Memento story scene</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;1,6..72,400;1,6..72,500&display=block" rel="stylesheet">
<style>
  :root { --bg: #f6f1e7; --card: #fffcf6; --ink: #2b2723; --mut: #6f675d; --line: #e3daca; --ter: #a85a38; --sage: #56724f; --sageT: #dfe7d8; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { width: 1920px; height: 1080px; overflow: hidden; background: #1f2438; }
  body { font-family: -apple-system, "SF Pro Text", system-ui, sans-serif; -webkit-font-smoothing: antialiased; }
  #stage, #world { position: absolute; inset: 0; overflow: hidden; }
  .shot { position: absolute; inset: 0; width: 1920px; height: 1080px; object-fit: cover; opacity: 0; transform-origin: 30% 50%; }
  .wash { position: absolute; inset: 0; pointer-events: none; }
  #grade { mix-blend-mode: multiply; }
  #moon { width: 520px; height: 520px; border-radius: 50%; background: radial-gradient(closest-side, rgba(242, 238, 226, 0.45), rgba(242, 238, 226, 0)); position: absolute; }
  #glow { width: 760px; height: 760px; border-radius: 50%; background: radial-gradient(closest-side, rgba(255, 196, 140, 0.42), rgba(255, 196, 140, 0)); position: absolute; mix-blend-mode: screen; }
  #sunrise { background: linear-gradient(115deg, rgba(255, 186, 140, 0.55), rgba(255, 220, 180, 0.15) 45%, rgba(255, 220, 180, 0) 70%); mix-blend-mode: screen; opacity: 0; }
  #clock { position: absolute; font-family: -apple-system, system-ui; font-weight: 600; font-size: 22px; color: #2b2723; letter-spacing: 0.5px; transform: translate(-50%, -50%); }
  #sol { position: absolute; transform-origin: 50% 100%; }
  #sol img { position: absolute; left: 0; bottom: 0; width: 100%; opacity: 0; }
  #sol-shadow { position: absolute; border-radius: 50%; background: radial-gradient(closest-side, rgba(20, 16, 12, 0.3), rgba(20, 16, 12, 0)); }
  .wave { position: absolute; border: 4px solid #f2e1d4; border-left-color: transparent; border-bottom-color: transparent; border-radius: 50%; opacity: 0; }
  #phone { position: absolute; border-radius: 64px; background: #1c1a18; padding: 11px; box-shadow: 0 50px 90px rgba(10, 8, 20, 0.45), inset 0 0 0 3px #3a3631; transform-style: preserve-3d; }
  #screen-wrap { position: relative; width: 100%; height: 100%; border-radius: 54px; overflow: hidden; background: var(--bg); }
  #screen { position: absolute; left: 0; top: 0; width: 100%; }
  #statusfix { position: absolute; display: flex; align-items: center; justify-content: center; font-weight: 600; color: #000; }
  #ring { position: absolute; border: 4px solid var(--ter); border-radius: 22px; opacity: 0; box-shadow: 0 0 0 8px rgba(168, 90, 56, 0.16); }
  .chip { position: absolute; padding: 12px 22px; border-radius: 999px; background: rgba(255, 252, 246, 0.94); color: var(--ink); font-size: 26px; font-weight: 600; box-shadow: 0 10px 24px rgba(10, 8, 20, 0.18); opacity: 0; white-space: nowrap; }
  .chip i { display: inline-block; width: 12px; height: 12px; border-radius: 50%; background: var(--sage); margin-right: 12px; vertical-align: 2px; }
  #wordmark { position: absolute; left: 96px; top: 70px; font-family: Newsreader, serif; font-weight: 500; font-size: 64px; color: #f6f1e7; opacity: 0; letter-spacing: -0.01em; }
  #endcard { position: absolute; left: 860px; top: 330px; opacity: 0; }
  #endcard .name { font-family: Newsreader, serif; font-weight: 500; font-size: 150px; line-height: 1; color: var(--ink); letter-spacing: -0.02em; }
  #endcard .tag { margin-top: 22px; font-size: 36px; color: var(--mut); }
  #endcard .yours { margin-top: 44px; font-family: Newsreader, serif; font-style: italic; font-size: 62px; color: var(--ter); }
  #endcard .foot { margin-top: 56px; font-size: 24px; color: var(--mut); letter-spacing: 0.02em; }
  #veil { position: absolute; inset: 0; background: rgba(246, 241, 231, 0.78); opacity: 0; }
  #subs { position: absolute; left: 96px; bottom: 64px; max-width: 1100px; opacity: 0; }
  #subs span { display: inline; padding: 10px 18px; line-height: 1.6; font-size: 34px; font-weight: 500; color: #fffcf6; background: rgba(23, 20, 18, 0.62); border-radius: 12px; box-decoration-break: clone; -webkit-box-decoration-break: clone; }
</style>
</head>
<body>
<div id="stage">
  <div id="world"></div>
  <div class="wash" id="grade"></div>
  <div id="moon"></div>
  <div id="glow"></div>
  <div class="wash" id="sunrise"></div>
  <div id="clock">2:04</div>
  <div id="sol-shadow"></div>
  <div id="sol">
    <img data-pose="hello" src="build/art/sol-hello.png" alt="">
    <img data-pose="listening" src="build/art/sol-listening.png" alt="">
    <img data-pose="thinking" src="build/art/sol-thinking.png" alt="">
    <img data-pose="mark" src="build/art/sol-mark.png" alt="">
    <img data-pose="reflect" src="build/art/sol-reflect.png" alt="">
    <img data-pose="resting" src="build/art/sol-resting.png" alt="">
  </div>
  <div class="wave" id="wave1"></div>
  <div class="wave" id="wave2"></div>
  <div id="phone"><div id="screen-wrap"><img id="screen" alt=""><div id="statusfix">2:04</div><div id="ring"></div></div></div>
  <div id="chips"></div>
  <div id="wordmark">Memento</div>
  <div id="veil"></div>
  <div id="endcard">
    <div class="name">Memento</div>
    <div class="tag">Write naturally. Notice gently. Find it again.</div>
    <div class="yours">Your words stay yours.</div>
    <div class="foot">Built with Apple Foundation Models · on-device</div>
  </div>
  <div id="subs"><span></span></div>
</div>
<script type="module" src="scene.js"></script>
</body>
</html>
```

- [ ] **Step 5: Write `marketing/memento-story/scene.js`**

```js
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
  await Promise.all($$("img").map((i) => i.decode().catch(() => {})));
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
    const tf = `translate(${lerp(x0, x1, p).toFixed(3)}%, ${lerp(y0, y1, p).toFixed(3)}%) scale(${lerp(s0, s1, p).toFixed(4)})`;
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
  let r = 0, g = 0, b = 0, a = 0, total = 0;
  for (const s of shots) {
    const w = s.enter === "unfold" ? (t >= s.from && t < s.to ? easeInOut(prog(t, s.from, s.from + 0.8)) * (1 - easeInOut(prog(t, s.to - 0.6, s.to))) : 0) : shotWeight(s, t);
    if (!w) continue;
    const [gr, gg, gb, ga] = GRADES[s.grade];
    r += gr * w; g += gg * w; b += gb * w; a += ga * w; total += w;
  }
  if (total) css($("#grade"), { background: `rgba(${(r / total) | 0}, ${(g / total) | 0}, ${(b / total) | 0}, ${(a / total).toFixed(3)})` });
  const night = t < 22.2 || (t > 34.4 && t < 43.0);
  const moon = px(ANCHORS.moon);
  css($("#moon"), { left: `${moon.x - 260}px`, top: `${moon.y - 260}px`, opacity: night ? (0.75 + Math.sin(t * 1.3) * 0.12).toFixed(3) : "0" });
  const her = px(t < 5.6 ? ANCHORS.herNight : ANCHORS.herSitting);
  const glowOn = night ? Math.min(1, prog(t, 0, 0.6) + (t >= 5 ? 1 : 0)) : 0;
  css($("#glow"), { left: `${her.x - 380}px`, top: `${her.y - 380}px`, opacity: (glowOn * (0.85 + Math.sin(t * 2.4) * 0.08)).toFixed(3) });
  css($("#sunrise"), { opacity: (easeInOut(prog(t, 42.6, 44.4)) * (1 - prog(t, 47.0, 48.0))).toFixed(3) });
  const clock = px(ANCHORS.clock);
  css($("#clock"), { left: `${clock.x}px`, top: `${clock.y}px`, opacity: t < T.clockOut ? String(1 - prog(t, T.clockOut - 0.5, T.clockOut)) : "0" });
}

// ---------- Sol ----------

function solAt(t) {
  let k = SOL.length - 1;
  while (k > 0 && SOL[k].t > t) k--;
  const a = SOL[k];
  const b = SOL[k + 1];
  const moving = b && (b.mode === "walk" || a.mode === "walk");
  const p = b ? (moving ? prog(t, a.t, b.t) : easeInOut(prog(t, b.t - 0.7, b.t))) : 0;
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
    transform: `translateY(${(bob + sink).toFixed(2)}px) rotate(${tilt.toFixed(2)}deg)`,
  });
  css($("#sol-shadow"), { display: hidden ? "none" : "", left: `${(s.x - s.w * 0.4).toFixed(1)}px`, top: `${(s.y - s.w * 0.06).toFixed(1)}px`,
                          width: `${(s.w * 0.8).toFixed(1)}px`, height: `${(s.w * 0.12).toFixed(1)}px`, opacity: String(rise * 0.9) });
  const f = prog(t, s.since, s.since + 0.18);
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
  const zoom = 1 + 0.12 * easeInOut(prog(t, T.zoomIn, T.zoomIn + 0.8)) * (1 - easeInOut(prog(t, T.zoomOut, T.zoomOut + 0.5)));
  const away = (1 - inP + outP) * 900;
  css($("#phone"), {
    display: shown ? "" : "none", width: `${w.toFixed(1)}px`, height: `${h.toFixed(1)}px`,
    left: `${(PHONE.x * WIDTH - w / 2).toFixed(1)}px`, top: `${(PHONE.y * HEIGHT - h / 2).toFixed(1)}px`,
    transformOrigin: "50% 66%", transform: `translateX(${away.toFixed(1)}px) perspective(2400px) rotateY(${PHONE.tilt}deg) scale(${zoom.toFixed(4)})`,
  });
  const seg = segAt(t);
  if (!shown || !seg) return;
  const sw = w - 22;
  const sh = sw * (1440 / 662);
  // The journal chip, as fractions of the screen (measured in v1).
  const ringP = prog(t, T.chip, T.chip + 0.35);
  css($("#ring"), { left: `${(0.154 * sw).toFixed(1)}px`, top: `${(0.653 * sh).toFixed(1)}px`, width: `${(0.544 * sw).toFixed(1)}px`,
                    height: `${(0.0444 * sh).toFixed(1)}px`, opacity: String(Math.min(1, ringP * 1.4) * (1 - prog(t, T.zoomOut - 0.2, T.zoomOut + 0.2))),
                    transform: `scale(${lerp(1.25, 1, easeBack(ringP)).toFixed(3)})` });
  // The status bar says 2:04, like the story: paint over the recorded 9:41 in the screen's own colour.
  css($("#statusfix"), { left: `${(0.04 * sw).toFixed(1)}px`, top: `${(0.012 * sh).toFixed(1)}px`, width: `${(0.15 * sw).toFixed(1)}px`,
                         height: `${(0.026 * sh).toFixed(1)}px`, fontSize: `${(0.04 * sw).toFixed(1)}px` });
  const n = frames[seg.id];
  const i = clamp(Math.floor((t - seg.at) * FPS), 0, n - 1) + 1;
  const src = `build/frames/${seg.id}/${String(i).padStart(5, "0")}.jpg`;
  if (src !== lastSrc) {
    const img = $("#screen");
    img.src = src;
    lastSrc = src;
    await img.decode().catch(() => {});
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
```

- [ ] **Step 6: Generate speech timings, then run the tests**

Run:
```bash
cd marketing && ELEVENLABS_API_KEY="$(cat "$SCRATCH/.eleven")" node kit/voice.mjs memento-story --clips-only \
  && node -e 'import("./kit/render.mjs").then(async (k) => { const ad = await k.loadAd("memento-story"); await (await import("./memento-story/prep.mjs")).default(ad); })' \
  && node --test memento-story/scene.test.mjs
```
Expected:
- **clips-only:** prints the tempo table. Every line must be ≤ 1.10x; if one isn't, shorten its `text`/`say` in `timeline.mjs` and re-run.
- **prep:** extracts frames without a "frames" error.
- **tests:** PASS.

- [ ] **Step 7: Stills at every beat, and the Review Focus checks**

Run:
```bash
cd marketing && node kit/render.mjs memento-story --still 1.5,7.5,9.8,12.5,17.0,19.5,22.4,26.9,30,35.5,38.5,41,43.5,46,50,57.5
```
Check each still against the spec's beat table. Also check:
- **Status bar:** at 7.5, 12.5, 19.5, 26.9 and 38.5, it reads 2:04 and the patch is invisible. If it isn't, re-record with `STATUS_TIME` (see below) and re-measure the cut points.
- **Tags:** at 12.5, the footage tags equal `TAGS_ON_SCREEN`. At 26.9, the chip shows `MEMORY_DATE`. If either differs, change the constant and the matching VO line.
- **Sol on the journal at night (9.8):** crop 3× (`magick t-9.80.png -crop 400x400+180+420 -resize 300% sol-crop.png`) and check for a cream halo. If one shows, tighten `defringe` (raise the 170 threshold to 200 in `kit/art.mjs`).
- **Unfold (22.4):** the flashback opens from the journal, not from a corner.
- **Subtitles:** legible on both the night and morning scenes.

Re-record fallback: change `record.sh` to accept `STATUS_TIME="${STATUS_TIME:-9:41}"` in its `status_bar` call, run `STATUS_TIME=2:04 TAKE=Night marketing/memento-demo/record.sh Scene2Write Scene4Sol` at night, and re-measure `SEGMENTS` from contact sheets:

```bash
ffmpeg -ss <from> -t <span> -i <clip>.mov -vf "fps=2,scale=150:-1,tile=10x1" -frames:v 1 sheet.png
```

- [ ] **Step 8: Commit**

```bash
cd marketing && npm test && node --test memento-story/scene.test.mjs && cd .. \
  && git add marketing/memento-story marketing/kit/render.mjs && git commit -m "Story video: paper-world scene, Sol in the world, phone, subtitles

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Score, render and mix (60 s)

**Files:**
- Create: `marketing/memento-story/music.json` (the request body)
- Output: `marketing/memento-story/build/music.mp3`, `marketing/memento-story/out/memento-story-16x9-vo.mp4`

**Interfaces:**
- Consumes: the scene (Task 5) and the kit voice mixer (Task 2).
- Produces the verified 60 s master.

- [ ] **Step 1: Write the score request** — `marketing/memento-story/music.json`

```json
{"prompt": "Gentle cinematic underscore for a 60-second story about a woman who can't sleep and a wise old paper tortoise in her journal. 0-20s: sparse felt piano and a soft warm pad at night, very quiet, intimate. 20-34s: warm strings and nylon guitar swell gently for a tender memory of a sunset walk with a friend. 34-42s: settle back, soft and hopeful. 42-55s: brighten into morning with light glockenspiel and lighter guitar, unhurried. 55-60s: a tender warm resolve. Around 75 bpm, no vocals, no drums, sits quietly under dialogue.", "music_length_ms": 60000}
```

- [ ] **Step 2: Generate it**

```bash
cd marketing/memento-story && mkdir -p build && curl -s -m 300 -o build/music.mp3 -w "status=%{http_code}\n" \
  -H "xi-api-key: $(cat "$SCRATCH/.eleven")" -H "Content-Type: application/json" -d @music.json \
  "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128" && ffprobe -v error -show_entries format=duration -of csv=p=0 build/music.mp3
```
Expected: `status=200` and a duration of about 60.0. Play it (`afplay build/music.mp3`) for a listening pass. Regenerate if it has drums, vocals or a jarring change.

- [ ] **Step 3: Render, mix and verify**

```bash
cd marketing && node kit/render.mjs memento-story && ELEVENLABS_API_KEY="$(cat "$SCRATCH/.eleven")" node kit/voice.mjs memento-story \
  && node kit/verify.mjs memento-story/out/memento-story-16x9-vo.mp4 --duration 60
```
Expected:
- the voice table shows every line ≤ 1.10x
- `verify` prints OK: 1920x1080, 60.00 s, −16 ±1 LUFS, true peak ≤ −1.0 dBTP, no black frames

- [ ] **Step 4: Frame check at every transition, and a listening pass**

```bash
cd marketing/memento-story/out && ffmpeg -loglevel error -y -i memento-story-16x9-vo.mp4 \
  -vf "select='eq(n\,150)+eq(n\,165)+eq(n\,660)+eq(n\,672)+eq(n\,1020)+eq(n\,1260)+eq(n\,1272)+eq(n\,1290)+eq(n\,1584)+eq(n\,1662)+eq(n\,1800)',scale=480:-1,tile=4x3" \
  -frames:v 1 -vsync 0 transitions.png
```
Open `transitions.png`. Check:
- no empty phone, no clipped Sol, no half-faded text stuck on screen
- the flashback unfolds and folds from the journal
- dawn re-lights the same room

Play the MP4 once and check that every line is clear over the music, and that the music doesn't hide any subtitle-paired line.

- [ ] **Step 5: Commit the source** (outputs stay ignored)

```bash
cd marketing && npm test && cd .. && git add marketing/memento-story/music.json && git commit -m "Story video: score request and verified 60 s master

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The 30 s cut-down

**Files:**
- Create: `marketing/memento-story-30/timeline.mjs`, `marketing/memento-story-30/scene.html`, `marketing/memento-story-30/prep.mjs`, `marketing/memento-story-30/music.json`
- Test: `marketing/kit/check.test.mjs` (its `memento-story-30` case now runs)

**Interfaces:**
- Consumes: the story scene and prep from Task 5. Both read the page's or ad's own timeline, so they're reused unchanged.
- Produces the verified 30 s cut.

- [ ] **Step 1: Write `marketing/memento-story-30/timeline.mjs`**

```js
// The 30 s cut of the Memento story: hook, tags, the question and the Priya flashback, why local, end card.
export { FPS, WIDTH, HEIGHT, ANCHORS, VOICES, TAGS_ON_SCREEN, MEMORY_DATE } from "../memento-story/timeline.mjs";
export const NAME = "memento-story-30";
export const DURATION = 30;
export const COVER_T = 15.6;
export const DOC = { title: "Memento story (30 s)", notes: [], rules: ["Same rules as the 60 s master."] };

export const SCENES = [
  { id: "night", img: "story-night", from: 0, to: 4.4, drift: [0, 0, 1.0, -1, 0, 1.03], grade: "night" },
  { id: "writing", img: "story-writing", from: 3.8, to: 10.2, drift: [-1, 0, 1.04, 0, -1, 1.06], grade: "night", enter: "fade" },
  { id: "dusk", img: "story-dusk", from: 9.4, to: 20.8, drift: [1, 0, 1.06, -1, 0, 1.0], grade: "dusk", enter: "unfold" },
  { id: "morning", img: "story-morning", from: 20.0, to: 30, drift: [-2, 0, 1.0, 1, 0, 1.05], grade: "day", enter: "fade" },
];

export const PHONE = { in: 3.9, out: 20.4, x: 0.785, y: 0.5, h: 0.89, tilt: -7, glow: true };

export const SEGMENTS = [
  { id: "typing", clip: "Scene2Write", at: 3.9, to: 6.0, src: 16.4, rate: 15.4 },
  { id: "tags", clip: "Scene2Write", at: 6.0, to: 9.4, src: 51.5, rate: 1 },
  { id: "solListen", clip: "Scene4SolC", at: 9.4, to: 12.8, src: 24.0, rate: 1 },
  { id: "solThink", clip: "Scene4SolC", at: 12.8, to: 13.4, src: 28.2, rate: 1 },
  { id: "solReply", clip: "Scene4SolC", at: 13.4, to: 20.4, src: 31.3, rate: 1 },
];

export const SOL = [
  { t: 0, mode: "hidden", pose: "listening", at: "journal", w: 0.10 },
  { t: 5.6, mode: "peek", pose: "listening", at: "journal", w: 0.10 },
  { t: 6.6, mode: "idle", pose: "mark", at: "journal", w: 0.10 },
  { t: 9.6, mode: "idle", pose: "reflect", at: "flashCorner", w: 0.13 },
  { t: 20.2, mode: "walk", pose: "mark", at: "pathStart", w: 0.095 },
  { t: 26.8, mode: "walk", pose: "mark", at: "pathEnd", w: 0.095 },
  { t: 27.2, mode: "idle", pose: "hello", at: "endSol", w: 0.21 },
];

export const CHIPS = [
  { from: 6.0, to: 9.4, text: "Tags from your words · on device" },
  { from: 13.4, to: 20.4, text: "Sol remembers" },
];

export const T = { clockOut: 4.4, wordmarkIn: 9.6, wordmarkOut: 12.6, chip: 17.6, zoomIn: 16.7, zoomOut: 20.0, end: 27.0 };

export const SFX = [
  ...[0.3, 1.3, 2.3, 3.3].map((t) => ({ t, kind: "tick", gain: 0.22 })),
  { t: 5.6, kind: "whoosh", gain: 0.22, dur: 0.35 },
  { t: 6.05, kind: "ding", gain: 0.28 },
  { t: 9.45, kind: "tap", gain: 0.4 },
  { t: 9.4, kind: "whoosh", gain: 0.3, dur: 0.7 },
  { t: T.chip, kind: "sparkle", gain: 0.35 },
  { t: 20.4, kind: "whoosh", gain: 0.3, dur: 0.5 },
  { t: T.end + 0.2, kind: "ding", gain: 0.4 },
];

export const VO = [
  { from: 0.3, to: 3.9, who: "Her", note: "2 a.m., tired", text: "It's 2 a.m., and I can't switch off.", say: "It's two a.m., and I can't switch off." },
  { from: 6.1, to: 9.5, who: "Sol", note: "gentle", text: "Drained. And a walk with Priya that helped.", say: "Drained. And a walk with Priya that helped." },
  { from: 9.8, to: 13.4, who: "Her", note: "honest", text: "Work stress is back this week. What helped me last time?", say: "Work stress is back this week. What helped me last time?" },
  { from: 13.5, to: 20.4, who: "Sol", note: "remembering fondly", text: "On Sep 13, you wrote: “Long walk with Priya after work.”", say: "On September thirteenth, you wrote: long walk with Priya, after work." },
  { from: 20.6, to: 27.0, who: "Sol", note: "sincere", text: "And everything I do stays on your iPhone. No servers. Even offline.", say: "And everything I do stays on your iPhone. No servers. Even offline." },
  { from: 27.3, to: 29.7, who: "Sol", note: "warm close", text: "Your words stay yours.", say: "Your words stay yours." },
];
```

- [ ] **Step 2: Run the timeline checks**

Run: `cd marketing && npm test`
Expected: PASS, with `memento-story-30 timeline is valid` running.

- [ ] **Step 3: Create `marketing/memento-story-30/prep.mjs` and `scene.html`**

`prep.mjs`:

```js
// Same art and footage as the 60 s master, built into this cut's build/.
import prep from "../memento-story/prep.mjs";
export default prep;
```

`scene.html`: copy `marketing/memento-story/scene.html`, changing only the script tag to `<script type="module" src="../memento-story/scene.js"></script>`.

- [ ] **Step 4: Score, clips, render, mix, verify**

`music.json`:

```json
{"prompt": "Gentle cinematic underscore for a 30-second story: 0-9s sparse felt piano at night, quiet and intimate; 9-20s warm strings and nylon guitar swell for a tender memory of a sunset walk; 20-27s brighten into morning with light glockenspiel; 27-30s a tender warm resolve. Around 75 bpm, no vocals, no drums, sits under dialogue.", "music_length_ms": 30000}
```

```bash
cd marketing/memento-story-30 && mkdir -p build && cp -R ../memento-story/build/vo build/ \
  && curl -s -m 300 -o build/music.mp3 -w "status=%{http_code}\n" -H "xi-api-key: $(cat "$SCRATCH/.eleven")" -H "Content-Type: application/json" -d @music.json "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128" \
  && cd .. && ELEVENLABS_API_KEY="$(cat "$SCRATCH/.eleven")" node kit/voice.mjs memento-story-30 --clips-only \
  && node kit/render.mjs memento-story-30 && ELEVENLABS_API_KEY="$(cat "$SCRATCH/.eleven")" node kit/voice.mjs memento-story-30 \
  && node kit/verify.mjs memento-story-30/out/memento-story-30-16x9-vo.mp4 --duration 30
```
Expected:
- the voice table shows every line ≤ 1.10x
- `verify` prints OK at 30.00 s

Spot-check stills at 1.5, 7.0, 10.0, 17.6, 20.2 (flashback fading into morning, no hard cut), 24.0 and 28.5.

- [ ] **Step 5: Commit**

```bash
cd marketing && npm test && node --test memento-story/scene.test.mjs && cd .. \
  && git add marketing/memento-story-30 \
  && git commit -m "Story video: 30 s cut-down

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Deliverables and docs

**Files:**
- Modify: `marketing/README.md`, `docs/superpowers/specs/2026-10-10-memento-story-video-design.md` (status line)
- Output (git-ignored): `marketing/final/Memento story – 60s 16x9.mp4`, `Memento story – 30s 16x9.mp4`, cover PNGs and `.srt` files

- [ ] **Step 1: Collect the finals and re-verify the copies**

```bash
cd marketing && cp memento-story/out/memento-story-16x9-vo.mp4 "final/Memento story – 60s 16x9.mp4" \
  && cp memento-story-30/out/memento-story-30-16x9-vo.mp4 "final/Memento story – 30s 16x9.mp4" \
  && cp memento-story/out/memento-story-cover.png "final/Memento story – 60s cover.png" \
  && cp memento-story-30/out/memento-story-30-cover.png "final/Memento story – 30s cover.png" \
  && cp memento-story/out/memento-story-vo.srt "final/Memento story – 60s.srt" \
  && cp memento-story-30/out/memento-story-30-vo.srt "final/Memento story – 30s.srt" \
  && node kit/verify.mjs "final/Memento story – 60s 16x9.mp4" --duration 60 && node kit/verify.mjs "final/Memento story – 30s 16x9.mp4" --duration 30
```
Expected: both print OK.

- [ ] **Step 2: Document.**
  - Add both ads to the table in `marketing/README.md`, with their commands (`--clips-only` before render; the `music.json` curl).
  - Set the spec's status line to "Built Oct 10, 2026".

- [ ] **Step 3: Commit and push**

```bash
cd marketing && npm test && cd .. && git add marketing/README.md docs/superpowers/specs/2026-10-10-memento-story-video-design.md \
  && git commit -m "Story video: deliverables and docs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push origin app:main
```
