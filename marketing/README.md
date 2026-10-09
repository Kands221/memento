# Marketing videos

Ads built in code, adapted from the LETPass marketing kit: each frame is an HTML scene rendered in headless Chromium,
with synthesized sound effects, an ElevenLabs voiceover and an optional ElevenLabs score. Every visual is a pure
function of time, so any frame can be rendered on its own.

| Ad | What it shows | Length |
|---|---|---|
| [`memento-demo/`](memento-demo/) | Memento's core features on Apple's on-device model, hosted by Sol, and why the AI runs locally | 58 s, 9:16 |
| [`memento-demo-wide/`](memento-demo-wide/) | The same cut laid out for landscape (shares timeline, footage, voice and score) | 58 s, 16:9 |
| [`memento-story/`](memento-story/) | A sleepless writer, Sol remembering a walk with Priya, and a journal that stays on her iPhone | 60 s, 16:9 |
| [`memento-story-30/`](memento-story-30/) | The social cut of the same story, with tags, a remembered walk and on-device privacy | 30 s, 16:9 |

## Commands

Before running any voice or music command, set and export `ELEVENLABS_API_KEY` in your shell, or read it from your own
secret file and export it. The commands below use that environment variable.

```bash
cd marketing && npm install                                   # Playwright + sharp
memento-demo/record.sh                                        # record the scenes from the "Memento Demo" simulator
TAKE=B memento-demo/record.sh Scene4Sol                       # another take of one scene (live AI varies)
node kit/render.mjs memento-demo --still 2,34.9               # PNG stills into build/stills/
node kit/render.mjs memento-demo                              # frames, SFX and the silent cut into out/
node kit/voice.mjs memento-demo                              # voice + score mix → out/memento-demo-9x16-vo.mp4
node kit/render.mjs memento-demo-wide && node kit/voice.mjs memento-demo-wide   # landscape (copy build/vo and build/music.mp3 first to reuse them)
```

For the story cuts, run these from `marketing/`. Generate the voice timings before rendering so the subtitles follow
the cached speech, then generate the score, render, mix and verify:

```bash
# 60 s master
node kit/voice.mjs memento-story --clips-only
curl -fsS -m 300 -o memento-story/build/music.mp3 -w "status=%{http_code}\n" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" -H "Content-Type: application/json" \
  -d @memento-story/music.json "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128"
node kit/render.mjs memento-story
node kit/voice.mjs memento-story
node kit/verify.mjs memento-story/out/memento-story-16x9-vo.mp4 --duration 60

# 30 s social cut
node kit/voice.mjs memento-story-30 --clips-only
curl -fsS -m 300 -o memento-story-30/build/music.mp3 -w "status=%{http_code}\n" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" -H "Content-Type: application/json" \
  -d @memento-story-30/music.json "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128"
node kit/render.mjs memento-story-30
node kit/voice.mjs memento-story-30
node kit/verify.mjs memento-story-30/out/memento-story-30-16x9-vo.mp4 --duration 30
```

The 30 s timeline uses `MUSIC = { delay: 4.6, fadeOut: 1 }` to start its score at 4.6 s and fade it over the last second.

- **Footage:** the real app in the iOS Simulator with its live on-device AI (Apple's Foundation Models on the Mac).
  The Simulator has no working speech model, so `-demoSpeech` types the spoken lines word by word, the way on-device
  dictation fills the field on an iPhone.
- **Cuts:** set by eye against the recordings (the test markers drift a few seconds), in `timeline.mjs`.
- **Voices:** Sol is Grandfather Joe and the writer is Jessica (ElevenLabs Voice Library, Starter plan or above).
  Voice lines are cached in `build/vo/`, so re-runs only spend characters on lines that changed.
- **Score:** `build/music.mp3`, made with ElevenLabs Music. It ducks under the voice.
- **Deliverables:** `final/Memento story – 60s 16x9.mp4` and `final/Memento story – 30s 16x9.mp4`, with matching cover PNGs and SRT subtitles.
- **Not committed:** `footage/`, `build/`, `out/` and `final/` are git-ignored, so the recordings and renders stay local.
