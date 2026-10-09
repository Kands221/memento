import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, rmSync } from "node:fs";
import test from "node:test";
import * as voice from "./voice.mjs";

test("music filter preserves the existing defaults exactly", () => {
  assert.equal(typeof voice.musicFilter, "function", "exports the music filter builder");
  assert.equal(voice.musicFilter({ DURATION: 60 }),
    "[3:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=0.32,afade=t=in:d=1.2,afade=t=out:st=57.50:d=2.5[mus];");
  assert.equal(voice.musicFilter({ DURATION: 30, MUSIC: {} }),
    "[3:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=0.32,afade=t=in:d=1.2,afade=t=out:st=27.50:d=2.5[mus];");
});

test("music filter delays both channels and fades at the cut's endpoint", () => {
  assert.equal(typeof voice.musicFilter, "function", "exports the music filter builder");
  assert.equal(voice.musicFilter({ DURATION: 30, MUSIC: { delay: 1.6, fadeOut: 1 } }),
    "[3:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=0.32,afade=t=in:d=1.2,adelay=1600:all=1,afade=t=out:st=29.00:d=1[mus];");
  assert.equal(voice.musicFilter({ DURATION: 30, MUSIC: { delay: 1.6 } }),
    "[3:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=0.32,afade=t=in:d=1.2,adelay=1600:all=1,afade=t=out:st=27.50:d=2.5[mus];");
  assert.equal(voice.musicFilter({ DURATION: 30, MUSIC: { fadeOut: 1 } }),
    "[3:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=0.32,afade=t=in:d=1.2,afade=t=out:st=29.00:d=1[mus];");
});

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
