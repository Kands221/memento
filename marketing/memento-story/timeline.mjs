// The Memento story (v2), 60 s, 1920×1080: every shot, footage cut, Sol move, cue and line is timed here.
// Footage: the approved simulator takes (Scene2Write, Scene4SolC) with live on-device AI; spoken input simulated.

export const NAME = "memento-story";
export const FPS = 30;
export const DURATION = 60;
export const WIDTH = 1920;
export const HEIGHT = 1080;
export const COVER_T = 26.9;

export const DOC = {
  title: "Memento story",
  notes: ["Her is the writer's inner voice; Sol is the paper tortoise. Footage is the real app with live on-device AI."],
  rules: [
    "Only show what the app does live; voice lines quote only what is on screen.",
    "No Paint this day, no airplane mode, no claims about other phones.",
    "No em-dashes in visible copy.",
  ],
};

// What the footage shows (checked against stills in Task 5). Sol's lines must agree with these.
export const TAGS_ON_SCREEN = ["Drained", "Walking helped", "Work"];
export const MEMORY_DATE = "Sep 13";

// Paper-world anchors, as fractions of the frame (from design-assets/briefs/wave5-story.md, 1536×864 crop).
export const ANCHORS = {
  journal: { x: 0.150, y: 0.655 },
  clock: { x: 0.189, y: 0.607 },
  moon: { x: 0.300, y: 0.115 },
  herNight: { x: 0.280, y: 0.590 },
  herSitting: { x: 0.312, y: 0.405 },
  besideHer: { x: 0.235, y: 0.700 },
  flashCorner: { x: 0.110, y: 0.930 },
  pathStart: { x: 0.080, y: 0.880 },
  pathEnd: { x: 0.260, y: 0.880 },
  endSol: { x: 0.300, y: 0.860 },
};

// Paper-world shots. `enter`/`exit`: "fade" or the flashback's "unfold"/"fold" (from the open journal).
export const SCENES = [
  { id: "night", img: "story-night", from: 0, to: 5.6, drift: [0, 0, 1.0, -1, 0, 1.04], grade: "night" },
  { id: "writing", img: "story-writing", from: 5.0, to: 22.8, drift: [-1, 0, 1.04, 0, -1, 1.07], grade: "night", enter: "fade" },
  { id: "dusk", img: "story-dusk", from: 22.0, to: 34.6, drift: [1, 0, 1.06, -1, 0, 1.0], grade: "dusk", enter: "unfold", exit: "fold" },
  { id: "writing2", img: "story-writing", from: 34.0, to: 43.6, drift: [0, -1, 1.07, 0, 0, 1.05], grade: "night" },
  { id: "dawn", img: "story-dawn", from: 42.4, to: 47.8, drift: [0, 0, 1.05, 1, 0, 1.02], grade: "dawn", enter: "fade" },
  { id: "morning", img: "story-morning", from: 47.0, to: 60, drift: [-2, 0, 1.0, 1, 0, 1.06], grade: "day", enter: "fade" },
];

// The phone (right third). Footage segments must be contiguous from PHONE.in to PHONE.out.
export const PHONE = { in: 5.2, out: 42.6, x: 0.785, y: 0.5, h: 0.89, tilt: -7, glow: true };

// Measured by eye on the approved takes (see Task 5, Step 2, to re-measure after any re-record).
export const SEGMENTS = [
  { id: "writeOpen", clip: "Scene2Write", at: 5.2, to: 6.8, src: 12.6, rate: 2.0 },
  { id: "typing", clip: "Scene2Write", at: 6.8, to: 10.6, src: 16.4, rate: 8.5 },
  { id: "finding", clip: "Scene2Write", at: 10.6, to: 11.8, src: 50.2, rate: 1 },
  { id: "tags", clip: "Scene2Write", at: 11.8, to: 16.2, src: 51.5, rate: 1 },
  { id: "solOpen", clip: "Scene4SolC", at: 16.2, to: 17.8, src: 20.2, rate: 1 },
  { id: "solListen", clip: "Scene4SolC", at: 17.8, to: 21.6, src: 23.6, rate: 1 },
  { id: "solThink", clip: "Scene4SolC", at: 21.6, to: 22.6, src: 28.2, rate: 1 },
  { id: "solReply", clip: "Scene4SolC", at: 22.6, to: 29.0, src: 31.3, rate: 1 },
  { id: "solHold", clip: "Scene4SolC", at: 29.0, to: 33.6, src: 37.3, rate: 0.45 },
  { id: "solSecond", clip: "Scene4SolC", at: 33.6, to: 37.4, src: 39.4, rate: 1 },
  { id: "solReply2", clip: "Scene4SolC", at: 37.4, to: 40.0, src: 53.5, rate: 1 },
  { id: "reflection", clip: "Scene4SolC", at: 40.0, to: 42.6, src: 65.4, rate: 1 },
];

// Sol in the world: keyframes, interpolated between `t`s. `mode`: "hidden", "peek" (rising from the journal), "idle",
// "walk". Positions are his feet (bottom centre).
export const SOL = [
  { t: 0, mode: "hidden", pose: "listening", at: "journal", w: 0.10 },
  { t: 9.2, mode: "peek", pose: "listening", at: "journal", w: 0.10 },
  { t: 10.4, mode: "idle", pose: "mark", at: "journal", w: 0.10 },
  { t: 16.2, mode: "idle", pose: "listening", at: "besideHer", w: 0.115 },
  { t: 21.6, mode: "idle", pose: "thinking", at: "besideHer", w: 0.115 },
  { t: 22.4, mode: "idle", pose: "reflect", at: "flashCorner", w: 0.13 },
  { t: 34.4, mode: "idle", pose: "listening", at: "besideHer", w: 0.115 },
  { t: 37.6, mode: "idle", pose: "mark", at: "besideHer", w: 0.115 },
  { t: 42.4, mode: "idle", pose: "resting", at: "journal", w: 0.10 },
  { t: 47.4, mode: "walk", pose: "mark", at: "pathStart", w: 0.095 },
  { t: 55.0, mode: "walk", pose: "mark", at: "pathEnd", w: 0.095 },
  { t: 55.4, mode: "idle", pose: "hello", at: "endSol", w: 0.21 },
];

// Small feature chips beside the phone.
export const CHIPS = [
  { from: 11.8, to: 16.2, text: "Tags from your words · on device" },
  { from: 22.6, to: 29.0, text: "Sol remembers" },
  { from: 40.0, to: 42.6, text: "A reflection in your words" },
];

export const T = { clockOut: 5.6, wordmarkIn: 16.4, wordmarkOut: 21.0, chip: 26.8, zoomIn: 25.9, zoomOut: 28.8, end: 55.2 };

// kind: tap | pop | bloop | receive | whoosh | buzz | ding | sparkle | tick | check
export const SFX = [
  ...[0.3, 1.3, 2.3, 3.3, 4.3].map((t) => ({ t, kind: "tick", gain: 0.22 })),
  { t: 5.35, kind: "tap", gain: 0.4 },
  { t: 9.2, kind: "whoosh", gain: 0.22, dur: 0.35 },
  { t: 11.85, kind: "ding", gain: 0.28 },
  { t: 17.85, kind: "tap", gain: 0.4 },
  { t: 22.0, kind: "whoosh", gain: 0.3, dur: 0.7 },
  { t: T.chip, kind: "sparkle", gain: 0.35 },
  { t: 33.65, kind: "tap", gain: 0.4 },
  { t: 34.0, kind: "whoosh", gain: 0.26, dur: 0.6 },
  { t: 42.6, kind: "whoosh", gain: 0.3, dur: 0.5 },
  { t: T.end + 0.2, kind: "ding", gain: 0.4 },
];

export const VOICES = {
  model: "eleven_multilingual_v2",
  settings: { stability: 0.5, similarity_boost: 0.8, style: 0.3, use_speaker_boost: true, speed: 1.0 },
  Sol: { id: "0lp4RIz96WD1RUtvEu3Q", name: "Grandfather Joe, Gentle, Warm" },
  Her: { id: "cgSgspJ2msm6clMCkdW9", name: "Jessica, Playful, Bright, Warm",
         settings: { stability: 0.35, similarity_boost: 0.8, style: 0.45, use_speaker_boost: true, speed: 0.95 } },
};

export const VO = [
  { from: 0.4, to: 5.0, who: "Her", note: "2 a.m., tired, quiet, to herself",
    text: "It's 2 a.m. Work's been a lot, and I can't switch off.",
    say: "It's two a.m. Work's been a lot, and I can't switch off." },
  { from: 11.9, to: 17.9, who: "Sol", note: "gentle, noticing",
    text: "Drained. Work. And a walk with Priya that helped. Shall we keep those?",
    say: "Drained. Work. And a walk with Priya that helped. Shall we keep those?" },
  { from: 18.5, to: 22.4, who: "Her", note: "honest, to a friend",
    text: "Work stress is back this week. What helped me last time?",
    say: "Work stress is back this week. What helped me last time?" },
  { from: 22.7, to: 33.9, who: "Sol", note: "remembering fondly",
    text: "On Sep 13, you wrote: “Long walk with Priya after work.”",
    say: "On September thirteenth, you wrote: long walk with Priya, after work." },
  { from: 34.1, to: 37.5, who: "Her", note: "a small smile",
    text: "Maybe I'll text Priya. We can walk tomorrow.",
    say: "Maybe I'll text Priya. We can walk tomorrow." },
  { from: 37.6, to: 42.8, who: "Sol", note: "warm",
    text: "A kind next step, I think.",
    say: "A kind next step, I think." },
  { from: 43.0, to: 55.2, who: "Sol", note: "sincere, the heart of it",
    text: "A journal holds your most private words. So everything I do stays on your iPhone. No servers, no account. Even offline.",
    say: "A journal holds your most private words. So everything I do stays on your iPhone. No servers, no account. Even offline." },
  { from: 55.4, to: 59.6, who: "Sol", note: "warm close",
    text: "Your words stay yours.",
    say: "Your words stay yours." },
];
