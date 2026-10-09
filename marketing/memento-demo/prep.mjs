// Builds what the scene needs, before rendering:
// - Sol's poses cut out of their paper background (design-assets/generated/tortoise, 1024 px);
// - the footage frames for each segment in timeline.mjs, from footage/*.mov (recorded by record.sh).
// Both are cached in build/ and only rebuilt when missing.

import { readdir, mkdir, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import { run, ROOT } from "../kit/render.mjs";
import { FPS, SEGMENTS } from "./timeline.mjs";

const exists = (f) => stat(f).then(() => true, () => false);
const POSES = ["hello", "listening", "thinking", "mark", "reflect", "resting"];

// Flood-fills the paper from the edges (so cream inside Sol's shell stays), feathering the boundary.
async function cutout(src, dst) {
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
    data[p * 4 + 3] = d <= HARD ? 0 : Math.round(((d - HARD) / (SOFT - HARD)) * 255);
    const x = p % w;
    const y = (p / w) | 0;
    if (x > 0) queue.push(p - 1);
    if (x < w - 1) queue.push(p + 1);
    if (y > 0) queue.push(p - w);
    if (y < h - 1) queue.push(p + w);
  }
  await sharp(data, { raw: { width: w, height: h, channels: 4 } }).trim({ threshold: 1 }).png().toFile(dst);
}

async function prepArt(build) {
  const dir = path.join(build, "art");
  await mkdir(dir, { recursive: true });
  for (const pose of POSES) {
    const dst = path.join(dir, `sol-${pose}.png`);
    if (await exists(dst)) continue;
    await cutout(path.join(ROOT, "design-assets/generated/tortoise", `sol-${pose}.png`), dst);
  }
  const grain = path.join(dir, "paper.jpg");
  if (!(await exists(grain))) {
    await sharp(path.join(ROOT, "design-assets/generated/paper-grain.png")).resize(1080, 1920, { fit: "cover" }).jpeg({ quality: 88 }).toFile(grain);
  }
}

async function prepFootage(ad) {
  const counts = {};
  for (const seg of SEGMENTS) {
    const dir = path.join(ad.build, "frames", seg.id);
    const n = Math.round((seg.to - seg.at) * FPS);
    counts[seg.id] = n;
    if ((await exists(dir)) && (await readdir(dir)).length >= n) continue;
    await mkdir(dir, { recursive: true });
    const srcDur = ((seg.to - seg.at) * seg.rate + 0.5).toFixed(3);
    await run("ffmpeg", [
      "-y", "-loglevel", "error", "-ss", String(seg.src), "-t", srcDur, "-i", path.join(ad.dir, "footage", `${seg.clip}.mov`),
      "-vf", `setpts=(PTS-STARTPTS)/${seg.rate},fps=${FPS},scale=828:-2:flags=lanczos`,
      "-q:v", "2", "-frames:v", String(n), path.join(dir, "%05d.jpg"),
    ]).done;
    console.log(`  frames ${seg.id}: ${n}`);
  }
  await writeFile(path.join(ad.build, "frames.json"), JSON.stringify(counts, null, 2));
}

export default async function prep(ad) {
  await mkdir(ad.build, { recursive: true });
  await prepArt(ad.build);
  await prepFootage(ad);
}
