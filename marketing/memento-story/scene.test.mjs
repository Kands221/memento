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
async function withScene(fn, { adName = "memento-story", beforeLoad, ready = true } = {}) {
  const { serveForTest } = await import("../kit/render.mjs");
  const ad = await loadAd(adName);
  const { server, base } = await serveForTest(ad.folder);
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await beforeLoad?.(page);
    await page.goto(`${base}?t=0`, { waitUntil: "networkidle" });
    if (ready) await page.evaluate(() => window.__ready);
    await fn(page, ad);
    if (ready) assert.deepEqual(errors, []);
  } finally {
    await browser.close();
    server.close();
  }
}

for (const [adName, boundary] of [["memento-story", 55], ["memento-story-30", 26.8]]) {
  test(`${adName}: Sol stays opaque across a position-only keyframe`, async () => {
    await withScene(async (page) => {
      for (let frame = -6; frame <= 12; frame++) {
        const t = (Math.round(boundary * 30) + frame) / 30;
        await page.evaluate((t) => window.renderAt(t), t);
        const opacity = await page.evaluate(() => [...document.querySelectorAll("#sol img")].reduce((sum, img) => {
          let opacity = 1;
          for (let el = img; el; el = el.parentElement) opacity *= Number(getComputedStyle(el).opacity);
          return sum + opacity;
        }, 0));
        assert.ok(Math.abs(opacity - 1) < 0.000001, `Sol effective opacity at ${t}s: ${opacity}`);
      }
    }, { adName });
  });
}

for (const [asset, status] of [["story-night.jpg", 404], ["sol-hello.png", 200]]) {
  test(`required-art readiness rejects ${status === 404 ? "missing" : "corrupt"} ${asset} with its URL`, async () => {
    await withScene(async (page) => {
      await assert.rejects(page.evaluate(() => window.__ready), (error) => {
        assert.match(error.message, /Required image failed to decode:/);
        assert.ok(error.message.includes(`/build/art/${asset}`), error.message);
        return true;
      });
    }, {
      ready: false,
      beforeLoad: (page) => page.route(`**/build/art/${asset}`, (route) => route.fulfill({ status, contentType: "image/png", body: "invalid image" })),
    });
  });
}

test("required-art readiness exempts only the empty initial phone image", async () => {
  await withScene(async (page) => {
    assert.equal(await page.locator("#screen").getAttribute("src"), null);
    await assert.rejects(page.evaluate(() => window.renderAt(5.6)), /Required image failed to decode: .*\/build\/frames\/writeOpen\//);
  }, { beforeLoad: (page) => page.route("**/build/frames/**", (route) => route.fulfill({ status: 404, body: "" })) });
});

for (const adName of ["memento-story", "memento-story-30"]) {
  test(`${adName}: lighting follows the timeline's night and dawn scenes`, async () => {
    await withScene(async (page, { tl }) => {
      const lightsAt = async (t) => {
        await page.evaluate((t) => window.renderAt(t), t);
        return page.evaluate(() => Object.fromEntries(["moon", "glow", "sunrise"].map((id) => [id, Number(getComputedStyle(document.getElementById(id)).opacity)])));
      };
      for (const scene of tl.SCENES) {
        const t = (scene.from + scene.to) / 2;
        const lights = await lightsAt(t);
        for (const light of ["moon", "glow"]) {
          if (scene.grade === "night") assert.ok(lights[light] > 0, `${light} on during ${scene.id} at ${t}s`);
          else assert.equal(lights[light], 0, `${light} off during ${scene.id} at ${t}s`);
        }
        if (scene.grade === "dawn") assert.ok(lights.sunrise > 0, `sunrise during ${scene.id}`);
      }
      const dawn = tl.SCENES.filter((scene) => scene.grade === "dawn");
      const samples = new Set([...Array.from({ length: tl.DURATION * 2 }, (_, i) => i / 2), ...dawn.flatMap((s) => [s.from - 0.01, s.to, s.to + 0.01])]);
      for (const t of samples) {
        if (dawn.some((s) => t >= s.from && t < s.to)) continue;
        assert.equal((await lightsAt(t)).sunrise, 0, `no sunrise outside a dawn scene at ${t}s`);
      }
      await page.evaluate((t) => window.renderAt(t), tl.T.clockOut + 0.2);
      const glowLeft = await page.locator("#glow").evaluate((el) => parseFloat(el.style.left));
      assert.ok(Math.abs(glowLeft - (tl.ANCHORS.herSitting.x * tl.WIDTH - 380)) < 0.01, "glow follows the seated writer after the opening scene");
    }, { adName });
  });
}

for (const adName of ["memento-story", "memento-story-30"]) {
  test(`${adName}: phone pushes in only during tags and journal windows`, async () => {
    await withScene(async (page, { tl }) => {
      const zoomAt = async (t) => {
        await page.evaluate((t) => window.renderAt(t), t);
        return page.locator("#phone").evaluate((el) => Number(el.style.transform.match(/scale\(([^)]+)\)/)[1]));
      };
      const tags = tl.SEGMENTS.find((s) => s.id === "tags");
      assert.ok(await zoomAt((tags.at + tags.to) / 2) > 1, "push in while the real tags are visible");
      assert.deepEqual(tl.T.zoomWindows.map((w) => w.id), ["tags", "journal"]);
      for (const window of tl.T.zoomWindows) {
        for (const t of [window.in + 0.4, (window.in + window.out) / 2, window.out + 0.25]) {
          assert.ok(await zoomAt(t) > 1, `${window.id} zoom inside its window at ${t}s`);
        }
        for (const t of [window.in - 0.1, window.in, window.out + 0.5, window.out + 0.6]) {
          assert.equal(await zoomAt(t), 1, `${window.id} zoom outside its window at ${t}s`);
        }
      }
      const tagWindow = tl.T.zoomWindows.find((w) => w.id === "tags");
      assert.ok(tagWindow.in >= tags.at && tagWindow.out + 0.5 <= tags.to, "tags push-in stays within the measured tags footage");
    }, { adName });
  });
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
