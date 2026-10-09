import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { loadAd, writeDocs } from "./render.mjs";

async function docsFor(ad) {
  const dir = await mkdtemp(path.join(os.tmpdir(), "memento-render-docs-"));
  try {
    await writeDocs({ ...ad, dir });
    return await readFile(path.join(dir, "vo-script.md"), "utf8");
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

for (const adName of ["memento-story", "memento-story-30"]) {
  test(`${adName}: docs omit absent captions`, async () => {
    const ad = await loadAd(adName);
    const md = await docsFor(ad);
    assert.doesNotMatch(md, /On-screen captions/);
    assert.ok(md.includes(ad.tl.VO[0].text), "voice script is still included");
  });
}

test("landscape docs use the ad's aspect in prose and video paths", async () => {
  const ad = await loadAd("memento-story");
  const md = await docsFor({ ...ad, tl: { ...ad.tl, CAPTIONS: [] } });
  assert.match(md, /Total runtime 60s, 16:9/);
  assert.match(md, /out\/memento-story-16x9-vo\.mp4/);
  assert.doesNotMatch(md, /9:16|9x16/);
});

test("portrait docs retain their captions and aspect", async () => {
  const md = await docsFor(await loadAd("memento-demo"));
  assert.match(md, /On-screen captions/);
  assert.match(md, /9:16/);
  assert.match(md, /out\/memento-demo-9x16-vo\.mp4/);
});
