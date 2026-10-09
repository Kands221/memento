import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import test from "node:test";

// memento-demo's clips are cached in build/vo, so this spends no ElevenLabs characters.
test("--clips-only writes speech timings without a render", () => {
  execFileSync("node", ["kit/voice.mjs", "memento-demo", "--clips-only"], { env: { ...process.env, ELEVENLABS_API_KEY: process.env.ELEVENLABS_API_KEY ?? "cached-only" } });
  const timing = JSON.parse(readFileSync("memento-demo/build/vo-timing.json", "utf8"));
  assert.equal(timing.length, 9);
  for (const line of timing) {
    assert.ok(line.out > line.start, `line ${line.index} ends after it starts`);
    assert.equal(typeof line.text, "string");
  }
  assert.equal(timing[0].who, "Sol");
});
