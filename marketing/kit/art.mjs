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
