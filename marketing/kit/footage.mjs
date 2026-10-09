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
