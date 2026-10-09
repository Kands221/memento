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
