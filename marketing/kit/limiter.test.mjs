import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import test from "node:test";
import { LIMITER_FILTER } from "./voice.mjs";

test("the mix limiter keeps a loud signal at or below -1.4 dBFS", (t) => {
  const samples = execFileSync("ffmpeg", [
    "-hide_banner", "-loglevel", "error", "-f", "lavfi",
    "-i", "sine=frequency=1000:duration=0.2:sample_rate=48000",
    "-af", `volume=8,${LIMITER_FILTER}`, "-f", "f32le", "-",
  ]);
  assert.ok(samples.length > 0, "ffmpeg produced audio samples");
  let peak = 0;
  for (let i = 0; i < samples.length; i += 4) peak = Math.max(peak, Math.abs(samples.readFloatLE(i)));
  const peakDBFS = 20 * Math.log10(peak);
  t.diagnostic(`sample peak: ${peakDBFS.toFixed(6)} dBFS`);
  assert.ok(Number.isFinite(peakDBFS), "sample peak is finite");
  assert.ok(peakDBFS <= -1.4, `sample peak ${peakDBFS.toFixed(6)} dBFS exceeds -1.4 dBFS`);
  assert.ok(peakDBFS >= -1.5, "loud signal reaches the limiter ceiling");
});

test("importing voice does not run its CLI", () => {
  const result = spawnSync(process.execPath, ["--input-type=module", "-e",
    `await import(${JSON.stringify(new URL("./voice.mjs", import.meta.url).href)})`,
  ], { encoding: "utf8", env: { ...process.env, VOICE_OFFLINE: "1", ELEVENLABS_API_KEY: "" } });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "");
  assert.equal(result.stderr, "");
});
