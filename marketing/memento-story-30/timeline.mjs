// The 30 s cut of the Memento story: hook, tags, the question and the Priya flashback, why local, end card.
export { FPS, WIDTH, HEIGHT, ANCHORS, VOICES, TAGS_ON_SCREEN, MEMORY_DATE } from "../memento-story/timeline.mjs";
export const NAME = "memento-story-30";
export const DURATION = 30;
export const MUSIC = { delay: 4.6, fadeOut: 1.0 };
export const COVER_T = 15.6;
export const DOC = { title: "Memento story (30 s)", notes: [], rules: ["Same rules as the 60 s master."] };

export const SCENES = [
  { id: "night", img: "story-night", from: 0, to: 4.4, drift: [0, 0, 1.0, -1, 0, 1.03], grade: "night" },
  { id: "writing", img: "story-writing", from: 3.8, to: 10.2, drift: [-1, 0, 1.04, 0, -1, 1.06], grade: "night", enter: "fade" },
  { id: "dusk", img: "story-dusk", from: 9.4, to: 20.8, drift: [1, 0, 1.06, -1, 0, 1.0], grade: "dusk", enter: "unfold" },
  { id: "morning", img: "story-morning", from: 20.0, to: 30, drift: [-2, 0, 1.0, 1, 0, 1.05], grade: "day", enter: "fade" },
];

export const PHONE = { in: 3.9, out: 20.4, x: 0.785, y: 0.5, h: 0.89, tilt: -7, glow: true };

export const SEGMENTS = [
  { id: "typing", clip: "Scene2Write", at: 3.9, to: 6.0, src: 16.4, rate: 15.4 },
  { id: "tags", clip: "Scene2Write", at: 6.0, to: 9.4, src: 51.5, rate: 1 },
  { id: "solListen", clip: "Scene4SolC", at: 9.4, to: 12.8, src: 24.0, rate: 1 },
  { id: "solThink", clip: "Scene4SolC", at: 12.8, to: 13.4, src: 28.2, rate: 1 },
  { id: "solReply", clip: "Scene4SolC", at: 13.4, to: 20.4, src: 31.3, rate: 1 },
];

export const SOL = [
  { t: 0, mode: "hidden", pose: "listening", at: "journal", w: 0.10 },
  { t: 5.6, mode: "peek", pose: "listening", at: "journal", w: 0.10 },
  { t: 6.6, mode: "idle", pose: "mark", at: "journal", w: 0.10 },
  { t: 9.6, mode: "idle", pose: "reflect", at: "flashCorner", w: 0.13 },
  { t: 20.2, mode: "walk", pose: "mark", at: "pathStart", w: 0.095 },
  { t: 26.8, mode: "walk", pose: "mark", at: "pathEnd", w: 0.095 },
  { t: 27.2, mode: "idle", pose: "hello", at: "endSol", w: 0.21 },
];

export const CHIPS = [
  { from: 6.0, to: 9.4, text: "Tags from your words · on device" },
  { from: 13.4, to: 20.4, text: "Sol remembers" },
];

export const T = {
  clockOut: 4.4, wordmarkIn: 9.6, wordmarkOut: 12.6, chip: 17.6, end: 27.0,
  // The cached tags segment shows all three suggestions throughout 6.0–9.4 s.
  zoomWindows: [{ id: "tags", in: 6.0, out: 8.9 }, { id: "journal", in: 16.7, out: 20.0 }],
};

export const SFX = [
  ...[0.3, 1.3, 2.3, 3.3].map((t) => ({ t, kind: "tick", gain: 0.22 })),
  { t: 5.6, kind: "whoosh", gain: 0.22, dur: 0.35 },
  { t: 6.05, kind: "ding", gain: 0.28 },
  { t: 9.45, kind: "tap", gain: 0.4 },
  { t: 9.4, kind: "whoosh", gain: 0.3, dur: 0.7 },
  { t: T.chip, kind: "sparkle", gain: 0.35 },
  { t: 20.4, kind: "whoosh", gain: 0.3, dur: 0.5 },
  { t: T.end + 0.2, kind: "ding", gain: 0.4 },
];

export const VO = [
  { from: 0.3, to: 3.9, who: "Her", note: "2 a.m., tired", text: "It's 2 a.m., and I can't switch off.", say: "It's two a.m., and I can't switch off." },
  { from: 6.1, to: 9.5, who: "Sol", note: "gentle", text: "Drained. And a walk with Priya that helped.", say: "Drained. And a walk with Priya that helped." },
  { from: 9.8, to: 13.4, who: "Her", note: "honest", text: "Work stress is back this week. What helped me last time?", say: "Work stress is back this week. What helped me last time?" },
  { from: 13.5, to: 20.4, who: "Sol", note: "remembering fondly", text: "On Sep 13, you wrote: “Long walk with Priya after work.”", say: "On September thirteenth, you wrote: long walk with Priya, after work." },
  { from: 20.6, to: 27.0, who: "Sol", note: "sincere", text: "And everything I do stays on your iPhone. No servers. Even offline.", say: "And everything I do stays on your iPhone. No servers. Even offline." },
  { from: 27.3, to: 29.7, who: "Sol", note: "warm close", text: "Your words stay yours.", say: "Your words stay yours." },
];
