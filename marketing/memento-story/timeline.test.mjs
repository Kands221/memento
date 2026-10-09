import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import test from "node:test";

for (const ad of ["memento-story", "memento-story-30"]) {
  const file = new URL(`../${ad}/timeline.mjs`, import.meta.url);
  test(`${ad}: Sol only names what the footage shows`, { skip: ad === "memento-story-30" && !existsSync(file) }, async () => {
    const tl = await import(file.href);
    const sol = tl.VO.filter((v) => v.who === "Sol").map((v) => v.text);
    const tagLine = sol.find((t) => t.includes("Priya") && !t.includes("wrote"));
    assert.ok(tagLine, "a tag line mentions Priya");
    assert.ok(tagLine.includes(tl.TAGS_ON_SCREEN[0]), `tag line names ${tl.TAGS_ON_SCREEN[0]}`);
    assert.ok(sol.some((t) => t.includes(`On ${tl.MEMORY_DATE}, you wrote`)), `memory line quotes ${tl.MEMORY_DATE}`);
  });
}
