// Voices an ad and mixes the voice over each rendered cut, either with
// ElevenLabs or from a take someone recorded:
//
//   ELEVENLABS_API_KEY=... node marketing/kit/voice.mjs <ad> [--variant quiz]
//   node marketing/kit/voice.mjs <ad> --variant quiz --take <ad>/recordings/quiz-take1.m4a
//
// A take is one file with every line of that cut's script, in order, with a
// short pause between lines. It is split at the pauses, cleaned, and placed in
// the speaker's own rhythm.
//
// Needs <ad>/build/<cut>/video.mp4 and sfx.wav from kit/render.mjs. Every line
// is cached in <ad>/build/vo/ under a hash of its text, voice, model and
// settings, so a re-run only spends characters on lines that changed, and a
// line shared by several hooks is generated once. The key is read from the
// environment and never written anywhere.
// Set VOICE_OFFLINE=1 to reuse cached clips without an API key; cache misses fail.

import { execFile, spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { once } from "node:events";
import { access, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { flag, loadAd, ROOT, writeCrops } from "./render.mjs";
import { forVariant } from "./text.mjs";

const MAX_TEMPO = 1.25;
export const LIMITER_FILTER = "alimiter=limit=0.85:level=false";
const GAP = 0.1;
// A human take keeps its own pacing: lines may start up to EARLY before their
// beat, pauses close to about 0.16s (the clip's own air plus TAKE_GAP), and the whole take speeds up uniformly by no
// more than MAX_TAKE_TEMPO. Hook lines (those with a `variant`) stay on their beat.
const EARLY = 0.4;
const TAKE_GAP = 0.06;
const MAX_TAKE_TEMPO = 1.08;

const exec = promisify(execFile);
const aspect = (tl) => (tl.WIDTH > tl.HEIGHT ? "16x9" : "9x16");

const exists = (f) => access(f).then(() => true, () => false);

async function ffmpeg(args) {
  const p = spawn("ffmpeg", ["-y", "-hide_banner", "-loglevel", "error", ...args], { stdio: "inherit" });
  const [code] = await once(p, "close");
  if (code !== 0) throw new Error(`ffmpeg exited ${code}`);
}

async function duration(file) {
  const { stdout } = await exec("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file]);
  return Number(stdout.trim());
}

async function synthesize(VOICES, line, file) {
  const voice = VOICES[line.who];
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voice.id}?output_format=mp3_44100_128`, {
    method: "POST",
    headers: { "xi-api-key": process.env.ELEVENLABS_API_KEY, "content-type": "application/json" },
    body: JSON.stringify({ text: line.say, model_id: VOICES.model, voice_settings: voice.settings ?? VOICES.settings }),
  });
  if (!res.ok) throw new Error(`ElevenLabs ${res.status} for "${line.text}": ${await res.text()}`);
  await writeFile(file, Buffer.from(await res.arrayBuffer()));
  return Number(res.headers.get("character-cost") ?? line.say.length);
}

const stamp = (s) => {
  const ms = Math.round(s * 1000);
  const p = (n, w = 2) => String(n).padStart(w, "0");
  return `00:00:${p(Math.floor(ms / 1000))},${p(ms % 1000, 3)}`;
};

// Generates (or reuses) one line and returns its trimmed WAV and speech length.
async function clipFor(ad, line) {
  const { VOICES } = ad.tl;
  const voDir = path.join(ad.build, "vo");
  await mkdir(voDir, { recursive: true });
  const hash = createHash("sha1")
    .update(JSON.stringify([VOICES.model, VOICES[line.who].settings ?? VOICES.settings, VOICES[line.who].id, line.say]))
    .digest("hex")
    .slice(0, 10);
  const raw = path.join(voDir, `${line.who}-${hash}.mp3`);
  const cached = await exists(raw);
  if (!cached && process.env.VOICE_OFFLINE === "1") {
    throw new Error(`VOICE_OFFLINE=1: missing cached voice clip ${raw}; ElevenLabs synthesis is disabled.`);
  }
  const spent = cached ? 0 : await synthesize(VOICES, line, raw);

  // Trim the lead-in and the breathy tail, and squeeze dramatic pauses down
  // to a beat, so the slot math sees speech. -35 dB sits above the noise
  // floor between phrases; -45 dB left whole seconds of near-silence in.
  const trimmed = raw.replace(/\.mp3$/, ".wav");
  await ffmpeg([
    "-i", raw, "-ac", "1", "-ar", "48000", "-af",
    "silenceremove=start_periods=1:start_threshold=-35dB:start_silence=0.03," +
      "silenceremove=stop_periods=-1:stop_duration=0.3:stop_threshold=-35dB:stop_silence=0.18," +
      "areverse,silenceremove=start_periods=1:start_threshold=-35dB:start_silence=0.1,areverse",
    trimmed,
  ]);
  return { file: trimmed, len: await duration(trimmed), spent };
}

async function requireRender(ad, cut) {
  for (const f of ["video.mp4", "sfx.wav"]) {
    if (!(await exists(path.join(cut.build, f)))) throw new Error(`Missing ${path.relative(ad.dir, cut.build)}/${f}. Run kit/render.mjs first.`);
  }
}

async function ttsClips(ad, cut) {
  const { tl } = ad;
  const lines = forVariant(tl.VO, cut.variant);
  let spent = 0;
  const clips = [];
  for (const [i, line] of lines.entries()) {
    const c = await clipFor(ad, line);
    spent += c.spent;
    const end = i < lines.length - 1 ? lines[i + 1].from - GAP : tl.DURATION - 0.25;
    const slot = end - line.from;
    const tempo = Math.max(1, c.len / slot);
    clips.push({ line, file: c.file, len: c.len, slot, tempo, start: line.from, out: line.from + c.len / tempo });
  }

  console.log(`[${cut.name}] characters spent: ${spent}`);
  console.log("line  who    speech  slot   tempo  ends");
  for (const [i, c] of clips.entries()) {
    const warn = c.tempo > MAX_TEMPO ? "  <-- too long, shorten the line" : "";
    console.log(`${String(i + 1).padStart(4)}  ${c.line.who.padEnd(5)}  ${c.len.toFixed(2)}s  ${c.slot.toFixed(2)}s  ${c.tempo.toFixed(2)}x  ${c.out.toFixed(2)}s${warn}`);
  }
  if (clips.some((c) => c.tempo > MAX_TEMPO)) throw new Error(`A line needs more than ${MAX_TEMPO}x to fit. Shorten its text in timeline.mjs.`);
  // When each line is actually spoken, for the scene's subtitles.
  await writeFile(path.join(ad.build, "vo-timing.json"), JSON.stringify(
    clips.map((c, i) => ({ index: i + 1, who: c.line.who, text: c.line.text, start: Number(c.start.toFixed(3)), out: Number(c.out.toFixed(3)) })), null, 2));
  return clips;
}

// Spoken stretches of a recording, split at pauses of 0.25s or more; anything
// under 0.2s (a breath, a click) is dropped.
async function speechSegments(file) {
  const total = await duration(file);
  const { stderr } = await exec("ffmpeg", ["-hide_banner", "-i", file, "-af", "silencedetect=noise=-38dB:d=0.25", "-f", "null", "-"]);
  const silences = [];
  let open = null;
  for (const m of stderr.matchAll(/silence_(start|end): ([\d.]+)/g)) {
    if (m[1] === "start") open = Number(m[2]);
    else {
      silences.push([open ?? 0, Number(m[2])]);
      open = null;
    }
  }
  if (open !== null) silences.push([open, total]);
  const segs = [];
  let cursor = 0;
  for (const [a, b] of silences) {
    if (a > cursor) segs.push({ start: cursor, end: a });
    cursor = b;
  }
  if (cursor < total) segs.push({ start: cursor, end: total });
  return segs.filter((g) => g.end - g.start >= 0.2);
}

async function takeClips(ad, cut, takeFile) {
  const { tl } = ad;
  const lines = forVariant(tl.VO, cut.variant);
  const segs = await speechSegments(takeFile);
  if (segs.length !== lines.length) {
    throw new Error(
      `Found ${segs.length} spoken lines in ${path.basename(takeFile)}, but the ${cut.name} script has ${lines.length}:\n` +
        segs.map((g, i) => `  ${i + 1}. ${g.start.toFixed(2)}s to ${g.end.toFixed(2)}s`).join("\n") +
        "\nRe-record with a clear pause between lines, or send one file per line.",
    );
  }

  // Each line: a little air either side, rumble and hiss taken out, levels evened.
  const dir = path.join(ad.build, "take");
  await mkdir(dir, { recursive: true });
  const parts = [];
  for (const [i, g] of segs.entries()) {
    const from = Math.max(0, g.start - 0.03);
    const len = g.end + 0.07 - from;
    const file = path.join(dir, `${cut.name}-${i + 1}.wav`);
    await ffmpeg([
      "-ss", from.toFixed(3), "-t", len.toFixed(3), "-i", takeFile, "-ac", "1", "-ar", "48000", "-af",
      "highpass=f=80,afftdn=nf=-50,acompressor=threshold=-20dB:ratio=3:attack=5:release=80:makeup=2," +
        `afade=t=in:d=0.01,afade=t=out:st=${(len - 0.05).toFixed(3)}:d=0.05`,
      file,
    ]);
    parts.push({ file, len });
  }

  // The smallest uniform speed-up at which the take fits the cut.
  for (let k = 1; k <= MAX_TAKE_TEMPO + 1e-9; k = Math.round((k + 0.01) * 100) / 100) {
    let prev = -Infinity;
    const clips = lines.map((line, i) => {
      const len = parts[i].len / k;
      const start = line.variant ? Math.max(line.from, prev + TAKE_GAP) : Math.max(line.from - EARLY, prev + TAKE_GAP);
      prev = start + len;
      return { line, file: parts[i].file, len: parts[i].len, tempo: k, start, out: prev };
    });
    const fits = prev <= tl.DURATION - 0.25 && clips.every((c) => !c.line.variant || c.start - c.line.from <= 0.3);
    if (!fits) continue;
    console.log(`[${cut.name}] take ${path.relative(ROOT, takeFile)}, speed ${k.toFixed(2)}x`);
    console.log("line  speech  starts  beat    drift   ends    first words");
    for (const [i, c] of clips.entries()) {
      const drift = c.start - c.line.from;
      console.log(
        `${String(i + 1).padStart(4)}  ${c.len.toFixed(2)}s   ${c.start.toFixed(2)}s  ${c.line.from.toFixed(2)}s  ${(drift >= 0 ? "+" : "") + drift.toFixed(2)}s  ${c.out.toFixed(2)}s  ${c.line.text.slice(0, 34)}`,
      );
    }
    return clips;
  }
  throw new Error(`The take needs more than ${MAX_TAKE_TEMPO}x to fit ${tl.DURATION}s. Read it a little faster, or trim a line in timeline.mjs.`);
}

async function mixCut(ad, cut, clips) {
  const { tl } = ad;
  const stem = path.join(ad.out, `${cut.name}-vo.wav`);
  const graph = clips
    .map((c, i) => `[${i}:a]atempo=${c.tempo.toFixed(4)},adelay=${Math.round(c.start * 1000)}[v${i}]`)
    .join(";");
  await ffmpeg([
    ...clips.flatMap((c) => ["-i", c.file]),
    "-filter_complex",
    `${graph};${clips.map((_, i) => `[v${i}]`).join("")}amix=inputs=${clips.length}:normalize=0:duration=longest,` +
      `apad=whole_dur=${tl.DURATION},atrim=0:${tl.DURATION},loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[vo]`,
    "-map", "[vo]", "-ac", "1", "-ar", "48000", stem,
  ]);

  // SFX (and an optional score, <ad>/build/music.mp3) duck under the voice, then everything goes through a limiter.
  const master = path.join(ad.out, `${cut.name}-${aspect(tl)}-vo.mp4`);
  const music = path.join(ad.build, "music.mp3");
  const withMusic = await exists(music);
  const st = "aformat=sample_rates=48000:channel_layouts=stereo";
  await ffmpeg([
    "-i", path.join(cut.build, "video.mp4"), "-i", path.join(cut.build, "sfx.wav"), "-i", stem,
    ...(withMusic ? ["-i", music] : []),
    "-filter_complex",
    withMusic
      ? `[2:a]${st},asplit=3[vo1][vo2][vo3];[1:a]${st},volume=0.6[sfx];` +
        "[sfx][vo1]sidechaincompress=threshold=0.03:ratio=8:attack=15:release=250[duck];" +
        `[3:a]${st},volume=0.32,afade=t=in:d=1.2,afade=t=out:st=${(tl.DURATION - 2.5).toFixed(2)}:d=2.5[mus];` +
        "[mus][vo3]sidechaincompress=threshold=0.035:ratio=5:attack=40:release=600[mduck];" +
        `[duck][vo2][mduck]amix=inputs=3:normalize=0:duration=first,${LIMITER_FILTER},apad[a]`
      : "[2:a]asplit=2[vo1][vo2];[1:a]aresample=48000,volume=0.6[sfx];" +
        "[sfx][vo1]sidechaincompress=threshold=0.03:ratio=8:attack=15:release=250[duck];" +
        `[duck][vo2]amix=inputs=2:normalize=0:duration=first,${LIMITER_FILTER},apad[a]`,
    "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
    "-t", String(tl.DURATION), "-movflags", "+faststart", master,
  ]);
  await writeCrops(tl, master, (key) => path.join(ad.out, `${cut.name}-${key}-vo.mp4`));

  const srt = clips.map((c, i) => `${i + 1}\n${stamp(c.start)} --> ${stamp(c.out)}\n${c.line.text}\n`).join("\n");
  await writeFile(path.join(ad.out, `${cut.name}-vo.srt`), srt);
  console.log(`[${cut.name}] done → out/${cut.name}-${aspect(tl)}-vo.mp4${Object.keys(tl.CROPS ?? {}).map((k) => `, ${cut.name}-${k}-vo.mp4`).join("")}`);
}

async function main() {
  const ad = await loadAd(process.argv[2]);
  await mkdir(ad.out, { recursive: true });
  const take = flag("take");
  if (take !== undefined) {
    if (ad.cuts.length !== 1) throw new Error("A take voices one cut: pass --variant too.");
    const file = path.resolve(take);
    if (!(await exists(file))) throw new Error(`No take at ${take}`);
    await requireRender(ad, ad.cuts[0]);
    await mixCut(ad, ad.cuts[0], await takeClips(ad, ad.cuts[0], file));
    return;
  }
  if (process.env.VOICE_OFFLINE !== "1" && !process.env.ELEVENLABS_API_KEY) throw new Error("Set ELEVENLABS_API_KEY.");
  if (flag("clips-only") !== undefined) {
    for (const cut of ad.cuts) await ttsClips(ad, cut);
    console.log(`[${ad.folder}] speech timings → build/vo-timing.json`);
    return;
  }
  for (const cut of ad.cuts) {
    await requireRender(ad, cut);
    await mixCut(ad, cut, await ttsClips(ad, cut));
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message ?? e);
    process.exit(1);
  });
}
