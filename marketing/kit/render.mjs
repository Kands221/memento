// Renders an ad folder under marketing/: runs the ad's prep.mjs (art cutouts, footage frames), synthesizes the SFX
// track, captures every frame of <ad>/scene.html in headless Chromium, and encodes the MP4s, crops, covers and the
// VO script. Adapted from the LETPass marketing kit.
//
//   node marketing/kit/render.mjs <ad>                       full render into <ad>/out/
//   node marketing/kit/render.mjs <ad> --variant quiz        one hook only
//   node marketing/kit/render.mjs <ad> --still 4.4,17.9      PNG stills into <ad>/build/stills/
//   node marketing/kit/render.mjs <ad> --preview             serve scene.html?play for a live look
//   node marketing/kit/render.mjs <ad> --docs                rewrite vo-script.md only
//
// The ad's timeline.mjs exports NAME, FPS, DURATION, WIDTH, HEIGHT, COVER_T,
// CAPTIONS, SFX, VO, VOICES, DOC, and optionally VARIANTS (hook cuts sharing
// one body) and CROPS ({ "4x5": { x, y, w, h } }).

import { spawn } from "node:child_process";
import { once } from "node:events";
import { createReadStream } from "node:fs";
import { mkdir, stat, writeFile } from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "@playwright/test";
import sharp from "sharp";
import { synthesize, writeWav } from "./sfx.mjs";
import { forVariant, plain } from "./text.mjs";

const KIT = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(KIT, "../..");

const args = process.argv.slice(2);
export const flag = (name) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? undefined : (args[i + 1] ?? "");
};

export async function loadAd(name) {
  if (!name || name.startsWith("--")) throw new Error("Usage: node marketing/kit/render.mjs <ad-folder> [flags]");
  const dir = path.join(ROOT, "marketing", name);
  const tl = await import(pathToFileURL(path.join(dir, "timeline.mjs")).href);
  const only = flag("variant");
  const variants = (tl.VARIANTS ?? [null]).filter((v) => !only || v === only);
  if (!variants.length) throw new Error(`No variant "${only}" in ${name}/timeline.mjs`);
  return {
    folder: name,
    dir,
    tl,
    build: path.join(dir, "build"),
    out: path.join(dir, "out"),
    cuts: variants.map((v) => ({
      variant: v,
      name: v ? `${tl.NAME}-${v}` : tl.NAME,
      build: path.join(dir, "build", v ?? "main"),
    })),
  };
}

// ---------- prep ----------

// An ad may export a default async function from prep.mjs to build what its scene needs.
async function prep(ad) {
  const file = path.join(ad.dir, "prep.mjs");
  try {
    await stat(file);
  } catch {
    return;
  }
  const mod = await import(pathToFileURL(file).href);
  await mod.default(ad);
}

// ---------- static server ----------

const TYPES = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".webp": "image/webp", ".wav": "audio/wav", ".ttf": "font/ttf" };

async function serve(folder) {
  const allowed = [path.join(ROOT, "marketing")];
  const server = http.createServer(async (req, res) => {
    const rel = decodeURIComponent(new URL(req.url, "http://x").pathname);
    const file = path.resolve(ROOT, `.${rel}`);
    try {
      if (!allowed.some((dir) => file.startsWith(dir + path.sep))) throw new Error("forbidden");
      if (!(await stat(file)).isFile()) throw new Error("not a file");
      res.writeHead(200, { "content-type": TYPES[path.extname(file)] ?? "application/octet-stream", "cache-control": "no-store" });
      createReadStream(file).pipe(res);
    } catch {
      res.writeHead(404).end();
    }
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  return { server, base: `http://127.0.0.1:${server.address().port}/marketing/${folder}/scene.html` };
}

// ---------- capture ----------

const query = (variant, extra) => `?${new URLSearchParams({ ...(variant ? { variant } : {}), ...extra })}`;

async function openScene(browser, base, tl, variant) {
  const page = await browser.newPage({ viewport: { width: tl.WIDTH, height: tl.HEIGHT }, deviceScaleFactor: 1 });
  page.on("pageerror", (e) => console.error("[pageerror]", e.message));
  page.on("console", (m) => m.type() === "error" && console.error("[console]", m.text()));
  await page.goto(`${base}${query(variant, { t: "0" })}`, { waitUntil: "networkidle" });
  await page.evaluate(() => window.__ready);
  // A stylesheet served with the wrong type is dropped without an error, and
  // every frame silently renders unstyled.
  const unstyled = await page.evaluate(() =>
    [...document.querySelectorAll('link[rel="stylesheet"]')].filter((l) => !l.sheet).map((l) => l.href),
  );
  if (unstyled.length) throw new Error(`Stylesheets failed to load: ${unstyled.join(", ")}`);
  return page;
}

const frameAt = (page, t) => page.evaluate((x) => window.renderAt(x), t);

export function run(cmd, argv) {
  const p = spawn(cmd, argv, { stdio: ["pipe", "inherit", "inherit"] });
  const done = once(p, "close").then(([code]) => {
    if (code !== 0) throw new Error(`${cmd} exited ${code}`);
  });
  return { p, done };
}

async function captureVideo(page, tl, file) {
  const total = Math.round(tl.DURATION * tl.FPS);
  const { p, done } = run("ffmpeg", [
    "-y", "-loglevel", "error",
    "-f", "image2pipe", "-framerate", String(tl.FPS), "-c:v", "mjpeg", "-i", "-",
    "-vf", "scale=in_color_matrix=bt601:in_range=full:out_color_matrix=bt709:out_range=tv,format=yuv420p",
    "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-profile:v", "high",
    "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
    "-r", String(tl.FPS), "-movflags", "+faststart", file,
  ]);
  const started = Date.now();
  for (let i = 0; i < total; i++) {
    await frameAt(page, i / tl.FPS);
    const jpg = await page.screenshot({ type: "jpeg", quality: 95 });
    if (!p.stdin.write(jpg)) await once(p.stdin, "drain");
    if (i % tl.FPS === 0) process.stdout.write(`\r  frame ${i}/${total}  (${((Date.now() - started) / 1000).toFixed(0)}s)`);
  }
  p.stdin.end();
  await done;
  process.stdout.write(`\r  frame ${total}/${total}  done in ${((Date.now() - started) / 1000).toFixed(0)}s\n`);
}

// Re-encodes a 9:16 master into each crop declared by the timeline, keeping its audio.
export async function writeCrops(tl, src, outFor) {
  for (const [key, c] of Object.entries(tl.CROPS ?? {})) {
    await run("ffmpeg", [
      "-y", "-loglevel", "error", "-i", src,
      "-vf", `crop=${c.w}:${c.h}:${c.x}:${c.y}`,
      "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-profile:v", "high", "-pix_fmt", "yuv420p",
      "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
      "-c:a", "copy", "-movflags", "+faststart", outFor(key),
    ]).done;
  }
}

// ---------- docs ----------

const clock = (s) => `0:${s.toFixed(1).padStart(4, "0")}`;

async function writeDocs(ad) {
  const { tl, cuts } = ad;
  const hooks = tl.VARIANTS?.length > 1;
  const col = (e) => (hooks ? ` ${e.variant ?? "all"} |` : "");
  const crops = Object.keys(tl.CROPS ?? {});
  const md = [
    `# ${tl.DOC.title}: voiceover script`,
    "",
    `Generated from \`timeline.mjs\` by \`kit/render.mjs\`. Edit the timeline, not this file.`,
    "",
    `Total runtime ${tl.DURATION}s, 9:16${crops.length ? ` (plus ${crops.join(", ")} crops)` : ""}. \`kit/voice.mjs\` voices these lines`,
    `with ElevenLabs (${tl.VOICES.model}) and mixes them over the SFX into ${cuts.map((c) => `\`out/${c.name}-9x16-vo.mp4\``).join(", ")}.`,
    "",
    `Voices: ${Object.entries(tl.VOICES).filter(([, v]) => v?.id).map(([who, v]) => `${who} is ${v.name}`).join("; ")}.`,
    ...(tl.DOC.notes ?? []),
    "",
    `| Time |${hooks ? " Hook |" : ""} Who | Line | Delivery |`,
    `|---|${hooks ? "---|" : ""}---|---|---|`,
    ...tl.VO.map((v) => `| ${clock(v.from)} to ${clock(v.to)} |${col(v)} ${v.who} | ${v.text} | ${v.note} |`),
    "",
    "## On-screen captions (already burned in)",
    "",
    `| Time |${hooks ? " Hook |" : ""} Caption |`,
    `|---|${hooks ? "---|" : ""}---|`,
    ...tl.CAPTIONS.map((c) => `| ${clock(c.from)} to ${clock(c.to)} |${col(c)} ${c.lines.map(plain).join(" / ")} |`),
    "",
    "## Copy rules this script follows",
    "",
    ...tl.DOC.rules.map((r) => `- ${r}`),
    "",
  ].join("\n");
  await writeFile(path.join(ad.dir, "vo-script.md"), md);
}

// ---------- main ----------

async function main() {
  const ad = await loadAd(args[0]);
  const { tl } = ad;
  if (flag("docs") !== undefined) {
    await writeDocs(ad);
    console.log(`Wrote ${path.relative(ROOT, path.join(ad.dir, "vo-script.md"))}`);
    return;
  }
  await prep(ad);
  const { server, base } = await serve(ad.folder);

  if (flag("preview") !== undefined) {
    const v = ad.cuts[0].variant;
    console.log(`Live preview: ${base}${query(v, { play: "" })}\nStill at t:   ${base}${query(v, { t: "12.3" })}\nCtrl-C to stop.`);
    return;
  }

  const browser = await chromium.launch();
  try {
    const still = flag("still");
    for (const cut of ad.cuts) {
      const page = await openScene(browser, base, tl, cut.variant);
      if (still !== undefined) {
        const dir = path.join(ad.build, "stills");
        await mkdir(dir, { recursive: true });
        for (const t of still.split(",").map(Number)) {
          await frameAt(page, t);
          const file = path.join(dir, `${cut.variant ? `${cut.variant}-` : ""}t-${t.toFixed(2)}.png`);
          await page.screenshot({ path: file });
          console.log(file);
        }
        await page.close();
        continue;
      }

      console.log(`[${cut.name}] synthesizing SFX…`);
      await mkdir(cut.build, { recursive: true });
      await mkdir(ad.out, { recursive: true });
      const sfx = path.join(cut.build, "sfx.wav");
      await writeWav(sfx, synthesize(forVariant(tl.SFX, cut.variant), tl.DURATION));

      console.log(`[${cut.name}] capturing frames…`);
      const video = path.join(cut.build, "video.mp4");
      await captureVideo(page, tl, video);

      const coverT = typeof tl.COVER_T === "object" ? tl.COVER_T[cut.variant] : tl.COVER_T;
      await frameAt(page, coverT);
      const cover = path.join(ad.out, `${cut.name}-cover.png`);
      await page.screenshot({ path: cover });
      for (const [key, c] of Object.entries(tl.CROPS ?? {})) {
        await sharp(cover).extract({ left: c.x, top: c.y, width: c.w, height: c.h }).toFile(path.join(ad.out, `${cut.name}-${key}-cover.png`));
      }
      await page.close();

      console.log(`[${cut.name}] muxing…`);
      const master = path.join(ad.out, `${cut.name}-9x16.mp4`);
      await run("ffmpeg", ["-y", "-loglevel", "error", "-i", video, "-i", sfx,
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-shortest", "-movflags", "+faststart",
        master]).done;
      await run("ffmpeg", ["-y", "-loglevel", "error", "-i", video, "-f", "lavfi", "-t", String(tl.DURATION), "-i", "anullsrc=r=48000:cl=stereo",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "128k", "-shortest", "-movflags", "+faststart",
        path.join(ad.out, `${cut.name}-9x16-nosfx.mp4`)]).done;
      await writeCrops(tl, master, (key) => path.join(ad.out, `${cut.name}-${key}.mp4`));
    }
    if (still === undefined) {
      await writeDocs(ad);
      console.log(`Done → ${path.relative(ROOT, ad.out)}/`);
    }
  } finally {
    await browser.close();
    server.close();
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
