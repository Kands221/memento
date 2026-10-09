import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import sharp from "sharp";
import { chromium } from "@playwright/test";
import { loadAd } from "../kit/render.mjs";
import { cutout } from "../kit/art.mjs";

// Opens the scene through the kit's static server and checks pure-function behaviour at given times.
async function withScene(fn) {
  const { serveForTest } = await import("../kit/render.mjs");
  const ad = await loadAd("memento-story");
  const { server, base } = await serveForTest(ad.folder);
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.goto(`${base}?t=0`, { waitUntil: "networkidle" });
    await page.evaluate(() => window.__ready);
    await fn(page);
    assert.deepEqual(errors, []);
  } finally {
    await browser.close();
    server.close();
  }
}

test("every voice line's subtitle shows at its middle", async () => {
  const timing = JSON.parse(readFileSync(new URL("./build/vo-timing.json", import.meta.url), "utf8"));
  await withScene(async (page) => {
    for (const line of timing) {
      const mid = (line.start + line.out) / 2;
      assert.equal(await page.evaluate((t) => window.subtitleAt(t), mid), line.text);
    }
  });
});

test("every half second renders without errors and with a phone frame while the phone is up", async () => {
  await withScene(async (page) => {
    for (let t = 0; t < 60; t += 0.5) {
      await page.evaluate((x) => window.renderAt(x), t);
      const src = await page.evaluate(() => document.querySelector("#screen").getAttribute("src") ?? "");
      if (t >= 5.6 && t < 42.4) assert.match(src, /build\/frames\//, `phone frame at ${t}s`);
    }
  });
});

// Ignore fully transparent layers when hit-testing the painted scene.
async function topmostAtCentre(page, selector) {
  return page.evaluate((selector) => {
    const transparent = [...document.querySelectorAll("body *")]
      .filter((el) => Number(getComputedStyle(el).opacity) === 0);
    const previous = transparent.map((el) => el.style.pointerEvents);
    transparent.forEach((el) => { el.style.pointerEvents = "none"; });
    try {
      const target = document.querySelector(selector);
      const { x, y, width, height } = target.getBoundingClientRect();
      const top = document.elementFromPoint(x + width / 2, y + height / 2);
      return top?.closest(selector)?.id || top?.id || top?.className;
    } finally {
      transparent.forEach((el, i) => { el.style.pointerEvents = previous[i]; });
    }
  }, selector);
}

test("phone footage is painted above the paper world", async () => {
  await withScene(async (page) => {
    for (const t of [7.5, 12.5, 26.9]) {
      await page.evaluate((x) => window.renderAt(x), t);
      assert.equal(await topmostAtCentre(page, "#screen"), "screen", `visible phone at ${t}s`);
    }
  });
});

test("burned-in subtitles are painted above the paper world", async () => {
  await withScene(async (page) => {
    await page.evaluate(() => window.renderAt(1.5));
    assert.equal(await topmostAtCentre(page, "#subs"), "subs", "visible subtitle during the opening line");
  });
});

test("paper scenes cover every frame edge throughout the camera drift", async () => {
  await withScene(async (page) => {
    for (let t = 0; t < 60; t += 0.5) {
      await page.evaluate((x) => window.renderAt(x), t);
      const covered = await page.evaluate(() => [[0, 0], [1919, 0], [0, 1079], [1919, 1079]]
        .every(([x, y]) => document.elementsFromPoint(x, y).some((el) => el.matches(".shot") && Number(getComputedStyle(el).opacity) > 0)));
      assert.ok(covered, `paper covers every corner at ${t}s`);
    }
  });
});

test("subtitles never cover Sol", async () => {
  await withScene(async (page) => {
    for (let t = 0; t < 60; t += 0.5) {
      await page.evaluate((x) => window.renderAt(x), t);
      const overlap = await page.evaluate(() => {
        const sol = document.querySelector("#sol");
        const subs = document.querySelector("#subs");
        if (getComputedStyle(sol).display === "none" || Number(getComputedStyle(subs).opacity) === 0) return false;
        const a = sol.getBoundingClientRect();
        return [...subs.querySelector("span").getClientRects()].some((b) => a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top);
      });
      assert.equal(overlap, false, `Sol is clear of subtitle pills at ${t}s`);
    }
  });
});

test("Sol speaks awake on the nightstand until the morning cut", async () => {
  await withScene(async (page) => {
    const positions = [];
    for (const t of [43.5, 46, 47]) {
      await page.evaluate((x) => window.renderAt(x), t);
      const sol = await page.evaluate(() => {
        const el = document.querySelector("#sol");
        const box = el.getBoundingClientRect();
        const pose = [...el.querySelectorAll("img")].find((img) => Number(getComputedStyle(img).opacity) === 1)?.dataset.pose;
        return { left: box.left, right: box.right, feet: box.bottom, pose };
      });
      assert.notEqual(sol.pose, "resting", `awake speaking pose at ${t}s`);
      assert.ok(sol.left >= 90 && sol.right <= 450 && sol.feet >= 675 && sol.feet <= 730, `feet on the nightstand at ${t}s: ${JSON.stringify(sol)}`);
      positions.push(sol);
    }
    assert.ok(Math.max(...positions.map((s) => s.left)) - Math.min(...positions.map((s) => s.left)) < 10, "no slide across furniture before the cut");
  });
});

test("end-card Sol waves fully visible above the veil", async () => {
  await withScene(async (page) => {
    await page.evaluate(() => window.renderAt(57.5));
    const opacity = await page.evaluate(() => {
      let value = 1;
      for (let el = document.querySelector('#sol img[data-pose="hello"]'); el; el = el.parentElement) value *= Number(getComputedStyle(el).opacity);
      return value;
    });
    assert.equal(opacity, 1);
    assert.equal(await topmostAtCentre(page, "#sol"), "sol");
  });
});

test("defringe clears enclosed paper while ordinary cutouts retain it", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "memento-cutout-"));
  try {
    const src = path.join(dir, "ring.png");
    const data = Buffer.alloc(32 * 32 * 3);
    for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) {
      const ring = x >= 6 && x < 26 && y >= 6 && y < 26 && !(x >= 12 && x < 20 && y >= 12 && y < 20);
      const hole = x >= 12 && x < 20 && y >= 12 && y < 20;
      data.set(ring ? [70, 100, 60] : hole ? [212, 211, 206] : [246, 241, 231], (y * 32 + x) * 3);
    }
    await sharp(data, { raw: { width: 32, height: 32, channels: 3 } }).png().toFile(src);
    for (const defringe of [false, true]) {
      const dst = path.join(dir, `${defringe}.png`);
      await cutout(src, dst, { defringe });
      const { data, info } = await sharp(dst).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      const middle = (Math.floor(info.height / 2) * info.width + Math.floor(info.width / 2)) * 4;
      assert.equal(data[middle + 3], defringe ? 0 : 255, `enclosed paper alpha with defringe=${defringe}`);
      assert.ok(data.some((value, i) => i % 4 === 3 && value === 255), "the coloured ring remains opaque");
    }
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("defringe preserves pale sage details and large enclosed cream pages", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "memento-cream-"));
  try {
    const src = path.join(dir, "details.png");
    const dst = path.join(dir, "cutout.png");
    const data = Buffer.alloc(64 * 64 * 3);
    for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) {
      let rgb = [246, 241, 231];
      if (x >= 6 && x < 58 && y >= 6 && y < 58) rgb = [70, 100, 60];
      if (x >= 12 && x < 30 && y >= 12 && y < 30) rgb = [232, 236, 223];
      if (x >= 34 && x < 52 && y >= 34 && y < 52) rgb = [246, 241, 231];
      data.set(rgb, (y * 64 + x) * 3);
    }
    await sharp(data, { raw: { width: 64, height: 64, channels: 3 } }).png().toFile(src);
    await cutout(src, dst, { defringe: true });
    const { data: pixels } = await sharp(dst).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    for (const [name, colour] of [["pale sage", [232, 236, 223]], ["cream page", [246, 241, 231]]]) {
      let opaque = 0;
      for (let i = 0; i < pixels.length; i += 4) if (colour.every((v, k) => pixels[i + k] === v) && pixels[i + 3] === 255) opaque++;
      assert.ok(opaque >= 200, `${name} remains an opaque illustrated region, got ${opaque} pixels`);
    }
  } finally { await rm(dir, { recursive: true, force: true }); }
});
