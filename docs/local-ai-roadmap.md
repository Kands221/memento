# Memento: local AI roadmap

Every item here runs **on the iPhone**. There are no servers, no API keys, and nothing leaves the device unless the writer exports it. The APIs were verified against the iOS 26.5 SDK installed with Xcode 26.6.

**Shipped:**
- Foundation Models for tag suggestions and for Sol, the tortoise companion.
- Items 1–3 below (Oct 2026): voice Sol, Sol remembers plus Discover related moments, and Paint this day.
- Exception to "never fall back to the cloud": for the iPhone 12 demo, builds with a `CloudAI.plist` key fall back to OpenRouter on devices that can't run on-device AI. It is labelled everywhere and can be turned off. See the README.

## Recommended for the hackathon (in order)

### 1. Talk with Sol: voice in, voice out ✅ shipped
**What:** hold a button and speak to Sol. He answers aloud in a slow, warm voice (he's a tortoise), and the text still streams on screen. Editor dictation is upgraded too: long-form, punctuated, with no one-minute limit.

**How:**
- **Speech to text:** `SpeechAnalyzer` + `SpeechTranscriber` (iOS 26, fully on device). Use `AssetInventory` to download the language model once.
- **Text to speech:** `AVSpeechSynthesizer`. Pick a warm voice, set the rate to about 0.42 and the pitch slightly low, and speak each sentence as it finishes streaming. Optionally use the writer's own Personal Voice, with permission.
- **Sol's animation:** a new **talking** state, a gentle head bob timed to speech.

**Works on:** every iOS 26 iPhone for speech. Sol's replies still need Apple Intelligence.

**Effort:** about half a day. **Demo impact:** very high, since it's a live conversation with a character.

### 2. Sol remembers: "Ask your journal" ✅ shipped
*As built:* retrieval is done by the app (a hybrid on-device index), not by a model tool call. The model didn't call the tool reliably, while app-side retrieval cited the right entry 3/3 times in live tests.
**What:**
- Sol can draw on what the writer has kept, for example: *"Last month you wrote that a long walk with Priya helped. Might that help now?"*
- Discover gains a semantic search ("times I felt stuck") that finds entries even when they don't use those words.

**How:**
- `NLContextualEmbedding` (on device) builds an embedding per entry, stored in SwiftData and refreshed after each save.
- A Foundation Models `Tool` (`SearchJournalTool`) lets Sol fetch the 3 most similar kept moments, each with a date, quote and tags, only when it helps. The model decides when to call it.
- The model's context is about 4K tokens, so the tool returns short excerpts, not whole entries.
- Guardrails:
  - Sol only cites entries that exist.
  - The UI shows a small "from your journal · Oct 6" chip under any reply that used one, so the writer can tap through.

**Works on:** devices with Apple Intelligence (search works on all iOS 26 devices).

**Effort:** about 1 day. **Demo impact:** very high, because it's the feature that makes the AI personal and useful.

### 3. Paint this day: on-device image generation ✅ shipped
**What:** one tap turns an entry into an illustration, used as the entry's cover and in Journal cards. Optionally, a weekly "memory card" collage.

**How:**
- `ImagePlayground.ImageCreator`, with `ImagePlaygroundConcept.extracted(from: entry.text, title:)` and the `.illustration` style (or `.sketch` for a pencil look).
- Images are rendered inside the existing paper card so they sit with the paper-cut art.
- For a no-code version, use `imagePlaygroundSheet(…)` so the writer can steer the image.

**Privacy note:** only offer `.animation`, `.illustration` and `.sketch`. **Never `.externalProvider`**, which is the ChatGPT-backed style and leaves the device.

**Works on:** Apple Intelligence devices. Check `ImageCreator` availability and hide the button elsewhere. One image takes about 10–20 s.

**Effort:** a few hours. **Demo impact:** high and visual.

### 4. Bring your paper journal in
**What:** photograph a handwritten page and it becomes a typed entry, which is then tagged like any other.

**How:** Vision `RecognizeDocumentsRequest` (iOS 26; reads paragraphs and layout, including handwriting), with `RecognizeTextRequest` as a fallback. Pages are cleaned up with `VNDocumentCameraViewController`.

**Works on:** every iOS 26 iPhone.

**Effort:** a few hours. **Demo impact:** high, a surprising "magic" moment.

## Next wave

| Idea | On-device API | Value | Effort |
|---|---|---|---|
| **Photos that tag themselves.** Suggest topic tags and alt text from photo entries (e.g. "Cooking", "Time outside"), and pick the best photo for covers. | Vision `ClassifyImageRequest` and `CalculateImageAestheticsScoresRequest`, feeding Foundation Models | Better tags for photo journaling, plus accessibility | ~3 h |
| **A weekly letter from Sol.** A gentle Sunday reflection on what was kept, what helped and what recurred. The numbers come from the deterministic counts; Sol writes the prose, labelled as drafted by Sol. | Foundation Models + `SummaryComposer` | Retention, and a warm ritual | ~3 h |
| **Mood over time.** A soft line of how entries *read* over weeks, explicitly "tone of your words, not a diagnosis". | `NLTagger` `.sentimentScore` (on device) | A pattern view for "For me" summaries | ~2 h |
| **Write in any language.** Sol replies in the writer's language. Translate an entry or summary for a clinician. | Foundation Models (multilingual) + `Translation` framework `TranslationSession` | Inclusive; matters for appointments | ~3 h |
| **"Hey Siri, tell Memento…"** Quick capture by voice, plus semantic Spotlight search of entries. | App Intents + Core Spotlight `CSUserQuery` (on-device semantic index) | Capture without opening the app | ~4 h |
| **Apple Health State of Mind.** With permission, kept feelings can be saved to Health. | HealthKit `HKStateOfMind` (not AI, but pairs with the tags) | Fits the user's wider wellbeing picture | ~2 h |

## Not recommended now

- **A custom paper-cut image model** (Core ML Stable Diffusion + LoRA in Memento's style): about 2 GB of weights, slow on phone (tens of seconds per image), and needs training. Image Playground plus paper-card framing gets most of the effect.
- **Whisper / third-party speech models:** `SpeechAnalyzer` on iOS 26 now covers long-form, on-device transcription natively.
- **Voice tone or emotion detection from audio:** sensitive, unreliable, and against Memento's "suggestions from your words" principle.

## Guardrails that apply to all of the above

- **Availability:**
  - Foundation Models and Image Playground need Apple Intelligence; check availability and degrade gracefully, like the existing AI states.
  - Speech, Vision, NaturalLanguage and Translation run on every iOS 26 iPhone, but their language assets may need a one-time download.
- **Never fall back to the cloud.** No `.externalProvider`, no server calls. The Demo menu keeps backup engines for stage use.
- **Grounding:** anything Sol says about the writer's past must come from a real entry and link to it.
- **Wording:** "suggestions, not facts"; no diagnoses; Sol is not a therapist.
