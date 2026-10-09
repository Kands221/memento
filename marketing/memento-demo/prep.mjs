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
