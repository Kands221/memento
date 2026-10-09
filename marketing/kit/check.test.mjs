import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import test from "node:test";
import { checkTimeline } from "./check.mjs";

const base = {
  DURATION: 10,
  VOICES: { Sol: { id: "a" }, Her: { id: "b" } },
  SCENES: [{ id: "night", from: 0, to: 10 }],
  SEGMENTS: [{ id: "x", at: 2, to: 4, src: 0, rate: 1 }, { id: "y", at: 4, to: 6, src: 0, rate: 1 }],
  VO: [{ from: 0.5, to: 3, who: "Her" }, { from: 3.2, to: 6, who: "Sol" }],
  SFX: [{ t: 1 }],
};

test("a clean timeline passes", () => assert.deepEqual(checkTimeline(base), []));
test("a gap between scenes is caught", () => {
  const tl = { ...base, SCENES: [{ id: "a", from: 0, to: 4 }, { id: "b", from: 4.5, to: 10 }] };
  assert.match(checkTimeline(tl).join("\n"), /gap/);
});
test("scenes must cover the whole duration", () => {
  assert.match(checkTimeline({ ...base, SCENES: [{ id: "a", from: 0, to: 9 }] }).join("\n"), /end/);
});
test("a gap between footage segments is caught", () => {
  const tl = { ...base, SEGMENTS: [{ id: "x", at: 2, to: 4, src: 0, rate: 1 }, { id: "y", at: 4.2, to: 6, src: 0, rate: 1 }] };
  assert.match(checkTimeline(tl).join("\n"), /segments x\/y/);
});
test("overlapping voice lines and unknown speakers are caught", () => {
  const tl = { ...base, VO: [{ from: 0.5, to: 4, who: "Her" }, { from: 3, to: 6, who: "Narrator" }] };
  const out = checkTimeline(tl).join("\n");
  assert.match(out, /overlap/);
  assert.match(out, /Narrator/);
});
test("cues outside the video are caught", () => {
  assert.match(checkTimeline({ ...base, SFX: [{ t: 12 }] }).join("\n"), /SFX/);
});
for (const ad of ["memento-demo", "memento-story", "memento-story-30"]) {
  const file = new URL(`../${ad}/timeline.mjs`, import.meta.url);
  test(`${ad} timeline is valid`, { skip: !existsSync(file) }, async () => {
    assert.deepEqual(checkTimeline(await import(file.href)), []);
  });
}
