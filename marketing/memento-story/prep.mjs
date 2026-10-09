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
