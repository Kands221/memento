# Marketing videos

Ads built in code, adapted from the LETPass marketing kit: each frame is an HTML scene rendered in headless Chromium,
with synthesized sound effects, an ElevenLabs voiceover and an optional ElevenLabs score. Every visual is a pure
function of time, so any frame can be rendered on its own.

| Ad | What it shows | Length |
|---|---|---|
| [`memento-demo/`](memento-demo/) | Memento's core features on Apple's on-device model, hosted by Sol, and why the AI runs locally | 58 s, 9:16 |

## Commands

```bash
cd marketing && npm install                                   # Playwright + sharp
memento-demo/record.sh                                        # record the scenes from the "Memento Demo" simulator
TAKE=B memento-demo/record.sh Scene4Sol                       # another take of one scene (live AI varies)
node kit/render.mjs memento-demo --still 2,34.9               # PNG stills into build/stills/
node kit/render.mjs memento-demo                              # frames, SFX and the silent cut into out/
ELEVENLABS_API_KEY=... node kit/voice.mjs memento-demo        # voice + score mix → out/memento-demo-9x16-vo.mp4
```

- **Footage:** the real app in the iOS Simulator with its live on-device AI (Apple's Foundation Models on the Mac).
  The Simulator has no working speech model, so `-demoSpeech` types the spoken lines word by word, the way on-device
  dictation fills the field on an iPhone.
- **Cuts:** set by eye against the recordings (the test markers drift a few seconds), in `timeline.mjs`.
- **Voices:** Sol is Grandfather Joe and the writer is Jessica (ElevenLabs Voice Library, Starter plan or above).
  Voice lines are cached in `build/vo/`, so re-runs only spend characters on lines that changed.
- **Score:** `build/music.mp3`, made with ElevenLabs Music. It ducks under the voice.
- **Not committed:** `footage/`, `build/` and `out/` are git-ignored, so the recordings and renders stay local.
