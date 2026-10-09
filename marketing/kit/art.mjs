// Art helpers shared by ads: cut a paper-backed illustration out of its paper, and a paper texture plate.
import path from "node:path";
import sharp from "sharp";
import { ROOT } from "./render.mjs";

// Flood-fills the paper from the edges (so cream inside the subject stays), feathering the boundary.
// `defringe` also clears small enclosed paper pockets and pulls the alpha edge inward for dark scenes.
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
  while (!defringe && queue.length) {
    const p = queue.pop();
    if (seen[p]) continue;
    const d = dist(p * 4);
    if (d >= SOFT) continue;
    seen[p] = 1;
    let a = d <= HARD ? 0 : Math.round(((d - HARD) / (SOFT - HARD)) * 255);
    data[p * 4 + 3] = a;
    const x = p % w;
    const y = (p / w) | 0;
    if (x > 0) queue.push(p - 1);
    if (x < w - 1) queue.push(p + 1);
    if (y > 0) queue.push(p - w);
    if (y < h - 1) queue.push(p + w);
  }
  if (defringe) {
    // A tighter paper match preserves light sage and cream details. Warm neutral shadows are paper too.
    const paperMask = new Uint8Array(w * h);
    for (let p = 0; p < w * h; p++) {
      const i = p * 4;
      const lo = Math.min(data[i], data[i + 1], data[i + 2]);
      const hi = Math.max(data[i], data[i + 1], data[i + 2]);
      paperMask[p] = dist(i) <= HARD || (data[i] >= data[i + 1] && lo > 170 && hi - lo < 12) ? 1 : 0;
    }
    // Keep large enclosed cream areas (journal pages) and tiny paper-grain highlights.
    const maxPocket = Math.max(64, w * h * 0.002);
    for (let p = 0; p < w * h; p++) {
      if (!paperMask[p]) continue;
      const region = [p];
      let exterior = false;
      paperMask[p] = 0;
      for (let k = 0; k < region.length; k++) {
        const q = region[k], x = q % w, y = (q / w) | 0;
        exterior ||= x === 0 || x === w - 1 || y === 0 || y === h - 1;
        const neighbours = [x > 0 ? q - 1 : -1, x < w - 1 ? q + 1 : -1, y > 0 ? q - w : -1, y < h - 1 ? q + w : -1];
        for (const n of neighbours) if (n >= 0 && paperMask[n]) { paperMask[n] = 0; region.push(n); }
      }
      if (region.length >= 16 && (exterior || region.length <= maxPocket)) for (const q of region) data[q * 4 + 3] = 0;
    }
    // Remove two source pixels of colour contaminated by the light paper, including around enclosed holes.
    // The ordinary paper-backed cutout path above is unchanged.
    for (let pass = 0; pass < 2; pass++) {
      const alpha = Uint8Array.from({ length: w * h }, (_, p) => data[p * 4 + 3]);
      for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
        const p = y * w + x;
        if (!alpha[p]) continue;
        let a = alpha[p];
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) a = Math.min(a, alpha[p + dy * w + dx]);
        data[p * 4 + 3] = a;
      }
    }
  }
  await sharp(data, { raw: { width: w, height: h, channels: 4 } }).trim({ threshold: 1 }).png().toFile(dst);
}

export async function paper(dst, width, height) {
  await sharp(path.join(ROOT, "design-assets/generated/paper-grain.png")).resize(width, height, { fit: "cover" }).jpeg({ quality: 88 }).toFile(dst);
}
