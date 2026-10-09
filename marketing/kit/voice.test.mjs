import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, rmSync } from "node:fs";
import test from "node:test";

// Optional integration check: cached clips only, with paid synthesis disabled.
test("--clips-only writes speech timings without a render", { skip: !existsSync("memento-demo/build/vo") }, () => {
  rmSync("memento-demo/build/vo-timing.json", { force: true });
  execFileSync(process.execPath, ["kit/voice.mjs", "memento-demo", "--clips-only"], {
    env: { ...process.env, VOICE_OFFLINE: "1", ELEVENLABS_API_KEY: "" },
  });
  const timing = JSON.parse(readFileSync("memento-demo/build/vo-timing.json", "utf8"));
  assert.equal(timing.length, 9);
  for (const line of timing) {
    assert.ok(line.out > line.start, `line ${line.index} ends after it starts`);
    assert.equal(typeof line.text, "string");
  }
  assert.equal(timing[0].who, "Sol");
});
