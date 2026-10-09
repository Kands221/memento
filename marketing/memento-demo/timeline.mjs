// Single source of truth for the Memento demo: every footage cut, Sol pose, caption, sound cue and voiceover
// line is timed here, so a re-cut moves them together. Shared by scene.js (browser), prep.mjs and the kit.
//
// Footage is real: recorded from the iOS Simulator with the app's live on-device AI (Apple's Foundation Models
// on this Mac), by record.sh. Only the spoken input is simulated, because the Simulator has no working speech
// model; on an iPhone the same words come from on-device dictation.

export const NAME = "memento-demo";
export const FPS = 30;
export const DURATION = 58;
export const WIDTH = 1080;
export const HEIGHT = 1920;
export const COVER_T = 34.9;

export const DOC = {
  title: "Memento demo",
  notes: [
    "Sol, the old paper tortoise, narrates. The writer's line to Sol is a second voice.",
    "Footage is the real app in the iOS Simulator with live on-device AI; the spoken input is simulated there.",
  ],
  rules: [
    "Only show what the app does live: every reply, tag, reflection and look-back on screen was generated on device.",
    "Suggestions, not diagnosis. Sol is not a therapist.",
    "No claims about other phones: on-device Sol needs an Apple Intelligence iPhone.",
    "No em-dashes in visible copy.",
  ],
};

// Where each recorded clip lands in the video: [at, to) in video seconds, from `src` seconds of footage/<clip>.mov,
// played `rate` times faster.
export const SEGMENTS = [
  { id: "journal", clip: "Scene1Journal", at: 5.0, to: 8.6, src: 19.0, rate: 1 },
  { id: "typing", clip: "Scene2Write", at: 8.6, to: 12.6, src: 16.4, rate: 8.0 },
  { id: "finding", clip: "Scene2Write", at: 12.6, to: 13.8, src: 50.2, rate: 1 },
  { id: "tags", clip: "Scene2Write", at: 13.8, to: 18.8, src: 51.5, rate: 1 },
  { id: "find", clip: "Scene3FindAgain", at: 18.8, to: 23.6, src: 19.0, rate: 1 },
  { id: "solHello", clip: "Scene4SolC", at: 23.6, to: 25.6, src: 20.2, rate: 1 },
  { id: "solListen", clip: "Scene4SolC", at: 25.6, to: 29.6, src: 23.4, rate: 1 },
  { id: "solThink", clip: "Scene4SolC", at: 29.6, to: 30.6, src: 28.0, rate: 1 },
  { id: "solReply", clip: "Scene4SolC", at: 30.6, to: 36.6, src: 31.3, rate: 1 },
  { id: "reflectTap", clip: "Scene4SolC", at: 36.6, to: 37.5, src: 60.9, rate: 1 },
  { id: "reflection", clip: "Scene4SolC", at: 37.5, to: 41.0, src: 65.4, rate: 1 },
  { id: "lookWriting", clip: "Scene5Summary", at: 41.0, to: 42.2, src: 28.2, rate: 1 },
  { id: "lookBack", clip: "Scene5Summary", at: 42.2, to: 45.4, src: 31.2, rate: 1 },
];

// Beat boundaries (seconds).
export const T = {
  phoneIn: 5.0,
  phoneOut: 45.4,
  zoomIn: 33.2,
  chip: 34.8,
  zoomOut: 36.5,
  why: 45.8,
  bullets: [50.6, 51.5, 52.3, 53.6],
  end: 55.2,
};

// Sol, the host: his pose over time. Big in the opening and the close, small beside the phone in between.
export const POSES = [
  { from: 0, pose: "hello" },
  { from: 8.6, pose: "listening" },
  { from: 13.8, pose: "mark" },
  { from: 18.8, pose: "reflect" },
  { from: 23.6, pose: "listening" },
  { from: 29.6, pose: "thinking" },
  { from: 30.6, pose: "mark" },
  { from: 36.6, pose: "reflect" },
  { from: 45.4, pose: "mark" },
  { from: T.end, pose: "hello" },
];

// *word* = terracotta highlight.
export const CAPTIONS = [
  { from: 0.3, to: 5.0, lines: ["Meet *Sol*"], sub: "the wise old tortoise in your journal" },
  { from: 5.0, to: 8.6, lines: ["All the AI runs", "*on this iPhone*"] },
  { from: 8.6, to: 13.8, lines: ["Write *freely*"] },
  { from: 13.8, to: 18.8, lines: ["Details from", "*your own words*"] },
  { from: 18.8, to: 23.6, lines: ["Find it *again*"] },
  { from: 23.6, to: 30.6, lines: ["Talk it through", "with *Sol*"] },
  { from: 30.6, to: 36.6, lines: ["He *remembers*", "what helped"] },
  { from: 36.6, to: 41.0, lines: ["Keep a *reflection*"] },
  { from: 41.0, to: 45.4, lines: ["A gentle *look back*"] },
];

export const BULLETS = ["Never leaves your iPhone", "No servers. No account.", "Works offline", "Free to run"];

// kind: tap | pop | bloop | receive | whoosh | buzz | ding | sparkle | tick | check
export const SFX = [
  { t: 0.35, kind: "pop", gain: 0.45, pitch: 0.85 },
  { t: T.phoneIn, kind: "whoosh", gain: 0.45, dur: 0.5 },
  { t: 13.85, kind: "pop", gain: 0.35, pitch: 1.2 },
  { t: 16.85, kind: "tap", gain: 0.5 },
  { t: 18.95, kind: "tap", gain: 0.5 },
  { t: 25.6, kind: "tap", gain: 0.5 },
  { t: 30.7, kind: "receive", gain: 0.4 },
  { t: T.chip, kind: "sparkle", gain: 0.45 },
  { t: 36.75, kind: "tap", gain: 0.45 },
  { t: T.phoneOut, kind: "whoosh", gain: 0.4, dur: 0.5 },
  ...T.bullets.map((t, i) => ({ t, kind: "pop", gain: 0.4, pitch: 1 + i * 0.08 })),
  { t: T.end + 0.2, kind: "ding", gain: 0.45 },
];

// Sol is Grandfather Joe (warm, gentle, old); the writer is Jessica. `say` is what ElevenLabs reads.
export const VOICES = {
  model: "eleven_multilingual_v2",
  settings: { stability: 0.5, similarity_boost: 0.8, style: 0.3, use_speaker_boost: true, speed: 1.03 },
  Sol: { id: "0lp4RIz96WD1RUtvEu3Q", name: "Grandfather Joe, Gentle, Warm" },
  Writer: { id: "cgSgspJ2msm6clMCkdW9", name: "Jessica, Playful, Bright, Warm" },
};

export const VO = [
  { from: 0.4, to: 4.8, who: "Sol", note: "warm hello, a smile in it",
    text: "Hello, friend. I'm Sol, the old tortoise who lives in your journal.",
    say: "Hello, friend. I'm Sol, the old tortoise who lives in your journal." },
  { from: 5.1, to: 8.5, who: "Sol", note: "gentle, a little proud",
    text: "Everything I do happens right here, on your iPhone.",
    say: "Everything I do happens right here, on your iPhone." },
  { from: 8.8, to: 14.6, who: "Sol", note: "unhurried",
    text: "Write freely. I'll notice how you felt, what happened, and what helped, in your own words.",
    say: "Write freely. I'll notice how you felt, what happened, and what helped, in your own words." },
  { from: 18.9, to: 23.3, who: "Sol", note: "soft",
    text: "Keep a detail, and find that part of your life again.",
    say: "Keep a detail, and find that part of your life again." },
  { from: 26.6, to: 29.9, who: "Writer", note: "tired, honest, talking to a friend",
    text: "Work stress is back this week. What helped me last time?",
    say: "Work stress is back this week. What helped me last time?" },
  { from: 30.8, to: 36.4, who: "Sol", note: "remembering fondly",
    text: "On Sep 13, you wrote: “Long walk with Priya after work.”",
    say: "On September thirteenth, you wrote: long walk with Priya, after work." },
  { from: 37.0, to: 45.8, who: "Sol", note: "kind, steady",
    text: "When you're ready, I'll turn our talk into a reflection in your own words, or write you a gentle look back.",
    say: "When you're ready, I'll turn our talk into a reflection in your own words, or write you a gentle look back." },
  { from: 45.7, to: 54.9, who: "Sol", note: "sincere, the heart of it",
    text: "Why on your iPhone? Because your journal holds your most private words. They never leave it, it works offline, and it's free.",
    say: "Why on your iPhone? Because your journal holds your most private words. They never leave it, it works offline, and it's free." },
  { from: 55.3, to: 57.8, who: "Sol", note: "warm close",
    text: "Your words stay yours.",
    say: "Your words stay yours." },
];
