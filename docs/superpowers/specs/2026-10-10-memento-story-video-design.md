# Memento story video (v2): design

**Date:** Oct 10, 2026. **Status:** Built Oct 10, 2026

## Purpose and success

- **One 60 s master for hackathon judges, and a 30 s cut-down for social.** Both are landscape (16:9, 1920×1080) and made from the same pieces.
- **Judges** must come away with the problem (a 2 a.m. mind that won't switch off), the on-device demo (tags from her words, Sol remembering what helped, a reflection in her words), and why local AI (private, no servers or account, offline, free to run).
- **Social viewers** must feel something in the first 2 seconds and follow it with the sound off (burned-in subtitles).
- **Better than v1** (`marketing/memento-demo`): a story with a person in it, Sol as a character inside the world rather than a host in a corner, and a true 16:9 composition rather than a stretched vertical one.

## Story and script (60 s master)

The left two-thirds of the frame is a paper-cut world that changes with the story. The right third holds a large phone showing the real app. Voices: **Her** is the writer (late 20s, ElevenLabs Jessica, intimate). **Sol** is the tortoise (ElevenLabs Grandfather Joe, warm and slow, natural speed).

| Time | Paper world | Phone (real footage) | Voice |
|---|---|---|---|
| 0:00–0:05 | Night bedroom. Moonlit window; she lies awake; the phone glows; a clock reads 2:04 (drawn in HTML, not in the art). | Dark. | **Her:** "It's 2 a.m. Work's been a lot, and I can't switch off." |
| 0:05–0:16 | She sits up and writes; the journal on the nightstand opens and Sol peeks out of it. | Write freely → typing (timelapse) → "Finding details on this iPhone…" → tags from her words. | **Sol:** names the tags the chosen take shows, for example "Drained. Work. And a walk with Priya that helped. Shall we keep those?" |
| 0:16–0:22 | Sol climbs out and settles beside her, listening. The Memento wordmark appears briefly. | Sol's screen: "Still up? The quiet hours can be good for honest thinking." Mic, then dictation fills. | **Her:** "Work stress is back this week. What helped me last time?" |
| 0:22–0:34 | Flashback: the camera dives into the journal and the paper unfolds into a dusk walk under paper trees, with her and Priya. | Sol's reply quotes the Sep 13 entry; "From your journal · Sep 13" chip with the terracotta ring and a push-in. | **Sol:** "On September 13th, you wrote: long walk with Priya, after work." |
| 0:34–0:42 | It folds back to the room; she smiles. | Second dictated message → Sol's reply → "Turn this into a reflection" → her reflection → saved. | **Her:** "Maybe I'll text Priya. We can walk tomorrow." **Sol:** "A kind next step, I think." |
| 0:42–0:55 | The same room re-lit by sunrise, then the morning walk with Priya, with Sol trundling behind on the path. | The phone slides away. | **Sol:** "A journal holds your most private words. So everything I do stays on your iPhone. No servers, no account. Even offline." |
| 0:55–1:00 | End card: Sol waves beside the Memento wordmark. | — | **Sol:** "Your words stay yours." Small print: "Built with Apple Foundation Models · on-device". |

### 30 s cut-down

Same scene and footage, with its own timeline and music:

| Time | Beat |
|---|---|
| 0:00–0:04 | The 2 a.m. hook |
| 0:04–0:09 | Writing → tags (fast) |
| 0:09–0:20 | The question → Sol quotes Sep 13 → Priya flashback |
| 0:20–0:27 | The morning walk with "everything I do stays on your iPhone… even offline" |
| 0:27–0:30 | End card, "Your words stay yours." |

Line edits for the 30 s cut are made in its timeline and generated as their own voice clips.

## Look and layout

- **Frame:** 1920×1080. The paper world fills the frame. The phone floats on the right third, about 960 px tall, with a slight 3D tilt, a soft shadow and a warm screen glow at night. Story subjects stay in the left two-thirds.
- **Light and depth:**
  - **Camera:** a slow drift per scene (pan and zoom, at most 6%).
  - **Light overlays:** moon glow (gentle pulse), phone glow on her (radial, follows the phone), and a sunrise sweep (night slate-blue grade to dawn peach) over the same bedroom.
- **Sol:** the six existing tortoise poses as cut-outs (`design-assets/generated/tortoise`, cut by `prep.mjs` as in v1), placed inside the scenes.
  - **Peek:** rises out of the open journal, masked by its pages.
  - **Listen:** beside her, with a head tilt.
  - **Think:** the "?" pose while Sol is thinking on screen.
  - **Speak:** nod and ripples while his voice plays.
  - **Walk:** bob and translate along the morning path.
  - **Wave:** the hello pose on the end card.
- **Transitions:**
  - **Night to flashback:** zoom into the open journal, then a paper-unfold reveal.
  - **Flashback to night:** fold back.
  - **Night to dawn:** a grade and light change on the same room (cross-fade from the night image to the dawn image under the sweep).
- **Phone:** real footage in an iPhone frame, with push-ins on the tags and on the journal chip (the ring from v1, re-measured for the new screen size).
- **Text:**
  - Burned-in subtitles at the bottom-left (SF Pro, white on a soft ink pill).
  - Feature chips beside the phone: "Tags from your words · on device", "Sol remembers", "A reflection in your words".
  - The wordmark at about 0:16, and the end card. Titles use Newsreader.

## Art (new)

Five 16:9 paper-cut scenes, briefs in `design-assets/briefs/wave5-story.md`:

1. Night bedroom, her lying awake, with the phone glow as a lit paper shape.
2. Same room, her sitting up and writing, the journal open on the nightstand (with space where Sol rises).
3. Dusk walk: her and Priya under paper trees.
4. The bedroom at dawn (bed empty or her asleep), warm light.
5. Morning walk path: her and Priya walking, with open path behind them for Sol.

**Exceptions to `design-assets/STYLE.md` for this set only:**
- Faceless paper-cut figures are allowed (no facial features, simplified hands).
- Full scenes instead of a flat cream background.
- A night palette extension: deep slate-indigo paper and a pale moon. The palette otherwise stays as in the bible.
- Still no text, numbers or UI in the art.

**Generation and review:**
- Codex image generation, run through the Orca orchestration skill (per the user's standing rule).
- Each image is checked against its brief, and misses are regenerated.
- Verdicts go in `design-assets/RUN.md`.
- Accepted images are cropped to 16:9 with the subject in the left two-thirds.

## Footage

- Re-record `Scene2Write` and `Scene4Sol` on the "Memento Demo" simulator, with the status bar at 2:04 and live on-device AI, keeping the best of several takes.
- Sol's "Still up?" opener follows the Mac's real clock, so record late at night.
- The existing `Scene5Summary` is not needed. The dictated lines stay as recorded: "Work stress is back this week. What helped me last time?" and "Maybe I will text Priya and we can walk after work tomorrow."
- Cut points are set by eye against the recordings, as in v1 (the test markers drift).

## Sound

- **Voices:** ElevenLabs `eleven_multilingual_v2`. Jessica gets softer, more expressive settings; Grandfather Joe runs at speed 1.0. Lines are timed so none needs speeding up (the target tempo is 1.0x; the kit's limit is 1.25x).
- **Score:** ElevenLabs Music, with one 60 s track and one 30 s track. The arc: sparse felt piano and pad at night, warm strings and nylon guitar in the flashback, settling back, then brighter with glockenspiel at dawn, and a gentle resolve on the end card.
- **Sound effects:** synthesized by the kit: clock ticks (opening), a page rustle (journal opens), soft taps (phone), a small chime (tags), a paper flutter (unfold and fold), and a warm ding (end card).
- **Mix:** the music and effects duck under every voice line, with the master at −16 LUFS. The SRT comes from the script.

## Build

- `marketing/memento-story/` holds the 60 s master: `timeline.mjs`, `scene.html`, `scene.js`, `prep.mjs` (art cut-outs, scene crops, footage frames).
- `marketing/memento-story-30/` holds the 30 s cut: its own `timeline.mjs`, reusing the master's scene.
- The kit is reused as in v1. Any shared additions go in `marketing/kit/`, such as the burned-in subtitle renderer.
- **Checks:**
  - **Before rendering:** stills at every beat.
  - **After rendering:** frames at every transition, durations (60.0 s and 30.0 s), loudness, and subtitle sync.

## Deliverables

In `marketing/final/` (git-ignored):
- `Memento story – 60s 16x9.mp4`
- `Memento story – 30s 16x9.mp4`
- a cover PNG for each
- `.srt` subtitles

The source and scripts are committed. Recordings and renders stay local.

## Honesty rules

- Everything the app shows on screen was generated live by the on-device model.
- The spoken input is simulated in the simulator; the voices are ElevenLabs; the people and places are illustrations. These are disclosed in the submission's technical disclosures.
- Show no feature Memento doesn't have, no Paint this day (the simulator has no Image Playground), and no airplane mode from a simulator.

## Risks

- **Image generation:** quality may vary (figures, consistency between the two bedroom images). Mitigation: review, regenerate, and keep the bedroom composition identical across images 1, 2 and 4 by briefing them as one room.
- **Sol's opener depends on the time of day.** Mitigation: record at night, or pick a take where it reads "Still up?".
- **Live AI wording varies between takes.** Mitigation: several takes; the voice lines quote only what appears on screen.

## Out of scope

- Vertical versions.
- Real-iPhone footage.
- Changes to the app.
