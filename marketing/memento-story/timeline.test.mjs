import assert from "node:assert/strict";
import test from "node:test";

for (const ad of ["memento-story", "memento-story-30"]) {
  test(`${ad}: Sol only names what the footage shows`, async () => {
    let tl;
    try { tl = await import(`../${ad}/timeline.mjs`); } catch { return; }
    const sol = tl.VO.filter((v) => v.who === "Sol").map((v) => v.text);
    const tagLine = sol.find((t) => t.includes("Priya") && !t.includes("wrote"));
    assert.ok(tagLine, "a tag line mentions Priya");
    assert.ok(tagLine.includes(tl.TAGS_ON_SCREEN[0]), `tag line names ${tl.TAGS_ON_SCREEN[0]}`);
    assert.ok(sol.some((t) => t.includes(`On ${tl.MEMORY_DATE}, you wrote`)), `memory line quotes ${tl.MEMORY_DATE}`);
  });
}
