<p align="center"><img src="docs/screens/icon.png" width="96" alt="Memento app icon"></p>

<h1 align="center">Memento</h1>

<p align="center"><em>Write naturally. Notice gently. Find it again.</em></p>

Memento is a private journal for iPhone. On-device AI suggests the details in what you wrote: how you felt, what was hard, what helped. Each suggestion is tied to your exact words, so you can find those moments again later. **Sol** (short for Solomon), a wise old paper tortoise, talks things through with you and helps turn the conversation into a reflection you keep.

On iPhones with Apple Intelligence, AI runs on the iPhone through Apple's Foundation Models framework by default. Your writing stays on the phone unless you export, share it, or choose cloud AI.

On iPhones without on-device AI (for example iPhone 12), a build that includes a cloud key falls back to cloud AI through OpenRouter. The app says so wherever it matters ("Cloud AI" in Sol's header, the AI settings card, onboarding), and **You → On-device AI → Use cloud AI** turns it off.

<p align="center">
  <img src="docs/screens/03-journal-light.jpg" width="200" alt="Journal">
  <img src="docs/screens/06-entry-light.jpg" width="200" alt="Entry with on-device suggestions">
  <img src="docs/screens/14-sol-light.jpg" width="200" alt="Sol conversation">
  <img src="docs/screens/09-notebooks-light.jpg" width="200" alt="Notebooks">
</p>
<p align="center">
  <img src="docs/screens/07-tag-light.jpg" width="200" alt="Tag detail">
  <img src="docs/screens/08-discover-light.jpg" width="200" alt="Discover">
  <img src="docs/screens/16-summary-preview-light.jpg" width="200" alt="Summary preview">
  <img src="docs/screens/03-journal-dark.jpg" width="200" alt="Journal in dark mode">
</p>

## What it does

- **Write.** Four modes: free writing, a three-minute brain dump, guided prompts, and photo entries. Dictation runs on the device too. Saving is instant and never waits for AI.
- **Notice.** After you save, the on-device model suggests up to four tags: a feeling, a situation, what helped, and a topic. Each one highlights the words behind it. Dashed means suggested, filled means kept. You can keep, edit, remove, or undo any of them.
- **Find again.** A kept tag opens every related moment across your notebooks, on a timeline that also shows which other tags appear alongside it.
- **Reflect with Sol.** Sol streams its replies, asks one gentle question at a time, and drafts a reflection only from your own words. Sol's mood shows in his pose: waving hello, listening, thinking, reading beside your notebook, tucked in his shell to rest.
- **Talk with Sol.** Tap the mic and speak; Sol answers aloud, sentence by sentence as he writes. Pick and preview an installed voice in **You → Sol’s voice**. Speech is transcribed on the iPhone (`SpeechAnalyzer` where supported, classic on-device dictation otherwise).
- **Sol remembers.** Sol can bring back a closely related moment you wrote ("On Sep 13 you wrote that a walk with Priya helped") with a tappable "From your journal" chip. Discover also shows **Related moments** that don't share your exact words. The journal index is built and searched on the iPhone.
- **Paint this day.** On Apple Intelligence iPhones, one tap turns an entry into an illustration with Image Playground, on device.
- **Summaries.** A PDF of selected entries, kept-tag counts and optional quotes, for yourself or an appointment. In **For me** summaries, Sol can draft an editable look-back paragraph on the iPhone from counted facts. Each sentence cites facts; checks reject mismatched numbers, tags and dates, plus causal claims, diagnoses and advice. If drafting is unavailable or too little passes the checks, a fixed factual paragraph stays. Appointment summaries always use fixed factual text.

## On-device AI

| | How |
|---|---|
| Tagging | The system language model returns `EntryDetails`, with one optional slot per kind. Each slot holds a verbatim quote and a label constrained to a curated vocabulary (`@Guide(.anyOf(...))`). A sanitizer drops anything that isn't grounded in your text. See [`FoundationModelTagger.swift`](Packages/MementoCore/Sources/MementoCore/AI/FoundationModelTagger.swift). |
| Sol | A `LanguageModelSession` carries the conversation, condensed into grounded notes and recent messages when its context fills. Structured `@Generable` replies pass sentence checks before you see or hear them, with two quick replies. See [`FoundationModelSol.swift`](Packages/MementoCore/Sources/MementoCore/AI/FoundationModelSol.swift) and the persona in [`SolCharacter.swift`](Packages/MementoCore/Sources/MementoCore/AI/SolCharacter.swift). |
| Safety | Crisis language skips the model and shows a support card. Sol is capped at 12 writer turns, never claims to remember earlier conversations or be a therapist, and never diagnoses. |
| Memory | `JournalIndex`: on-device hybrid retrieval (NaturalLanguage sentence embeddings, lemma overlap, kept-tag and "what helped" boosts). Sol cites only entries that exist. |
| Voice | `SpeechAnalyzer` + `SpeechTranscriber` in, `AVSpeechSynthesizer` out, chunked by sentence while the reply streams. |
| Painting | `ImageCreator` prefers `.illustration`, falling back to `.sketch` or `.animation` when available; never the external (ChatGPT) style. |
| No on-device AI? | With a cloud key: `CloudTagger` and `CloudSol` call OpenRouter with strict JSON schemas and zero-data-retention routing, then pass through the same grounding sanitizer, planner and crisis handling. Without one: every journaling feature still works, with honest "not available" states and manual tags. |

## Run it

Requirements: Xcode 26, iOS 26. For live AI you need an Apple Intelligence iPhone (iPhone 15 Pro or newer) or the simulator on an Apple Intelligence Mac.

1. Open `Memento.xcodeproj`.
2. Select the **Memento** target, then under Signing & Capabilities pick your Team. A personal team is fine.
3. Run on your iPhone or the iPhone 17 Pro simulator.
4. Optional: go to **You → Demo → Load sample journal** for a populated journal. The Demo section also previews every AI state and has backup engines for stage demos.

### Cloud fallback (for iPhones without Apple Intelligence)

Create `Memento/Resources/CloudAI.plist` (git-ignored) before building:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>OpenRouterAPIKey</key><string>sk-or-…</string>
  <key>Model</key><string>anthropic/claude-haiku-5.5</string>
</dict></plist>
```

The key ships inside that build, so use a spend-capped key and keep the build to your own devices. A public release would route through a server instead. To try the fallback in the simulator, launch with `-simulateNoOnDeviceAI`, or pick **Cloud AI** under You → Demo.

## Tests

```bash
cd Packages/MementoCore && swift test          # 154 tests listed; live-model tests run where Apple Intelligence is available
MEMENTO_LIVE_CLOUD=1 swift test --filter CloudLiveTests   # live OpenRouter checks (needs CloudAI.plist)
cd ../..
xcodebuild -project Memento.xcodeproj -scheme Memento \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # UI tests, including RealAITests against the live model
```

## How it was made

- **Design:** recreated from a claude.ai/design prototype (`design-reference/Memento Prototype.dc.html`). The spec and implementation plan are in [`docs/superpowers`](docs/superpowers).
- **Art:** a paper-cut illustration kit generated with Codex image generation. Codex workers were orchestrated through Orca and did images only. The style bible, briefs, and review verdicts are in [`design-assets/`](design-assets).
- **Code:** SwiftUI and SwiftData, with an app target plus a `MementoCore` Swift package for models, domain logic, and AI engines.

## Demo videos

The HTML scene kit in [`marketing/`](marketing/README.md) renders the demo videos from Playwright frames, with ElevenLabs voices and an optional ElevenLabs score. Recordings, generated audio and rendered videos are git-ignored and stay local.

## Credits

- Typefaces: [Newsreader](https://github.com/productiontype/Newsreader) and [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), both SIL Open Font License. See [`Licenses/`](Licenses).
- Sol is not a therapist. If you're struggling, please reach out to someone you trust or a local helpline.
