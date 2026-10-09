# Memento for iPhone — Design Spec

**Date:** 2026-10-09
**Source design:** claude.ai/design project `439e4d4c-8919-4648-ad37-aa24c3e210b3`, files `Memento Prototype.dc.html` and `support.js` (the latter is the generic design-canvas runtime and holds no app logic).
**Status:** decisions made on the user's behalf ("go with all your recommended"); see §2 to override any of them.

## 1. Intent

Recreate the Memento HTML prototype as a native SwiftUI iPhone app that a real person can journal in.

- **What the user said:** recreate the design as a Swift app; use Codex image generation to add personality; use orchestration for image generation only; tagging and AI conversation run on local AI.
- **Product promise (from the prototype):** *Write naturally. Notice gently. Find it again.* Saving never waits for AI. On-device tagging suggests details, each tied to the exact words behind it. Dashed = suggested, filled = kept. Kept tags open every related moment across notebooks and feed summaries. Journal text never leaves the phone unless the user exports or shares it.
- **Success criteria:**
  1. Every screen and state in the prototype exists natively (list in §6), matching its palette, typography, spacing, and copy.
  2. Tag suggestions and Sol conversations run on Apple's on-device Foundation Models. There's no network call anywhere in the app.
  3. The prototype's placeholder hatched boxes ("paper-cut illustration — an olive sprig…", photo stand-ins) are replaced by a coherent set of Codex-generated paper-cut illustrations, plus an app icon.
  4. The app builds with Xcode 26.6 for iOS 26, its unit and UI tests pass on the iOS 26.5 simulator, and screenshots of key screens in light, dark, and large text match the prototype's intent.

## 2. Decisions made on the user's behalf

| # | Decision | Chosen | Alternatives considered | Why |
|---|---|---|---|---|
| D1 | Local AI runtime | **Apple Foundation Models** (iOS 26), `SystemLanguageModel(useCase: .contentTagging)` for tags, `.general` for Sol | MLX + downloaded open model; Core ML custom classifier | First-party, no 1.1 GB app-managed download, private by construction, structured output via `@Generable`. The SDK confirms the `.contentTagging` adapter exists. |
| D2 | Model download UX | Map the prototype's download flow onto the **system's real states**: ready / Apple Intelligence off / model preparing / device not eligible | Keep a fake download bar | Apple manages the model, so a fake progress bar would be dishonest. "Remove model" is replaced by a "Managed by Apple Intelligence" row. |
| D3 | Minimum OS | **iOS 26.0**, iPhone only | iOS 18 with AI disabled on older OSes | Foundation Models needs iOS 26, and the prototype's AI-unsupported states still cover ineligible iPhones. |
| D4 | UI framework | **SwiftUI**, Swift 6 language mode, `@Observable`, MainActor default isolation in the app target | UIKit | Native, concise, and matches the declarative prototype. |
| D5 | Persistence | **SwiftData**, local only, no CloudKit | JSON files; Core Data | Standard, supports `@Attribute(.externalStorage)` for photos, and has no sync, which keeps "never leaves your phone" literally true. |
| D6 | Project generation | **Hand-written `.pbxproj` using Xcode 16+ file-system-synchronized groups** plus a local Swift package | XcodeGen or Tuist (not installed) | No new tooling. Synchronized folders pick up new files without editing the pbxproj. |
| D7 | Code layout | **`MementoCore` local Swift package** (models, domain logic, AI engines) + thin **app target** (UI) | Single target | `swift test` gives fast TDD loops on macOS without booting a simulator. |
| D8 | Tab bar | **Custom bottom bar** reproducing the design (center terracotta "+" opens the Write sheet), translucent material, hidden on editor/Sol/onboarding exactly as the prototype does | Native `TabView` with an intercepted "Write" tab | The design's center action and per-screen visibility can't be expressed faithfully with the native bar. |
| D9 | Fonts | Bundle **Newsreader** (variable, roman + italic) and **JetBrains Mono** (both SIL OFL) from google/fonts. UI text uses SF Pro. All three scale with Dynamic Type via `relativeTo:` | System serif (New York) | Fidelity to the design's editorial voice. |
| D10 | Seed data | Installs start **empty** with the 4 default notebooks (Daily, Work, Gratitude, Reflections). The prototype's "Maya" journal is one tap away in **You → Demo → Load sample journal** (in every build), and launch arg `-seedSampleData` loads it for tests | Always preload Maya's entries | Hackathon judges see a rich journal instantly, while a fresh install still demonstrates the empty and first-entry flow. |
| D11 | Onboarding demo tagging | Uses the prototype's **deterministic rule tagger** on its fixed demo sentence, so it works instantly on every device. The demo entry is **not** inserted into the journal afterwards | Run Foundation Models live in onboarding | Instant, works on unsupported devices, and avoids planting a fake first entry. |
| D12 | Greeting / name | Time-of-day greeting ("Good evening") with no name. Sol opens with "Hi." The clinician summary asks for an optional "Prepared by" name, remembered for reuse | Ask for a name in onboarding | The prototype never collects a name, and only the clinician PDF needs one. |
| D13 | Appearance | **System / Light / Dark** picker in You (the prototype had a dark switch) | Boolean switch | A switch can't express "follow system", which is the iOS default. |
| D14 | Summary narrative | **Deterministic composer** (counts plus templated sentences, ported from the prototype), no LLM | Foundation Models prose | Clinician-facing text must be factual and reproducible ("not a diagnosis"). |
| D15 | Sharing / export | **System share sheet** (`ShareLink`) with PDFs rendered by `UIGraphicsPDFRenderer` (paginated) | Recreate the prototype's fake share sheet | The real share sheet is the honest "nothing is shared until you choose" moment. |
| D16 | Dictation | `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` | iOS 26 `SpeechAnalyzer` | Mature API. On-device only, matching the privacy promise. If on-device recognition is unavailable, the Speak button is hidden. |
| D17 | Sol safety | If the model hits a guardrail or the user's words suggest crisis, Sol shows a gentle static **Support** card (emergency number, 988 in the US, "talk to someone you trust") | Ignore | Journaling and clinician summaries put this app near mental health, so a static, offline safety net is the responsible floor. |
| D18 | Image generation | **Orca orchestration of Codex workers, images only.** All Swift code is written by Claude directly (inline execution) | Codex writes code too | The user scoped orchestration to image generation. |
| D19 | Illustration backgrounds | Generated on a **flat cream paper color (#FFFCF6)** and always shown inside a paper card, in both themes | Transparent PNGs | Transparency from the image tool isn't guaranteed. A paper card reads intentionally in dark mode ("a printed card on a dark desk"). |
| D20 | Notebooks | The 4 fixed notebooks from the design. **No create/rename in v1** | Full notebook CRUD | Not in the design. Recorded as future work. |
| D21 | Distribution | **Hackathon demo build for iPhone**, installed with Xcode on a real Apple Intelligence iPhone. No App Store compliance work for now (§11 lists what to add later) | App Store-ready from day one | The user said: hackathon, no compliance for now, iPhone. |
| D22 | Sol conversation length | A soft cap of **12 user turns**. From turn 8, Sol steers toward "Turn this into a reflection". At 12, input is replaced by the reflection button and a note | Unlimited chat | This is a Foundation Models *framework* term (item 7: no "dependency or spiraling user interactions"), not an App Store rule, so it applies even to a demo. It costs about 10 lines and fits the design's framing of Sol as a short path to a written reflection. |
| D23 | Demo controls | **You → Demo** section in every build: Load sample journal, Clear journal, Replay welcome, and an AI-state override (Live / Not set up / Getting ready / Unsupported / Tagging fails) to show every prototype state on stage | Debug-only tooling | The prototype's "Tweaks" panel exists so these states can be shown; judges will want to see them. |
| D25 | Source hosting | **Public GitHub repo `Kands221/memento`**, `main` = this app. README with demo GIF/screens and run steps. `design-reference/support.js` (Anthropic's generated canvas runtime) is git-ignored; the prototype HTML (the user's design) is committed | Private repo | The user asked for a public repo (hackathon). |
| D26 | Asset-driven UI/UX | Codex generates a **full asset kit, not just placeholders**: brand + onboarding spots, notebook covers, empty states, paper-cut write-mode icons, tag-kind emblems, a reminder lock-screen scene, streak and "Tonight" ornaments, and a paper-grain texture (§8) | Only replace the prototype's placeholder boxes | The user asked to improve UI/UX by generating assets with Codex. |
| D24 | Bundle identity | Bundle ID `com.kand221.memento`, display name **Memento**, automatic signing, `DEVELOPMENT_TEAM` empty for the user to pick (a free personal team works for on-device demos) | Guess a team | Device signing needs the user's Apple ID in Xcode. |

## 3. Architecture

```
Memento.xcodeproj                 hand-written, synchronized folders
Memento/                          app target (UI only)
  App/                            MementoApp, AppModel, RootView, Router, LaunchOptions
  DesignSystem/                   Palette, Typography, chips, toggles, cards, buttons,
                                  Toast, PaperIllustration, AnnotatedText (TextRenderer)
  Features/
    Onboarding/ Journal/ Write/ Editor/ Entry/ Tag/ Discover/
    Notebooks/ You/ Reminders/ OnDeviceAI/ Sol/ Summary/ Support/
  Services/                       ReminderScheduler, Dictation, PDFRenderer
  Resources/                      Assets.xcassets (colors, illustrations, AppIcon), Fonts/
  Info.plist                      UIAppFonts, usage descriptions
Packages/MementoCore/             Swift package (iOS 26, macOS 26)
  Sources/MementoCore/
    Models/                       Entry, TagMark (@Model); enums; Notebook catalog
    Domain/                       TagIndex, Streak, TextSegments, Excerpt, DateLabels,
                                  SummaryComposer, PendingReview, Revisit
    AI/                           AIAvailability, TaggingEngine, FoundationModelTagger,
                                  RuleTagger, SuggestionSanitizer, SolEngine,
                                  SolConversation, FoundationModelSol, ScriptedSol,
                                  ReflectionTemplate, CrisisSignal
    Services/                     TaggingCoordinator
    Sample/                       SampleJournal (demo seed ported from the prototype)
  Tests/MementoCoreTests/
MementoUITests/                   XCUITest smoke flows
design-assets/                    style bible, per-asset prompts; generated/ (git-ignored originals)
```

**Boundaries:**
- `MementoCore` has no SwiftUI or UIKit imports. It imports `SwiftData` and `FoundationModels` (both available on macOS 26, so `swift test` runs locally).
- Views never call Foundation Models directly. They talk to `TaggingCoordinator` and `SolEngine` through protocols, which UI tests replace with deterministic engines via launch arguments.

## 4. Data model

```swift
@Model final class Entry {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var notebookID: String          // "daily" | "work" | "grat" | "refl"
  var modeRaw: String             // WritingMode: free, dump, guided, photo, sol
  var prompt: String?             // guided prompt shown while writing
  var text: String
  @Attribute(.externalStorage) var photoData: Data?
  var taggingRaw: String          // TaggingStatus: pending, done, failed, skipped
  @Relationship(deleteRule: .cascade, inverse: \TagMark.entry) var tags: [TagMark]
}

@Model final class TagMark {
  @Attribute(.unique) var id: UUID
  var label: String
  var categoryRaw: String         // feeling | situation | helped | topic
  var quote: String?              // verbatim substring of entry.text, or nil
  var statusRaw: String           // suggested | kept | removed
  var isManual: Bool              // added by the user
  var isEdited: Bool              // label/kind changed by the user → never overwritten
  var createdAt: Date
  var entry: Entry?
}
```

`Notebook` is a static catalog (id, name, cover color, illustration asset), not a model (D20).

**Invariants:**
- Only `kept` tags count anywhere: Discover, tag detail, summaries, revisit, co-occurrence.
- `removed` tags stay on the entry so Undo works. They're hidden everywhere.
- Re-running tagging never modifies a kept or edited tag. New suggestions whose label (case-insensitive) already exists on the entry are dropped.

## 5. Local AI

### 5.1 Availability

`AIAvailability` is one of `.ready`, `.needsAppleIntelligence`, `.preparing`, `.unsupported`, mapped from `SystemLanguageModel.default.availability` (`.available`, `.appleIntelligenceNotEnabled`, `.modelNotReady`, `.deviceNotEligible`). It refreshes on launch and whenever the app returns to the foreground. While `.preparing`, it polls every 10 s.

| Prototype state | Native state | UI |
|---|---|---|
| ready | `.ready` | "READY · WORKS OFFLINE" |
| needs-download | `.needsAppleIntelligence` | "TURN ON APPLE INTELLIGENCE" + button that opens Settings (`UIApplication.openSettingsURLString`) |
| downloading / interrupted | `.preparing` | "GETTING READY" with an indeterminate progress bar: "Apple Intelligence is downloading its on-device model. You can start writing meanwhile." |
| unsupported | `.unsupported` | the prototype's "Not available on this iPhone" copy, unchanged |
| tagging-fails | `TaggingCoordinator` state `.failed` | "Couldn't finish finding details" + Try again |

### 5.2 Tagging

- **Engine:** `FoundationModelTagger` creates a fresh `LanguageModelSession(model: SystemLanguageModel(useCase: .contentTagging), instructions: …)` per entry and calls `respond(to:generating: TagSuggestions.self)`.
- **Schema:**
  ```swift
  @Generable struct TagSuggestions { @Guide(.maximumCount(5)) var tags: [SuggestedTag] }
  @Generable struct SuggestedTag {
    @Guide(description: "1–3 words, Title case, e.g. Drained, Work deadlines, Walking helped") var label: String
    var category: TagKind   // @Generable enum feeling, situation, helped, topic
    @Guide(description: "Exact words copied from the entry that support this tag") var quote: String
  }
  ```
- **Instructions:** suggestions not facts; no diagnoses or clinical terms; "helped" means only what the writer said helped; quote verbatim. When it fits, prefer reusing a label from the writer's existing vocabulary (the top 30 kept labels are passed in the prompt, which keeps "Find again" consistent).
- **Input limit:** entry text is truncated to 6,000 characters before prompting (the model's context is about 4K tokens). Quotes must come from the analyzed span.
- **`SuggestionSanitizer`** (pure, unit-tested):
  - Drops a tag whose quote isn't a case-sensitive substring. It retries a case-insensitive match and rewrites the quote to the exact casing found; if that fails, it drops the quote but keeps the tag if the label is non-empty.
  - Removes spans that overlap an earlier kept span.
  - Dedupes labels case-insensitively against the entry's existing tags.
  - Clamps to 5 and trims labels to 40 characters.
- **`RuleTagger`:** a port of the prototype's `RULES`/`analyze()`, used for the onboarding demo and as the deterministic engine in tests and UI tests.
- **`TaggingCoordinator`** (`@MainActor @Observable`):
  - `enqueue(entryID)` runs right after save. Save itself is synchronous and instant.
  - It keeps a per-entry `TaggingPhase`: `running`, `failed`, `none`, `unavailable`, `unsupported`, `off`, `done`.
  - It persists `Entry.taggingRaw`. On launch, entries still `pending` are re-enqueued, so "suggestions will be waiting" holds even if the app was killed.
  - It runs one request at a time. `concurrentRequests` and `rateLimited` errors back off once, then fail.
  - Error mapping: `guardrailViolation`, `refusal` → `none` (nothing to suggest); `exceededContextWindowSize` → retry once with 3,000 characters; everything else → `failed`.

### 5.3 Sol

- **Engine:** `FoundationModelSol` holds one `LanguageModelSession(instructions: SolPersona)` per conversation and calls `prewarm()` when the Sol screen appears.
- **Persona:** warm, brief (at most 2 sentences), asks one open question at a time, reflects the user's words back, never diagnoses or advises medically, never claims to be a therapist. After the second user turn, it may offer to turn the chat into a reflection.
- **Streaming:** each turn streams `SolTurn { reply: String; @Guide(.count(2)) suggestions: [String] }` via `streamResponse(to:generating:)`. Reply text renders as it streams, and the two quick-reply chips appear when the turn finishes. The opening message is static ("Hi. What's taking up the most room in your head tonight?"), with first-turn chips taken from the prototype.
- **Overflow:** on `exceededContextWindowSize`, start a new session whose instructions include a condensed transcript (the last 4 turns), then retry once.
- **Reflection:** `draftReflection(userMessages:)` returns a `@Generable Reflection { text }` written in the first person *only from the user's own messages*, ending with "One thing I'd like to try this week: ". On failure it falls back to the prototype's template (`ReflectionTemplate`). The draft is editable, and saving creates an Entry in Reflections with mode `sol` (counts toward the streak) and enqueues tagging.
- **Gates (prototype copy):** unsupported → "Try Guided reflection"; Sol turned off → "turn back on in On-device AI"; not ready → "Open On-device AI".
- **Safety (D17):** `CrisisSignal` matches a small keyword set (self-harm or suicide phrasing). On a match, or on a guardrail error, Sol shows the Support card inline instead of a model reply.
- **Length cap (D22):** the 12-turn soft cap is enforced in `SolConversation` (MementoCore, unit-tested). The persona also tells Sol never to encourage reliance on itself and to point toward people the user trusts when that fits.
- **Lifetime:** the conversation is never persisted. Closing Sol discards it unless the user saves a reflection ("not saved unless you choose").

## 6. Screens & behavior (parity with the prototype)

All copy, ordering, and states are taken from the prototype unless noted.

| Screen | Notes |
|---|---|
| Onboarding 1–4 | Page dots. (1) hero illustration + "A journal that helps you notice." (2) demo: "Find the details" → "Reading the entry…" (1.5 s, or 0.4 s with Reduce Motion) → suggestion rows with Keep / ✕ / Undo, tap a row to highlight its words; Continue is locked until suggestions show. (3) "Walking helped" find-again card. (4) Private by design + live `AIAvailability` card; finish label varies by state. Skip goes to step 4. |
| Journal | Date eyebrow, time greeting, streak number + week strip (Mon–Sun; filled = entry that day; today dashed), "Tonight" prompt card with Write freely / Brain dump · 3 min / Guided, pending-review dashed row, Revisit card (top "helped" tag with ≥2 entries), Recent entry cards (date · notebook, mode, photo, excerpt, ≤3 kept chips, +N, "N to review"). Empty journal uses the `empty-journal` illustration with "Your first entry can be one sentence." |
| Write sheet | 4 mode rows (custom geometric icons from the design) + dashed "Reflect with Sol" row with the `sol-mark` illustration. |
| Editor | Cancel / notebook picker / Save (disabled when empty). Segmented Free · Brain dump · Guided · Photo; switching keeps the text. Brain dump has a 3:00 mono timer with Start/Pause/Resume/Again, a progress bar, and notes. Guided has a sticky prompt card with category chips and "Another prompt". Photo uses Camera + PhotosPicker, with Replace. Speak (on-device dictation), "Use example" (kept in every build for live demos), and a word count. |
| Entry detail | Back, "Saved ✓" pill after a fresh save, Move. Meta line, guided prompt, photo, annotated text (dashed underline = suggested, 40% highlighter = kept, tap focuses the row). Details section: running / failed / none / unavailable / unsupported cards; SUGGESTED · N with Keep all, rows with chip (tap = edit), kind, quote, ✕, Keep; KEPT chips with counts, Edit/Done mode; "+ Add a tag" form sheet. Every removal has a 4.5 s toast with Undo; Keep all also has Undo. |
| Tag form sheet | Label field, KIND segmented, "Based on your words" quote, YOUR TAGS quick picks (add mode), Remove tag (edit mode). Editing marks the tag kept + edited. |
| Move sheet | 4 notebook rows with cover swatches and ✓. Moving shows a toast with Undo. |
| Tag detail | Kind eyebrow in category color, title, meta (entries · notebooks · date range), dot timeline over the month span of its entries, entry cards with highlighted quote, "Also kept in these entries" (co-occurrence ≥2, top 5), the not-causation caveat, and "Summarize these N entries". |
| Discover | Search field, basis line, pending row, four groups (Feelings / Situations / What helped / Topics) of kept chips with counts, entry results for queries of ≥2 characters, "Make a summary" card. Empty state uses the `empty-discover` illustration. |
| Notebooks | 2-column grid of cloth covers (generated textures) with label plates, name, and count. |
| Notebook detail | Cover band header, count, search, tag filter chips, cards with Move, and an empty-match message with the `empty-search` illustration. |
| You | Streak card; Daily reminder / Summaries / Reflect with Sol; On-device AI / Appearance / Export journal / Replay welcome; Demo (D23): Load sample journal / Clear journal / AI state override. |
| Reminders | Toggle, time picker, presets 8:00 / 12:30 / 20:30 / 22:00, lock-screen preview card with the app icon, caption, "How streaks work". Schedules a single repeating `UNCalendarNotificationTrigger` with the body "A few lines tonight? Even one sentence counts." Permission is requested on first enable. |
| On-device AI | State card (§5.1); toggles for "Suggest tags after saving" and "Sol conversations"; "Managed by Apple Intelligence" row (replaces Remove, D2); "What happens to your writing" copy. |
| Sol | Header "Sol · On this iPhone · not saved unless you choose", disclaimer card, streaming messages (Sol in Newsreader 20 pt, user in terracotta-tint bubbles), "Sol is thinking…" until the first token, quick replies, input + Send, "Turn this into a reflection" after the first exchange. |
| Sol draft | "Your reflection", editable text card, Save to journal, Discard conversation. |
| Summary | Step 0: For me / For my psychologist or psychiatrist; entry selection with presets (Last 2 weeks, All entries, top-2 kept tags, Clear); "Include my original words" toggle; "Only tags I've kept · Always"; clinician note; optional Prepared-by name (clinician only). Step 1: paper preview identical to the prototype's PDF card; Export PDF… opens the share sheet. |
| Export journal | Paginated PDF of all entries (date, notebook, text, kept tags), shared via the share sheet. |
| Toast | Ink capsule at the bottom with an optional Undo, 4.5 s. |

**Accessibility:** every tappable has a ≥44 pt target and an accessibility label. Chips expose "suggested"/"kept" in their accessibility value. Large text scales layouts (stacks reflow vertically at accessibility sizes). Reduce Motion shortens the demo and tagging animations and removes the switch and progress transitions.

## 7. Design system

- **Colors:** asset-catalog color sets with light and dark appearances, using the prototype's exact tokens:
  - Light: page #E9E2D5, bg #F6F1E7, card #FFFCF6, sheet #FBF7EF, ink #2B2723, mut #6F675D, line #E3DACA, ter #A85A38, onTer #FFFFFF, terT #F2E1D4, sage #56724F, sageT #DFE7D8, umb #765F4A, umbT #ECE2D6, slate #56616C, slateT #E2E5E7, danger #B3402E.
  - Dark: the `DARK` map from the prototype.
- **Category → color:** feeling → ter, situation → umb, helped → sage, topic → slate.
- **Type:**
  - Newsreader: display titles (34–42), entry text (21/1.55), prompts (italic).
  - SF Pro: UI text (13–17).
  - JetBrains Mono: eyebrows and the timer.
  - All use `Font.custom(_:size:relativeTo:)`.
- **Components:** `TagChip` (suggested dashed / kept filled, small and regular), `FilterChip`, `SegmentedPill`, `SageToggleStyle` (51×31 track), `PaperCard`, `Eyebrow`, `PrimaryButton` / `OutlineButton` / `InkButton`, `Toast`, `PaperIllustration` (asset inside a cream card with a 1 px line border and 20–28 pt radius), `NotebookCover`, `AnnotatedText`.
- **`AnnotatedText`:** builds an `AttributedString` from `TextSegments`. Each mark carries a custom `TextAttribute` (category, status, active) and a `memento://tag/<uuid>` link. A `TextRenderer` draws dashed underlines (suggested), a 40%-height highlighter (kept), or a full tint plus 3 pt halo (active) behind the glyph runs. `.tint(ink)` keeps link text ink-colored, and an `OpenURLAction` handles taps. Fallback if the renderer misbehaves: native `underlineStyle(.patternDash)` and `backgroundColor` attributes.

## 8. Personality: Codex-generated illustrations

**Style bible ("Paper & Olive"):** layered cut-paper illustration with visible paper fiber, soft contact shadows between layers, slightly imperfect hand-cut edges, and matte, even light.
- Palette: cream #FFFCF6 / #FBF7EF, terracotta #A85A38, sage #56724F / #DFE7D8, umber #765F4A, slate #56616C, sand #C8B186, with ink #2B2723 only for tiny accents.
- Composition: one focal subject, generous negative space, flat #FFFCF6 background edge to edge.
- Never: text, letters, numbers, logos, faces, or photorealism (except the sample photo).

| Asset | Size | Used in |
|---|---|---|
| **Wave 1: brand & anchor** | | |
| `onb-hero` (style anchor) | 1024×1024 | Onboarding 1: an olive sprig laid across an open notebook |
| `onb-private` | 1024×1024 | Onboarding 4: a closed notebook held shut by an olive-leaf band, small paper lock |
| `sol-mark` | 1024×1024 | Sol avatar, header, Write sheet row: a small layered paper sun with soft rays; must read at 40 pt |
| `app-icon` | 1024×1024 | AppIcon: a cream paper-cut olive sprig on full-bleed terracotta paper (no corner rounding) |
| **Wave 2A: notebook covers** | | |
| `cover-daily` / `cover-work` / `cover-gratitude` / `cover-reflections` | 1024×1536 | Bookcloth in #B4633F / #3B3733 / #7F9679 / #C8B186 with a small paper-cut emblem (sun-and-moon / paper plane / olive branch / crescent over water) in the lower third; upper 55% plain for the label plate. Used for grid covers and the notebook-detail band |
| **Wave 2B: spots & empty states** | | |
| `onb-notice` | 1024×1024 | Onboarding 2 header spot: a paper magnifier resting on a page with three small colored paper tabs |
| `onb-find` | 1024×1024 | Onboarding 3 header spot: three paper pages joined by a single sage thread |
| `empty-journal` | 1024×1024 | Empty Journal: an open blank notebook with a pencil and a single sprig |
| `empty-discover` | 1024×1024 | Empty Discover: a row of small paper sprouts |
| `empty-search` | 1024×1024 | No matches: paper leaves under a paper magnifier |
| `ai-unavailable` | 1024×1024 | AI unsupported / Sol gate: a paper crescent moon resting over a notebook |
| `sample-ceramics` | 1536×1024 | Sample journal photo entry: a warm film-style photo of a lopsided handmade ceramic bowl |
| **Wave 2C: UI accents** | | |
| `mode-free` / `mode-dump` / `mode-guided` / `mode-photo` | 1024×1024 | Write-sheet icons (40 pt): paper-cut versions of the design's shapes. Free = rounded terracotta-tint square with a folded corner; Dump = terracotta paper ring with a small swirl; Guided = terracotta diamond with a tiny compass star; Photo = cream frame with a small terracotta sun. Must read at 40 pt |
| `kind-feeling` / `kind-situation` / `kind-helped` / `kind-topic` | 1024×1024 | Discover group and tag-detail emblems (28 pt): terracotta heart-shaped leaf / umber paper house with a lit window / sage sprig / slate folded paper note |
| `reminder-scene` | 1024×1536 | Lock-screen preview backdrop in Reminders (replaces the prototype's #CDBFA8→#9C8C74 gradient): a paper-cut dusk landscape of layered sand hills and a low sun, calm, with the upper third quiet for the clock |
| `streak-sprout` | 1024×1024 | You streak card ornament: a small paper sprout with three leaves, terracotta-tint pot |
| `tonight-ornament` | 1024×1024 | Journal "Tonight" card corner: a paper crescent moon with two tiny stars |
| `paper-grain` | 1024×1024 | Seamless, very subtle cream paper fiber texture, tiled at 25% opacity over `bg` and `card` for tactility. Only used if it tiles without visible seams; otherwise dropped |

**UX rules for using the assets:**
- Illustrations never carry information on their own. Every one sits beside text that says the same thing, and VoiceOver treats them as decorative (`accessibilityHidden`).
- Spots are 120–200 pt; icons are 28–44 pt.
- With Reduce Motion off, onboarding spots fade and rise 8 pt on appear (0.35 s ease-out).
- In dark mode they stay inside their cream paper card (D19); the icons and emblems sit on a `card`-colored disc so the cream background reads as intentional.

**Orchestration (images only, D18):**
1. Claude writes `design-assets/STYLE.md` (the style bible) and creates an Orca Run.
2. **Wave 1:** one Codex worker generates `onb-hero` (the style anchor), then `onb-private`, `sol-mark`, and `app-icon`.
3. **Wave 2,** started after Wave 1 is accepted: three Codex workers run in parallel (2A covers, 2B spots and empty states, 2C UI accents). Each first views `onb-hero.png` and `sol-mark.png` with `view_image` to match the style.
4. **Task specs** follow the Orca contract (Target, Change, Constraints, Ownership, Observable acceptance). Each worker:
   - writes only to `design-assets/generated/<asset>.png` and `<asset>.prompt.md`;
   - never touches Swift, the Xcode project, or git;
   - reports through `worker_done`.
5. Claude inspects every image (viewing it, checking dimensions, the "no text" rule, and palette fit). It re-dispatches a rejected asset with notes, at most 2 retries per asset.
6. Claude imports accepted images into `Assets.xcassets`: resized with `sips` (spots to 768 px, icons and emblems to 256 px, covers and the reminder scene to 768×1152), converted to compressed PNG, with the AppIcon as a single 1024 image with alpha stripped.
7. **Swift work proceeds in parallel** against named placeholder assets, so image generation never blocks the build.

The generated originals are git-ignored; the prompts and processed catalog assets are committed.

## 9. Error handling

- Saving can't fail silently. If a SwiftData save throws, the editor keeps the draft and shows "Couldn't save — your words are still here."
- Every AI failure leaves the entry exactly as written (the prototype's copy).
- Dictation permission denied → the Speak button shows an inline note linking to Settings.
- Notification permission denied → the Reminders toggle reverts and the caption explains how to enable it in Settings.
- Photo too large → the image is downscaled to 2048 px and stored as JPEG at 0.85 quality.
- PDF render failure → a toast reading "Couldn't make the PDF."

## 10. Testing & verification

- **`swift test` (MementoCore), TDD for all domain logic:**
  - `TagIndex` counts (kept only, case-insensitive)
  - `Streak` and the week strip
  - `TextSegments` (overlaps, missing quotes)
  - `SuggestionSanitizer`
  - `RuleTagger` parity with the prototype on the demo text and the editor examples
  - `SummaryComposer` (me vs clinician, groups, quotes, range)
  - `TaggingCoordinator` phases with stub engines (success / none / failed / unavailable / off / re-enqueue pending)
  - `ReflectionTemplate`
  - `CrisisSignal`
  - The Foundation Models tagger and Sol run as integration tests that skip when `SystemLanguageModel.default.availability != .available`.
- **XCUITest on the iPhone 17 Pro (iOS 26.5) simulator,** with launch args `-uiTesting -seedSampleData -taggingEngine rules -solEngine scripted`:
  1. Onboarding → Journal.
  2. Write → Free → type → Save → Entry shows "Saved ✓" → suggestions appear → Keep → chip becomes kept → tap it → Tag detail lists the entry.
  3. **Sol streaming returns to idle:** send a message → "Sol is thinking…" appears → reply text appears → "Sol is thinking…" is gone and Send is enabled again.
  4. Summary → Preview shows the selected count.
  5. Removing a tag shows the Undo toast, and Undo restores it.
- **Visual check:** simulator screenshots of the 12 primary screens in light, dark, and the accessibility XL text size, compared against the prototype rendered via Playwright. Discrepancies get fixed or listed.
- **Real local AI check:** run on the simulator with `-taggingEngine foundation` on this Mac (M5, macOS 26.5). If Apple Intelligence is unavailable to the simulator, report it as a blocker and note that on-device verification needs a physical iPhone 15 Pro or newer.

## 11. Hackathon demo

- **Target device:** an iPhone that supports Apple Intelligence (iPhone 15 Pro or newer, any iPhone 16 or 17) on iOS 26, with Apple Intelligence turned on and its model downloaded *before* the demo.
- **Install:** Xcode, with automatic signing under the user's personal team.
- **Demo script** (`docs/demo-script.md`, about 3 minutes):
  1. The onboarding demo.
  2. Load the sample journal.
  3. Write freely → Use example → Save. Live on-device suggestions appear; Keep two.
  4. Tap "Walking helped" → tag detail → Summarize → clinician preview.
  5. Reflect with Sol → stream a reply → turn it into a reflection.
  6. Turn on **airplane mode** and repeat a suggestion to prove it runs locally.
  7. Show the AI-state override (unsupported, Getting ready) to show the app degrades gracefully.
- **Pre-demo checklist** (in the script): battery and Low Power Mode off (it can slow the model), Apple Intelligence ready, sample journal loaded, Reduce Motion off, Do Not Disturb on, and a mirroring setup tested.
- **Later, for an App Store release (not in this build):**
  - privacy manifest
  - privacy policy and nutrition label ("Data Not Collected")
  - export-compliance key
  - no-alpha icon check
  - OFL font acknowledgements
  - age-rating answers (wellness / AI assistant)
  - store metadata and review notes
  - 6.9" screenshots
  - moving the Demo section behind a hidden gesture
  - an "Erase journal" control

## 12. Out of scope (v1)

- Creating or renaming notebooks.
- iCloud sync.
- iPad and Mac layouts.
- Widgets.
- Lock with Face ID.
- Search over Sol transcripts (they aren't stored).
- Localization beyond English.

All are natural follow-ups.
