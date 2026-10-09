# Memento for iPhone: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native SwiftUI iPhone app that recreates the Memento prototype. It writes and saves instantly, suggests tags with Apple's on-device Foundation Models, finds tagged moments again, chats with Sol on-device, and wears a Codex-generated paper-cut asset kit.

**Architecture:** A hand-written Xcode 26 project (file-system-synchronized folders). It has a UI-only app target and a local Swift package, `MementoCore`, that holds the SwiftData models, pure domain logic, and the AI engines behind protocols. Codex workers, dispatched through Orca orchestration, generate *only* images, in parallel with the Swift work. Claude writes all of the code.

**Tech Stack:** Swift 6, SwiftUI (iOS 26), SwiftData, FoundationModels, Speech, UserNotifications, PhotosUI, UIGraphicsPDFRenderer, Swift Testing, XCUITest, Orca orchestration + Codex image generation, Playwright (prototype reference renders only).

**Spec:** `docs/superpowers/specs/2026-10-09-memento-ios-design.md`
**Design source of truth for markup and copy:** `design-reference/Memento Prototype.dc.html`. Line references below (e.g. *proto L175–221*) point into this file.

## Global Constraints

- iOS deployment target **26.0**, iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait.
- Swift 6 language mode. The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; `MementoCore` stays nonisolated by default.
- `MementoCore` must not import SwiftUI or UIKit.
- No network calls anywhere in the app. All AI is `FoundationModels` (or the deterministic demo engines).
- Only **kept** tags count in Discover, tag detail, summaries, revisit, and co-occurrence. **Removed** tags stay stored, for Undo.
- Edited tags (`isEdited`) and kept tags are never modified by re-tagging.
- Copy is taken verbatim from the prototype unless the spec's decisions table (D1–D26) changes it.
- Color tokens, light: page #E9E2D5, bg #F6F1E7, card #FFFCF6, sheet #FBF7EF, ink #2B2723, mut #6F675D, line #E3DACA, ter #A85A38, onTer #FFFFFF, terT #F2E1D4, sage #56724F, sageT #DFE7D8, umb #765F4A, umbT #ECE2D6, slate #56616C, slateT #E2E5E7, danger #B3402E.
- Color tokens, dark: page #121110, bg #1B1916, card #25221E, sheet #211E1B, ink #EEE7DB, mut #A89F92, line #38332D, ter #DB906B, onTer #1B1916, terT #3E2B21, sage #A3BC9C, sageT #27322A, umb #CDB298, umbT #352D25, slate #AEB8C2, slateT #2A2F34, danger #E07A66.
- Tag kind → color: feeling → ter, situation → umb, helped → sage, topic → slate.
- Bundle ID `com.kand221.memento`, display name `Memento`, automatic signing, `DEVELOPMENT_TEAM` empty.
- Simulator for all verification: `platform=iOS Simulator,name=iPhone 17 Pro` (iOS 26.5).
- Codex workers write only under `design-assets/generated/`. They never touch Swift, the Xcode project, or git.
- Public repo `Kands221/memento`; `design-reference/support.js` stays git-ignored.
- Commit after every task. Push to `origin main` after each phase (`git push origin app:main`), and only when that phase's build and tests exit 0 (`&&`-gated).

## Review Focus

1. **Very long entries** (well past the model's ~4K-token context): tagging must analyze only the first 6,000 characters, never crash, and still produce quotes that exist in the full text. *Test owned by Task 8* (`truncatesLongEntriesBeforeCallingEngine`).
2. **Model output that doesn't match the text** (smart quotes, wrong casing, invented quotes, duplicate labels, overlapping spans): no broken highlight, no duplicate chip. *Tests owned by Task 6* (`SuggestionSanitizerTests`).
3. **Entry deleted while tagging is in flight** (Demo → Clear journal mid-run): the coordinator must not crash or resurrect it. *Test owned by Task 8* (`deletedEntryDuringTaggingIsIgnored`).
4. **Sol double-send and stream failure** (tapping Send twice, the engine throwing mid-stream): one user message, a fallback reply, and the UI back to idle with Send enabled. *Tests owned by Task 9* (`sendWhileRespondingIsIgnored`, `streamFailureFallsBackAndReturnsToIdle`).
5. **Emoji and combining characters in entries**, and **case-variant labels across entries** ("walking helped" vs "Walking helped"): highlights land on the right characters, and counts merge case-insensitively. *Tests owned by Task 5* (`segmentsHandleEmoji`) and *Task 4* (`labelsMergeCaseInsensitively`).

---

## File Structure

```
.gitignore
README.md                                   Task 26
Memento.xcodeproj/project.pbxproj           Task 2 (hand-written, objectVersion 77)
Memento.xcodeproj/xcshareddata/xcschemes/Memento.xcscheme
Config/Info.plist                           UIAppFonts only (rest via INFOPLIST_KEY_*)
Memento/
  App/        MementoApp.swift, AppModel.swift, Route.swift, LaunchOptions.swift,
              Settings.swift, AIStatus.swift, AppServices.swift, RootView.swift
  DesignSystem/ Palette.swift, Typography.swift, Chips.swift, Controls.swift,
              Surfaces.swift, Toast.swift, PaperArt.swift, NotebookCover.swift,
              AnnotatedText.swift, MementoTabBar.swift, Screen.swift
  Features/
    Onboarding/OnboardingView.swift
    Journal/JournalView.swift, EntryCard.swift
    Write/WriteSheet.swift, EditorView.swift, BrainDumpTimer.swift
    Entry/EntryDetailView.swift, TagFormSheet.swift, MoveSheet.swift
    Tag/TagDetailView.swift
    Discover/DiscoverView.swift
    Notebooks/NotebooksView.swift, NotebookDetailView.swift
    You/YouView.swift, RemindersView.swift, OnDeviceAIView.swift, DemoSection.swift
    Sol/SolView.swift, SolDraftView.swift, SupportCard.swift
    Summary/SummaryView.swift, SummaryPreview.swift
  Services/   ReminderScheduler.swift, DictationService.swift, PDFComposer.swift,
              PhotoProcessing.swift, CameraPicker.swift
  Resources/  Assets.xcassets/, Fonts/*.ttf
Packages/MementoCore/
  Package.swift
  Sources/MementoCore/
    Models/   Kinds.swift, Notebook.swift, Entry.swift, TagMark.swift, MementoStore.swift
    Domain/   DateLabels.swift, Excerpt.swift, TagIndex.swift, Streak.swift,
              JournalInsights.swift, TextSegments.swift, SummaryComposer.swift
    AI/       AIAvailability.swift, TaggingEngine.swift, RuleTagger.swift,
              SuggestionSanitizer.swift, FoundationModelTagger.swift,
              SolEngine.swift, SolConversation.swift, ScriptedSol.swift,
              FoundationModelSol.swift, ReflectionTemplate.swift, CrisisSignal.swift
    Services/ TaggingCoordinator.swift
    Sample/   SampleJournal.swift
  Tests/MementoCoreTests/  TestSupport.swift + one file per unit
MementoUITests/ MementoUITests.swift, ScreenshotTour.swift
design-assets/  STYLE.md, briefs/*.md, generated/ (git-ignored), accepted/ (processed copies)
design-reference/ Memento Prototype.dc.html (committed), support.js (ignored)
docs/demo-script.md                          Task 26
```

**Phases** (the image waves run in the background throughout):

| Phase | Tasks | Content |
|---|---|---|
| A | 1–2 | Kickoff: dispatch image Wave 1, scaffold the project |
| B | 3–10 | MementoCore with TDD, tested by `swift test` |
| C | 11–13 | Design system, app shell, AnnotatedText |
| D | 14–22 | Features, UI tests |
| E | 23–26 | Image review and import, visual QA against the prototype, real on-device AI check, README and demo script |

Run `swift test` from the package directory:

```bash
cd Packages/MementoCore && swift test
```

Build and test the app:

```bash
xcodebuild -project Memento.xcodeproj -scheme Memento \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DD build
xcodebuild -project Memento.xcodeproj -scheme Memento \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DD test
```

---

### Task 1: Asset style bible, briefs, and Wave 1 dispatch (Orca + Codex, images only)

**Files:**
- Create: `design-assets/STYLE.md`
- Create: `design-assets/briefs/wave1.md`, `wave2a.md`, `wave2b.md`, `wave2c.md`

**Interfaces:**
- Produces: an Orca Run ID (recorded in `design-assets/RUN.md`, committed) and the Wave 1 Dispatch. Asset names are exactly those in spec §8; Swift code references them by these names.

- [ ] **Step 1: Write the style bible**

```markdown
<!-- File: design-assets/STYLE.md -->
# Memento illustration style — "Paper & Olive"

Medium: layered cut-paper illustration photographed flat. Visible paper fibre, slightly
imperfect hand-cut edges, soft contact shadows between layers (1–3 px feel), matte, even
north-window light. Calm, warm, quiet. Never glossy, never 3D-rendered plastic, never vector-flat.

Palette (use only these):
- cream paper #FFFCF6 and #FBF7EF (backgrounds, light layers)
- terracotta #A85A38 and its tint #F2E1D4
- sage #56724F and its tint #DFE7D8
- umber #765F4A, slate #56616C, sand #C8B186
- ink #2B2723 only for tiny accents (a pencil tip, a seed)

Composition: one focal subject, centred within the middle 70% of the frame, generous empty
margin. Background is flat #FFFCF6 edge to edge unless a brief says otherwise.

Never: text, letters, numbers, logos, watermarks, signatures, UI, people, faces, hands,
photorealism (except where a brief explicitly asks for a photo).
```

- [ ] **Step 2: Write the Wave 1 brief.** It doubles as the Orca task spec.

```markdown
<!-- File: design-assets/briefs/wave1.md -->
Target: Memento iPhone app illustration kit — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it exactly.

Change: with your built-in image generation tool, create these PNGs, one generation per asset:
1. onb-hero (1024x1024): an olive sprig with five or six sage leaves laid diagonally across an
   open cream notebook seen from above; a small terracotta paper bookmark ribbon. STYLE ANCHOR —
   do this first and make it excellent.
2. onb-private (1024x1024): a closed cream notebook held shut by a band made of sage paper olive
   leaves, with a tiny terracotta paper padlock on the band.
3. sol-mark (1024x1024): a small round paper sun — layered terracotta-tint and sand discs with
   eight short soft rays — centred with wide margin. Must stay legible scaled down to 40 pt.
4. app-icon (1024x1024): FULL-BLEED terracotta #A85A38 paper background (no cream, no border,
   no rounded corners); a cream paper-cut olive sprig curving across the centre, two sage leaves.
Before generating 2–4, open design-assets/generated/onb-hero.png with view_image and match its
paper texture, shadow depth, cut style and palette.

After each generation copy the PNG from the path the image tool reports (normally under
~/.codex/generated_images/) to design-assets/generated/<name>.png and write
design-assets/generated/<name>.prompt.md containing the exact final prompt you used.
If an image contains any text/letters or breaks STYLE.md, regenerate it (max 3 tries each).

Constraints: follow STYLE.md; no text of any kind in images.
Ownership: create files ONLY under design-assets/generated/. Do not edit Swift code, the Xcode
project, docs, or any other file. Do not run git commands.
Observable acceptance: 4 PNGs + 4 .prompt.md files exist in design-assets/generated/;
`sips -g pixelWidth -g pixelHeight design-assets/generated/*.png` shows ≥1024 px on the short
side; you viewed every final image and confirmed it has no text. List the files in worker_done.
If image generation is unavailable, send worker_done with --outcome failed and say why.
```

- [ ] **Step 3: Write the Wave 2 briefs.** Same header, footer, and constraints as Wave 1, but each lists its own assets and says "Before generating anything, open design-assets/generated/onb-hero.png and design-assets/generated/sol-mark.png with view_image and match them."
  - `wave2a.md` has the four covers. Each is 1024x1536 bookcloth. Daily is terracotta-red cloth #B4633F with a paper sun-and-moon emblem. Work is charcoal cloth #3B3733 with a cream paper plane. Gratitude is sage cloth #7F9679 with a cream olive branch. Reflections is sand cloth #C8B186 with a slate crescent over two wave strips. The emblem sits in the lower third, the upper 55% stays plain cloth, the background is the cloth itself (not cream), and nothing else is in the frame.
  - `wave2b.md` has `onb-notice`, `onb-find`, `empty-journal`, `empty-discover`, `empty-search`, `ai-unavailable` (1024x1024), and `sample-ceramics`. `sample-ceramics` is 1536x1024 and is the ONE photographic image: a warm natural-light film photo of a lopsided handmade speckled ceramic bowl on a pale oak table, shallow depth of field, no people.
  - `wave2c.md` has `mode-free`, `mode-dump`, `mode-guided`, `mode-photo`, `kind-feeling`, `kind-situation`, `kind-helped`, `kind-topic`, `streak-sprout`, `tonight-ornament` (1024x1024, each a single bold shape filling the central 60% so it reads at 28–40 pt), `reminder-scene` (1024x1536 dusk landscape of layered sand and umber paper hills under a low terracotta sun, with the upper third plain sky for a clock), and `paper-grain` (1024x1024 seamless, very low-contrast cream paper fibre, no objects, must tile without visible seams).
  - The subject descriptions are the ones in spec §8, copied verbatim into each brief.

- [ ] **Step 4: Create the Run and start Wave 1**

```bash
orca status --json | head -5
orca orchestration run-create --objective "Generate Memento paper-cut asset kit (images only)" --json
orca orchestration worker-start --spec "$(cat design-assets/briefs/wave1.md)" \
  --task-title "Wave 1: brand + style anchor images" --worktree current --agent codex --json
```

Expected: both calls return `"ok": true`. Record the run ID, task ID, and dispatch ID in `design-assets/RUN.md`.

- [ ] **Step 5: Start a background wait.** Run this with `run_in_background` and keep working on Task 2 meanwhile:

```bash
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
```

When it returns, process the message per the orchestration guide: answer questions with `orchestration reply`, and send a `worker_done` to Task 23. Then acknowledge with `check --ack <delivery_id>`.

- [ ] **Step 6: Commit**

```bash
git add design-assets/STYLE.md design-assets/briefs design-assets/RUN.md
git commit -m "Add paper-cut asset style bible and Codex briefs; dispatch Wave 1"
```

---

### Task 2: Project scaffold (Xcode project, scheme, package, blank app)

**Files:**
- Create: `Memento.xcodeproj/project.pbxproj`, `Memento.xcodeproj/xcshareddata/xcschemes/Memento.xcscheme`
- Create: `Config/Info.plist`, `Memento/App/MementoApp.swift`, `Memento/Resources/Assets.xcassets/{Contents.json, AppIcon.appiconset/Contents.json, AccentColor.colorset/Contents.json}`
- Create: `Memento/Resources/Fonts/{Newsreader-Variable.ttf, Newsreader-Italic-Variable.ttf, JetBrainsMono-Variable.ttf}`
- Create: `Packages/MementoCore/Package.swift`, `Packages/MementoCore/Sources/MementoCore/MementoCore.swift`, `Packages/MementoCore/Tests/MementoCoreTests/SmokeTests.swift`
- Create: `MementoUITests/MementoUITests.swift`

**Interfaces:**
- Produces: the scheme `Memento` (builds the app and runs `MementoUITests`), the package product `MementoCore`, and font family names that Task 11 verifies.

- [ ] **Step 1: Package manifest and a smoke test**

```swift
// File: Packages/MementoCore/Package.swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MementoCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "MementoCore", targets: ["MementoCore"])],
    targets: [
        .target(name: "MementoCore"),
        .testTarget(name: "MementoCoreTests", dependencies: ["MementoCore"]),
    ]
)
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/MementoCore.swift
/// MementoCore: models, domain logic and on-device AI engines for Memento.
public enum MementoCore {
    public static let version = "1.0"
}
```

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/SmokeTests.swift
import Testing
@testable import MementoCore

@Test func packageLoads() {
    #expect(MementoCore.version == "1.0")
}
```

Run `cd Packages/MementoCore && swift test`. Expected: `Test run with 1 test passed`.

- [ ] **Step 2: Fonts (SIL OFL, google/fonts).** Download into a fresh directory, then copy the files in under fixed names.

```bash
D=$(mktemp -d) && cd "$D" && \
curl -fsSLo nr.ttf  "https://raw.githubusercontent.com/google/fonts/main/ofl/newsreader/Newsreader%5Bopsz,wght%5D.ttf" && \
curl -fsSLo nri.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/newsreader/Newsreader-Italic%5Bopsz,wght%5D.ttf" && \
curl -fsSLo jb.ttf  "https://raw.githubusercontent.com/google/fonts/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf" && \
file nr.ttf nri.ttf jb.ttf
```

Expected: all three report `TrueType Font data`. Copy them to `Memento/Resources/Fonts/` as `Newsreader-Variable.ttf`, `Newsreader-Italic-Variable.ttf`, and `JetBrainsMono-Variable.ttf`.

- [ ] **Step 3: Info.plist (fonts only; every other key comes from build settings)**

```xml
<!-- File: Config/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>UIAppFonts</key>
	<array>
		<string>Newsreader-Variable.ttf</string>
		<string>Newsreader-Italic-Variable.ttf</string>
		<string>JetBrainsMono-Variable.ttf</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Write `project.pbxproj`.**
  - Object IDs are `4D00000000000000000000NN`:
    - project `01`, main group `02`, products group `03`
    - Memento.app `04`, MementoUITests.xctest `05`
    - synced root groups `06` (path `Memento`) and `07` (path `MementoUITests`)
    - native targets `08` (application) and `09` (ui-testing, `TestTargetID = 08`)
    - build phases: app `0A` Sources / `0B` Frameworks / `0C` Resources; tests `0D` / `0E` / `0F`
    - container proxy `10`, target dependency `11`
    - `XCLocalSwiftPackageReference` `12` (`relativePath = Packages/MementoCore`)
    - `XCSwiftPackageProductDependency` `13` (`productName = MementoCore`)
    - `PBXBuildFile` `14` (`productRef = 13`, in phase `0B`)
    - configuration lists `15` / `18` / `1B`, with Debug/Release pairs `16`/`17`, `19`/`1A`, `1C`/`1D`
  - `objectVersion = 77` and `preferredProjectObjectVersion = 77`.
  - All build phases have empty `files = ()` except `0B`; the synchronized groups supply the sources and resources.
  - **Project-level settings** (Debug and Release both):
    - `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `SDKROOT = iphoneos`
    - `CLANG_ENABLE_MODULES = YES`, `CLANG_ENABLE_OBJC_ARC = YES`
    - `ENABLE_USER_SCRIPT_SANDBOXING = YES`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`
    - `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`
    - **Debug only:** `ONLY_ACTIVE_ARCH = YES`, `ENABLE_TESTABILITY = YES`, `GCC_OPTIMIZATION_LEVEL = 0`, `SWIFT_OPTIMIZATION_LEVEL = "-Onone"`, `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`, `GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)")`, `DEBUG_INFORMATION_FORMAT = dwarf`
    - **Release only:** `SWIFT_COMPILATION_MODE = wholemodule`, `VALIDATE_PRODUCT = YES`, `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"`
  - **App target settings:**
    - Identity and signing: `PRODUCT_NAME = "$(TARGET_NAME)"`, `PRODUCT_BUNDLE_IDENTIFIER = com.kand221.memento`, `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`, `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = ""`
    - Swift: `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_EMIT_LOC_STRINGS = YES`
    - Platform and assets: `TARGETED_DEVICE_FAMILY = 1`, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`, `ENABLE_PREVIEWS = YES`, `LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks")`
    - Info.plist: `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_FILE = Config/Info.plist`, `INFOPLIST_KEY_CFBundleDisplayName = Memento`, `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES`, `INFOPLIST_KEY_UILaunchScreen_Generation = YES`, `INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`
    - `INFOPLIST_KEY_NSCameraUsageDescription = "Take a photo for a journal entry. Photos stay on this iPhone."`
    - `INFOPLIST_KEY_NSMicrophoneUsageDescription = "Speak an entry instead of typing. Audio is transcribed on this iPhone and not stored."`
    - `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "Turn your voice into text on this iPhone."`
  - **UI-test target settings:** `PRODUCT_BUNDLE_IDENTIFIER = com.kand221.mementoUITests`, `TEST_TARGET_NAME = Memento`, `GENERATE_INFOPLIST_FILE = YES`, `SWIFT_VERSION = 6.0`, `TARGETED_DEVICE_FAMILY = 1`, `CODE_SIGN_STYLE = Automatic`.

- [ ] **Step 5: Shared scheme.** Build action: target `08` (`Memento.app`). Test action: Debug, testable `09` (`MementoUITests.xctest`), not parallelizable. Launch action: `08`. Archive action: Release. `ReferencedContainer = "container:Memento.xcodeproj"`.

- [ ] **Step 6: Minimal app, asset catalog, and one UI test**

```swift
// File: Memento/App/MementoApp.swift
import SwiftUI

@main
struct MementoApp: App {
    var body: some Scene {
        WindowGroup { Text("Memento") }
    }
}
```

The asset catalog needs a `Contents.json` with `{"info":{"author":"xcode","version":1}}`, an AppIcon set with one `{"idiom":"universal","platform":"ios","size":"1024x1024"}` entry (no file yet), and an AccentColor set holding sRGB #A85A38 (light) and #DB906B (dark).

```swift
// File: MementoUITests/MementoUITests.swift
import XCTest

@MainActor
final class MementoUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
```

- [ ] **Step 7: Verify the project parses, builds, and tests**

```bash
xcodebuild -list -project Memento.xcodeproj
xcodebuild -project Memento.xcodeproj -scheme Memento -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DD build 2>&1 | tail -3
xcodebuild -project Memento.xcodeproj -scheme Memento -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DD test 2>&1 | tail -5
```

Expected: `-list` shows targets `Memento` and `MementoUITests` and scheme `Memento`. Then `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`. If the project fails to open, diff the structure against a fresh Xcode 26 template before changing anything else.

- [ ] **Step 8: Commit**

```bash
git add Memento.xcodeproj Config Memento MementoUITests Packages
git commit -m "Scaffold Xcode 26 project with MementoCore package, fonts, and UI test target"
```

---

### Task 3: Models and the in-memory store (MementoCore)

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/Models/{Kinds,Notebook,Entry,TagMark,MementoStore}.swift`
- Create: `Packages/MementoCore/Tests/MementoCoreTests/{TestSupport,ModelTests}.swift`

**Interfaces:**
- Produces:
  - `TagKind {feeling, situation, helped, topic}` (`singular`, `plural`, `shortLabel`)
  - `TagStatus {suggested, kept, removed}`
  - `WritingMode {free, dump, guided, photo, sol}` (`title`)
  - `TaggingStatus {pending, done, failed, skipped}`
  - `Notebook` (static `all`, `with(id:)`)
  - `@Model Entry` (`mode`, `tagging`, `notebook`, `orderedTags`, `suggestedTags`, `keptTags`, `visibleTags`, `quoteMarks`, `addTag(label:kind:quote:status:isManual:)`, `hasKept(label:)`)
  - `@Model TagMark` (`kind`, `status`)
  - `QuoteMark`
  - `MementoStore.container(inMemory:)`

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/TestSupport.swift
import Foundation
import SwiftData
@testable import MementoCore

enum Fixtures {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()
    /// Friday, October 9, 2026, 9:41 PM: the prototype's "today".
    static let today: Date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 21, minute: 41))!
    static func daysAgo(_ n: Int, hour: Int = 20, minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: -n, to: today)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
}

typealias TagSpec = (label: String, kind: TagKind, quote: String?, status: TagStatus)

@MainActor
struct TestStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws { container = try MementoStore.container(inMemory: true) }

    @discardableResult
    func entry(daysAgo: Int = 0, notebook: String = "daily", mode: WritingMode = .free,
               text: String = "Some words.", tags: [TagSpec] = []) -> Entry {
        let e = Entry(createdAt: Fixtures.daysAgo(daysAgo), notebookID: notebook, mode: mode, text: text, tagging: .done)
        context.insert(e)
        for t in tags { e.addTag(label: t.label, kind: t.kind, quote: t.quote, status: t.status) }
        return e
    }

    func all() throws -> [Entry] {
        try context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }
}
```

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/ModelTests.swift
import Testing
import SwiftData
@testable import MementoCore

@MainActor
@Suite struct ModelTests {
    @Test func tagsKeepInsertionOrderAndFilterByStatus() throws {
        let store = try TestStore()
        let e = store.entry(text: "I felt drained. A walk helped.", tags: [
            ("Drained", .feeling, "I felt drained", .kept),
            ("Walking helped", .helped, "A walk helped", .suggested),
            ("Old", .topic, nil, .removed),
        ])
        try store.context.save()
        #expect(e.orderedTags.map(\.label) == ["Drained", "Walking helped", "Old"])
        #expect(e.keptTags.map(\.label) == ["Drained"])
        #expect(e.suggestedTags.map(\.label) == ["Walking helped"])
        #expect(e.visibleTags.count == 2)
        #expect(e.quoteMarks.map(\.quote) == ["I felt drained", "A walk helped"])
        #expect(e.hasKept(label: "drained"))
    }

    @Test func enumsRoundTripThroughRawStorage() throws {
        let store = try TestStore()
        let e = store.entry(notebook: "refl", mode: .sol)
        e.tagging = .failed
        #expect(e.mode == .sol)
        #expect(e.tagging == .failed)
        #expect(e.notebook.name == "Reflections")
        #expect(Notebook.with(id: "nope") == .daily)
    }

    @Test func deletingEntryCascadesToTags() throws {
        let store = try TestStore()
        store.entry(tags: [("Calm", .feeling, nil, .kept)])
        try store.context.save()
        try store.context.delete(model: Entry.self)
        try store.context.save()
        #expect(try store.context.fetchCount(FetchDescriptor<TagMark>()) == 0)
    }
}
```

- [ ] **Step 2: Run them and confirm they fail.** Run `cd Packages/MementoCore && swift test`. Expected: compile errors (`cannot find 'Entry' in scope`).

- [ ] **Step 3: Implement**

```swift
// File: Packages/MementoCore/Sources/MementoCore/Models/Kinds.swift
import Foundation

public enum TagKind: String, Codable, CaseIterable, Sendable {
    case feeling, situation, helped, topic

    /// Label under a suggestion row ("Feeling", "What helped").
    public var singular: String {
        switch self {
        case .feeling: "Feeling"
        case .situation: "Situation"
        case .helped: "What helped"
        case .topic: "Topic"
        }
    }

    /// Discover group titles, tag-detail eyebrow and summary sections.
    public var plural: String {
        switch self {
        case .feeling: "Feelings"
        case .situation: "Situations"
        case .helped: "What helped"
        case .topic: "Topics"
        }
    }

    /// Segmented control in the tag form sheet.
    public var shortLabel: String {
        switch self {
        case .feeling: "Feeling"
        case .situation: "Situation"
        case .helped: "Helped"
        case .topic: "Topic"
        }
    }
}

public enum TagStatus: String, Codable, Sendable {
    case suggested, kept, removed
}

public enum WritingMode: String, Codable, CaseIterable, Sendable {
    case free, dump, guided, photo, sol

    public var title: String {
        switch self {
        case .free: "Write freely"
        case .dump: "Brain dump"
        case .guided: "Guided reflection"
        case .photo: "Photo journal"
        case .sol: "Sol reflection"
        }
    }
}

public enum TaggingStatus: String, Codable, Sendable {
    case pending, done, failed, skipped
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Models/Notebook.swift
import Foundation

/// The four fixed notebooks from the design (spec D20).
public struct Notebook: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// 0xRRGGBB cloth colour from the prototype.
    public let coverHex: UInt32
    /// Asset-catalog name of the generated cover.
    public let coverAsset: String

    public static let daily = Notebook(id: "daily", name: "Daily", coverHex: 0xB4633F, coverAsset: "cover-daily")
    public static let work = Notebook(id: "work", name: "Work", coverHex: 0x3B3733, coverAsset: "cover-work")
    public static let gratitude = Notebook(id: "grat", name: "Gratitude", coverHex: 0x7F9679, coverAsset: "cover-gratitude")
    public static let reflections = Notebook(id: "refl", name: "Reflections", coverHex: 0xC8B186, coverAsset: "cover-reflections")

    public static let all: [Notebook] = [.daily, .work, .gratitude, .reflections]

    public static func with(id: String) -> Notebook {
        all.first { $0.id == id } ?? .daily
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Models/TagMark.swift
import Foundation
import SwiftData

@Model
public final class TagMark {
    @Attribute(.unique) public var id: UUID
    public var label: String
    public var kindRaw: String
    /// Verbatim substring of the entry text, or nil for tags without a quote.
    public var quote: String?
    public var statusRaw: String
    public var isManual: Bool
    /// Renamed or re-kinded by the writer; never overwritten by suggestions.
    public var isEdited: Bool
    /// Stable display order within the entry.
    public var position: Int
    public var entry: Entry?

    public init(id: UUID = UUID(), label: String, kind: TagKind, quote: String? = nil,
                status: TagStatus = .kept, isManual: Bool = false, isEdited: Bool = false, position: Int = 0) {
        self.id = id
        self.label = label
        self.kindRaw = kind.rawValue
        self.quote = quote
        self.statusRaw = status.rawValue
        self.isManual = isManual
        self.isEdited = isEdited
        self.position = position
    }

    public var kind: TagKind {
        get { TagKind(rawValue: kindRaw) ?? .topic }
        set { kindRaw = newValue.rawValue }
    }

    public var status: TagStatus {
        get { TagStatus(rawValue: statusRaw) ?? .suggested }
        set { statusRaw = newValue.rawValue }
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Models/Entry.swift
import Foundation
import SwiftData

@Model
public final class Entry {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var notebookID: String
    public var modeRaw: String
    /// Guided prompt shown while writing, if any.
    public var prompt: String?
    public var text: String
    @Attribute(.externalStorage) public var photoData: Data?
    public var taggingRaw: String
    @Relationship(deleteRule: .cascade, inverse: \TagMark.entry)
    public var tags: [TagMark] = []

    public init(id: UUID = UUID(), createdAt: Date = .now, notebookID: String = Notebook.daily.id,
                mode: WritingMode = .free, prompt: String? = nil, text: String,
                photoData: Data? = nil, tagging: TaggingStatus = .pending) {
        self.id = id
        self.createdAt = createdAt
        self.notebookID = notebookID
        self.modeRaw = mode.rawValue
        self.prompt = prompt
        self.text = text
        self.photoData = photoData
        self.taggingRaw = tagging.rawValue
    }

    public var mode: WritingMode {
        get { WritingMode(rawValue: modeRaw) ?? .free }
        set { modeRaw = newValue.rawValue }
    }

    public var tagging: TaggingStatus {
        get { TaggingStatus(rawValue: taggingRaw) ?? .done }
        set { taggingRaw = newValue.rawValue }
    }

    public var notebook: Notebook { Notebook.with(id: notebookID) }

    public var orderedTags: [TagMark] { tags.sorted { $0.position < $1.position } }
    public var suggestedTags: [TagMark] { orderedTags.filter { $0.status == .suggested } }
    public var keptTags: [TagMark] { orderedTags.filter { $0.status == .kept } }
    public var visibleTags: [TagMark] { orderedTags.filter { $0.status != .removed } }

    public var quoteMarks: [QuoteMark] {
        visibleTags.compactMap { tag in
            tag.quote.map { QuoteMark(id: tag.id, kind: tag.kind, status: tag.status, quote: $0) }
        }
    }

    public func hasKept(label: String) -> Bool {
        keptTags.contains { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }

    @discardableResult
    public func addTag(label: String, kind: TagKind, quote: String? = nil,
                       status: TagStatus = .kept, isManual: Bool = false) -> TagMark {
        let position = (tags.map(\.position).max() ?? -1) + 1
        let tag = TagMark(label: label, kind: kind, quote: quote, status: status, isManual: isManual, position: position)
        modelContext?.insert(tag)
        tags.append(tag)
        return tag
    }
}

/// A tag's quote located for highlighting, decoupled from SwiftData.
public struct QuoteMark: Hashable, Sendable {
    public let id: UUID
    public let kind: TagKind
    public let status: TagStatus
    public let quote: String

    public init(id: UUID, kind: TagKind, status: TagStatus, quote: String) {
        self.id = id
        self.kind = kind
        self.status = status
        self.quote = quote
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Models/MementoStore.swift
import SwiftData

public enum MementoStore {
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Entry.self, TagMark.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: config)
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `cd Packages/MementoCore && swift test`. Expected: all tests pass.

- [ ] **Step 5: Commit.** `git add Packages && git commit -m "MementoCore: SwiftData models for entries and tags"`

---

### Task 4: Domain: dates, excerpts, tag index, streak, journal insights

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/Domain/{DateLabels,Excerpt,TagIndex,Streak,JournalInsights}.swift`
- Create: `Packages/MementoCore/Tests/MementoCoreTests/{DateAndExcerptTests,TagIndexTests,StreakTests}.swift`

**Interfaces:**
- Consumes: `Entry`, `TagKind` (Task 3).
- Produces:
  - `DateLabels(now:calendar:)` with `.relativeDay(_:)`, `.short(_:)`, `.time(_:)`, `.longDay(_:)`, `.fullDate(_:)`, `.greeting()`
  - `Excerpt.make(_:limit:)`
  - `TagSummary {key, label, kind, entryIDs, count}`
  - `TagIndex(entries:)` with `.summaries`, `.summary(for:)`, `.count(for:)`, `.byKind(_:matching:)`, `.topLabels(_:)`
  - `Streak.compute(entryDates:today:calendar:) -> StreakInfo {count, unit, week: [WeekDay]}`
  - `PendingReview {suggestionCount, entryIDs, isEmpty, label, firstEntryID}`
  - `JournalInsights.pending(_:)`, `JournalInsights.revisit(_:)`

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/DateAndExcerptTests.swift
import Testing
import Foundation
@testable import MementoCore

@Suite struct DateAndExcerptTests {
    let labels = DateLabels(now: Fixtures.today, calendar: Fixtures.calendar)

    @Test func relativeDays() {
        #expect(labels.relativeDay(Fixtures.daysAgo(0)) == "Today")
        #expect(labels.relativeDay(Fixtures.daysAgo(1)) == "Yesterday")
        #expect(labels.relativeDay(Fixtures.daysAgo(2)) == "Wed, Oct 7")
        #expect(labels.short(Fixtures.daysAgo(27)) == "Sep 12")
        #expect(labels.time(Fixtures.daysAgo(1, hour: 23, minute: 52)) == "11:52 PM")
        #expect(labels.longDay(Fixtures.today) == "Friday, October 9")
        #expect(labels.fullDate(Fixtures.today) == "October 9, 2026")
        #expect(labels.greeting() == "Good evening")
    }

    @Test func excerptFlattensAndTrimsAtWordBoundary() {
        #expect(Excerpt.make("One\n\nTwo") == "One Two")
        let long = String(repeating: "word ", count: 40)
        let ex = Excerpt.make(long)
        #expect(ex.hasSuffix("…"))
        #expect(ex.count <= 110)
        #expect(!ex.dropLast().hasSuffix(" "))
    }
}
```

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/TagIndexTests.swift
import Testing
@testable import MementoCore

@MainActor
@Suite struct TagIndexTests {
    @Test func countsOnlyKeptTagsOncePerEntry() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("Walking helped", .helped, nil, .kept), ("Calm", .feeling, nil, .suggested)])
        s.entry(daysAgo: 2, tags: [("Walking helped", .helped, nil, .kept), ("Walking helped", .helped, nil, .kept)])
        s.entry(daysAgo: 3, tags: [("Walking helped", .helped, nil, .removed)])
        let index = TagIndex(entries: try s.all())
        #expect(index.count(for: "Walking helped") == 2)
        #expect(index.count(for: "Calm") == 0)
        #expect(index.summaries.map(\.label) == ["Walking helped"])
    }

    @Test func labelsMergeCaseInsensitively() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("walking helped", .helped, nil, .kept)])
        s.entry(daysAgo: 2, tags: [("Walking helped", .helped, nil, .kept)])
        let index = TagIndex(entries: try s.all())
        #expect(index.summaries.count == 1)
        #expect(index.summary(for: "WALKING HELPED")?.count == 2)
        #expect(index.summary(for: "walking helped")?.label == "walking helped") // newest wins display
    }

    @Test func byKindSortsByCountThenFirstSeenAndFilters() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("Calm", .feeling, nil, .kept), ("Drained", .feeling, nil, .kept)])
        s.entry(daysAgo: 2, tags: [("Drained", .feeling, nil, .kept)])
        let index = TagIndex(entries: try s.all())
        #expect(index.byKind(.feeling).map(\.label) == ["Drained", "Calm"])
        #expect(index.byKind(.feeling, matching: "cal").map(\.label) == ["Calm"])
        #expect(index.topLabels(1) == ["Drained"])
    }

    @Test func pendingAndRevisit() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("Restless", .feeling, nil, .suggested), ("Walking helped", .helped, nil, .kept)])
        s.entry(daysAgo: 2, tags: [("Boundaries", .situation, nil, .suggested), ("Walking helped", .helped, nil, .kept)])
        let entries = try s.all()
        let pending = JournalInsights.pending(entries)
        #expect(pending.label == "2 suggestions waiting in 2 entries")
        #expect(pending.firstEntryID == entries[0].id)
        #expect(JournalInsights.revisit(TagIndex(entries: entries))?.label == "Walking helped")
    }

    @Test func revisitNeedsTwoEntries() throws {
        let s = try TestStore()
        s.entry(tags: [("Reading", .helped, nil, .kept)])
        #expect(JournalInsights.revisit(TagIndex(entries: try s.all())) == nil)
        #expect(JournalInsights.pending([]).label == "0 suggestions waiting in 0 entries")
    }
}
```

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/StreakTests.swift
import Testing
import Foundation
@testable import MementoCore

@Suite struct StreakTests {
    @Test func countsBackFromYesterdayWhenNothingToday() {
        let dates = [1, 2, 3, 5].map { Fixtures.daysAgo($0) }
        let info = Streak.compute(entryDates: dates, today: Fixtures.today, calendar: Fixtures.calendar)
        #expect(info.count == 3)
        #expect(info.unit == "days in a row")
    }

    @Test func includesTodayAndBuildsMondayWeek() {
        let dates = [0, 1].map { Fixtures.daysAgo($0) }
        let info = Streak.compute(entryDates: dates, today: Fixtures.today, calendar: Fixtures.calendar)
        #expect(info.count == 2)
        #expect(info.week.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(info.week[4].isToday)          // Friday
        #expect(info.week[3].hasEntry && info.week[4].hasEntry)
        #expect(!info.week[0].hasEntry)
    }

    @Test func singleDayUnit() {
        let info = Streak.compute(entryDates: [Fixtures.daysAgo(0)], today: Fixtures.today, calendar: Fixtures.calendar)
        #expect(info.count == 1)
        #expect(info.unit == "day in a row")
        #expect(Streak.compute(entryDates: [], today: Fixtures.today, calendar: Fixtures.calendar).count == 0)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail.** Run `swift test`. Expected: compile errors for the missing types.

- [ ] **Step 3: Implement**

```swift
// File: Packages/MementoCore/Sources/MementoCore/Domain/DateLabels.swift
import Foundation

/// English date strings used across the app (formats from the prototype).
public struct DateLabels: Sendable {
    public var now: Date
    public var calendar: Calendar

    public init(now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = pattern
        return f.string(from: date)
    }

    /// "Today", "Yesterday", "Wed, Oct 7"
    public func relativeDay(_ date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        return format(date, "EEE, MMM d")
    }

    /// "Oct 7"
    public func short(_ date: Date) -> String { format(date, "MMM d") }
    /// "9:41 PM"
    public func time(_ date: Date) -> String { format(date, "h:mm a") }
    /// "Friday, October 9"
    public func longDay(_ date: Date) -> String { format(date, "EEEE, MMMM d") }
    /// "October 9, 2026"
    public func fullDate(_ date: Date) -> String { format(date, "MMMM d, yyyy") }
    /// "September"
    public func month(_ date: Date) -> String { format(date, "MMMM") }

    public func greeting() -> String {
        switch calendar.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Domain/Excerpt.swift
import Foundation

public enum Excerpt {
    /// Single-line preview: newlines flattened, cut at a word boundary with an ellipsis.
    public static func make(_ text: String, limit: Int = 110) -> String {
        let flat = text.replacingOccurrences(of: "\\n+", with: " ", options: .regularExpression)
        guard flat.count > limit else { return flat }
        var cut = String(flat.prefix(limit - 2))
        if let r = cut.range(of: "\\s+\\S*$", options: .regularExpression) { cut.removeSubrange(r) }
        return cut + "…"
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Domain/TagIndex.swift
import Foundation

public struct TagSummary: Identifiable, Hashable, Sendable {
    public var id: String { key }
    /// Lowercased label: the identity of a tag across entries.
    public let key: String
    /// Display label (as written in the newest entry carrying it).
    public let label: String
    public let kind: TagKind
    public internal(set) var entryIDs: [UUID]
    public var count: Int { entryIDs.count }
}

/// Every kept tag across the journal. Pass entries newest first.
public struct TagIndex: Sendable {
    public private(set) var summaries: [TagSummary] = []
    private var positions: [String: Int] = [:]

    public init(entries: [Entry]) {
        for entry in entries {
            for tag in entry.keptTags {
                let key = tag.label.lowercased()
                if let i = positions[key] {
                    if !summaries[i].entryIDs.contains(entry.id) { summaries[i].entryIDs.append(entry.id) }
                } else {
                    positions[key] = summaries.count
                    summaries.append(TagSummary(key: key, label: tag.label, kind: tag.kind, entryIDs: [entry.id]))
                }
            }
        }
    }

    public func summary(for label: String) -> TagSummary? {
        positions[label.lowercased()].map { summaries[$0] }
    }

    public func count(for label: String) -> Int { summary(for: label)?.count ?? 0 }

    /// Tags of one kind, most-used first (ties keep first-seen order), optionally filtered.
    public func byKind(_ kind: TagKind, matching query: String = "") -> [TagSummary] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return Self.byCount(summaries.filter { $0.kind == kind && (q.isEmpty || $0.key.contains(q)) })
    }

    public func topLabels(_ n: Int) -> [String] {
        Array(Self.byCount(summaries).prefix(n).map(\.label))
    }

    static func byCount(_ items: [TagSummary]) -> [TagSummary] {
        items.enumerated()
            .sorted { $0.element.count != $1.element.count ? $0.element.count > $1.element.count : $0.offset < $1.offset }
            .map(\.element)
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Domain/Streak.swift
import Foundation

public struct WeekDay: Hashable, Sendable {
    public let letter: String
    public let date: Date
    public let hasEntry: Bool
    public let isToday: Bool
}

public struct StreakInfo: Equatable, Sendable {
    public let count: Int
    public let week: [WeekDay]
    public var unit: String { count == 1 ? "day in a row" : "days in a row" }
}

public enum Streak {
    /// Consecutive days with an entry, counting back from today (or yesterday if today is empty),
    /// plus the Monday-start week containing today.
    public static func compute(entryDates: [Date], today: Date, calendar: Calendar = .current) -> StreakInfo {
        let days = Set(entryDates.map { calendar.startOfDay(for: $0) })
        let start = calendar.startOfDay(for: today)
        var cursor = days.contains(start) ? start : calendar.date(byAdding: .day, value: -1, to: start)!
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        let weekday = calendar.component(.weekday, from: start) // 1 = Sunday
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: start)!
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let week = letters.enumerated().map { i, letter in
            let d = calendar.date(byAdding: .day, value: i, to: monday)!
            return WeekDay(letter: letter, date: d, hasEntry: days.contains(d), isToday: d == start)
        }
        return StreakInfo(count: count, week: week)
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Domain/JournalInsights.swift
import Foundation

public struct PendingReview: Equatable, Sendable {
    public let suggestionCount: Int
    public let entryIDs: [UUID]

    public var isEmpty: Bool { suggestionCount == 0 }
    public var firstEntryID: UUID? { entryIDs.first }
    public var label: String {
        let s = suggestionCount == 1 ? "suggestion" : "suggestions"
        let e = entryIDs.count == 1 ? "entry" : "entries"
        return "\(suggestionCount) \(s) waiting in \(entryIDs.count) \(e)"
    }
}

public enum JournalInsights {
    /// Unreviewed suggestions across entries (pass newest first).
    public static func pending(_ entries: [Entry]) -> PendingReview {
        var total = 0
        var ids: [UUID] = []
        for e in entries {
            let n = e.suggestedTags.count
            if n > 0 { total += n; ids.append(e.id) }
        }
        return PendingReview(suggestionCount: total, entryIDs: ids)
    }

    /// The "what helped" tag kept most often, if it appears in at least two entries.
    public static func revisit(_ index: TagIndex) -> TagSummary? {
        guard let top = index.byKind(.helped).first, top.count >= 2 else { return nil }
        return top
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `swift test`. Expected: all tests pass.

- [ ] **Step 5: Commit.** `git commit -am "MementoCore: dates, excerpts, tag index, streak, insights"`. Stage new files with `git add Packages` first.

---

### Task 5: TextSegments (highlight spans)

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/Domain/TextSegments.swift`
- Test: `Packages/MementoCore/Tests/MementoCoreTests/TextSegmentsTests.swift`

**Interfaces:**
- Consumes: `QuoteMark` (Task 3).
- Produces: `TextSegment {text, mark: QuoteMark?}` and `TextSegments.build(text:marks:) -> [TextSegment]`. Concatenating the segments' texts always reproduces the input exactly.

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/TextSegmentsTests.swift
import Testing
import Foundation
@testable import MementoCore

@Suite struct TextSegmentsTests {
    func mark(_ q: String, _ s: TagStatus = .kept) -> QuoteMark { QuoteMark(id: UUID(), kind: .feeling, status: s, quote: q) }

    @Test func splitsAroundMarksInTextOrder() {
        let text = "I felt drained after deadlines. A short walk helped."
        let segs = TextSegments.build(text: text, marks: [mark("A short walk helped"), mark("I felt drained")])
        #expect(segs.map(\.text).joined() == text)
        #expect(segs.compactMap(\.mark).map(\.quote) == ["I felt drained", "A short walk helped"])
        #expect(segs.first?.mark != nil)
    }

    @Test func skipsOverlappingMissingAndRemoved() {
        let text = "Back-to-back deadlines today."
        let segs = TextSegments.build(text: text, marks: [
            mark("Back-to-back deadlines"), mark("deadlines today"), mark("not there"), mark("today", .removed),
        ])
        #expect(segs.compactMap(\.mark).map(\.quote) == ["Back-to-back deadlines"])
        #expect(segs.map(\.text).joined() == text)
    }

    @Test func segmentsHandleEmoji() {
        let text = "Tea 🍵 at midnight 👩🏽‍💻 didn't help."
        let segs = TextSegments.build(text: text, marks: [mark("at midnight 👩🏽‍💻")])
        #expect(segs.map(\.text) == ["Tea 🍵 ", "at midnight 👩🏽‍💻", " didn't help."])
    }

    @Test func emptyTextAndNoMarks() {
        #expect(TextSegments.build(text: "", marks: [mark("x")]).isEmpty)
        #expect(TextSegments.build(text: "Plain.", marks: []).map(\.text) == ["Plain."])
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail.** Run `swift test --filter TextSegmentsTests`. Expected: compile error.

- [ ] **Step 3: Implement**

```swift
// File: Packages/MementoCore/Sources/MementoCore/Domain/TextSegments.swift
import Foundation

public struct TextSegment: Hashable, Sendable {
    public let text: String
    public let mark: QuoteMark?
}

public enum TextSegments {
    /// Splits text into plain and marked runs. Each mark highlights the first occurrence of its
    /// quote; removed marks, missing quotes and marks overlapping an earlier one are skipped.
    public static func build(text: String, marks: [QuoteMark]) -> [TextSegment] {
        guard !text.isEmpty else { return [] }
        let located = marks.enumerated().compactMap { offset, mark -> (Range<String.Index>, Int, QuoteMark)? in
            guard mark.status != .removed, !mark.quote.isEmpty, let r = text.range(of: mark.quote) else { return nil }
            return (r, offset, mark)
        }
        .sorted { $0.0.lowerBound != $1.0.lowerBound ? $0.0.lowerBound < $1.0.lowerBound : $0.1 < $1.1 }

        var out: [TextSegment] = []
        var cursor = text.startIndex
        for (range, _, mark) in located where range.lowerBound >= cursor {
            if range.lowerBound > cursor { out.append(TextSegment(text: String(text[cursor..<range.lowerBound]), mark: nil)) }
            out.append(TextSegment(text: String(text[range]), mark: mark))
            cursor = range.upperBound
        }
        if cursor < text.endIndex { out.append(TextSegment(text: String(text[cursor...]), mark: nil)) }
        return out
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `swift test`. Expected: all tests pass.

- [ ] **Step 5: Commit.** `git add Packages && git commit -m "MementoCore: text segments for tag highlights"`

---

### Task 6: RuleTagger (demo/test engine) + SuggestionSanitizer

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/AI/{TaggingEngine,RuleTagger,SuggestionSanitizer}.swift`
- Test: `Packages/MementoCore/Tests/MementoCoreTests/{RuleTaggerTests,SuggestionSanitizerTests}.swift`

**Interfaces:**
- Consumes: `TagKind`.
- Produces:
  - `SuggestedTagDraft {label, kind, quote}`
  - `protocol TaggingEngine: Sendable { func suggest(text:vocabulary:) async throws -> [SuggestedTagDraft] }`
  - `TaggingEngineError {nothingToSuggest, failed}`
  - `RuleTagger.analyze(_:) -> [SuggestedTagDraft]`
  - `RuleTaggingEngine(delay:)`
  - `actor FailingOnceEngine(base:)`
  - `SuggestionSanitizer.sanitize(_:text:existingLabels:limit:)`

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/RuleTaggerTests.swift
import Testing
@testable import MementoCore

@Suite struct RuleTaggerTests {
    @Test func demoSentenceMatchesPrototype() {
        let text = "I felt drained after back-to-back deadlines today.\nA short walk helped me settle."
        let tags = RuleTagger.analyze(text)
        #expect(tags == [
            SuggestedTagDraft(label: "Drained", kind: .feeling, quote: "I felt drained"),
            SuggestedTagDraft(label: "Work deadlines", kind: .situation, quote: "back-to-back deadlines"),
            SuggestedTagDraft(label: "Walking helped", kind: .helped, quote: "A short walk helped me settle"),
        ])
    }

    @Test func freeWritingExample() {
        let text = "Stayed late again to get the deck finished and I felt drained by the time I got home. Called my sister on the walk from the station and we laughed about Mum's new phone.\n\nStill hopeful the launch moves."
        let labels = RuleTagger.analyze(text).map(\.label)
        #expect(labels == ["Drained", "Talking to a friend", "Walking helped", "Hopeful"])
    }

    @Test func capsAtFiveAndNeverOverlaps() {
        let text = "So overwhelmed and anxious. Grateful for mum. Couldn't sleep. Argued with Theo. A long walk at work. Took a nap."
        let tags = RuleTagger.analyze(text)
        #expect(tags.count == 5)
        #expect(tags.allSatisfy { $0.quote.map(text.contains) ?? false })
    }

    @Test func ruleEngineThrowsWhenNothingFound() async {
        await #expect(throws: TaggingEngineError.nothingToSuggest) {
            try await RuleTaggingEngine(delay: .zero).suggest(text: "Nothing here.", vocabulary: [])
        }
    }

    @Test func failingOnceEngineFailsFirstCallOnly() async throws {
        let engine = FailingOnceEngine(base: RuleTaggingEngine(delay: .zero))
        await #expect(throws: TaggingEngineError.failed) {
            try await engine.suggest(text: "I felt drained.", vocabulary: [])
        }
        let second = try await engine.suggest(text: "I felt drained.", vocabulary: [])
        #expect(second.first?.label == "Drained")
    }
}
```

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/SuggestionSanitizerTests.swift
import Testing
@testable import MementoCore

@Suite struct SuggestionSanitizerTests {
    let text = "Couldn't sleep until two. Writing a list of what's due helped."

    func d(_ label: String, _ quote: String?, _ kind: TagKind = .feeling) -> SuggestedTagDraft {
        SuggestedTagDraft(label: label, kind: kind, quote: quote)
    }

    @Test func keepsExactQuotes() {
        let out = SuggestionSanitizer.sanitize([d("Poor sleep", "Couldn't sleep until two")], text: text, existingLabels: [])
        #expect(out == [d("Poor sleep", "Couldn't sleep until two")])
    }

    @Test func rewritesCasingAndStripsSmartQuotes() {
        let out = SuggestionSanitizer.sanitize([d("Writing it down", "“writing a list of what's due helped”")], text: text, existingLabels: [])
        #expect(out.first?.quote == "Writing a list of what's due helped")
    }

    @Test func dropsInventedQuoteButKeepsTag() {
        let out = SuggestionSanitizer.sanitize([d("Tired", "I was exhausted all week")], text: text, existingLabels: [])
        #expect(out == [d("Tired", nil)])
    }

    @Test func dropsOverlappingSpans() {
        let out = SuggestionSanitizer.sanitize([d("Poor sleep", "Couldn't sleep"), d("Late night", "sleep until two")], text: text, existingLabels: [])
        #expect(out.map(\.label) == ["Poor sleep"])
    }

    @Test func dedupesAgainstExistingAndWithinList() {
        let out = SuggestionSanitizer.sanitize([d("poor sleep", nil), d("Calm", nil), d("calm", nil)], text: text, existingLabels: ["Poor Sleep"])
        #expect(out.map(\.label) == ["Calm"])
    }

    @Test func cleansLabelsAndLimits() {
        let many = (1...8).map { d("Tag \($0).", nil) } + [d("   ", nil)]
        let out = SuggestionSanitizer.sanitize(many, text: text, existingLabels: [])
        #expect(out.count == 5)
        #expect(out.first?.label == "Tag 1")
        let long = SuggestionSanitizer.sanitize([d("a very long label that keeps going and going on", nil)], text: text, existingLabels: [])
        #expect(long.first!.label.count <= 40)
        #expect(long.first!.label.hasPrefix("A very"))
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail.** Run `swift test`. Expected: compile errors.

- [ ] **Step 3: Implement**

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/TaggingEngine.swift
import Foundation

public struct SuggestedTagDraft: Hashable, Sendable {
    public var label: String
    public var kind: TagKind
    public var quote: String?

    public init(label: String, kind: TagKind, quote: String?) {
        self.label = label
        self.kind = kind
        self.quote = quote
    }
}

public enum TaggingEngineError: Error, Equatable, Sendable {
    /// The model had nothing (or declined) to suggest — not a failure.
    case nothingToSuggest
    case failed
}

public protocol TaggingEngine: Sendable {
    /// Suggests details for an entry. `vocabulary` is the writer's most-used kept labels.
    func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft]
}

/// Deterministic engine for onboarding, tests and the demo backup (spec D11, D23).
public struct RuleTaggingEngine: TaggingEngine {
    public var delay: Duration

    public init(delay: Duration = .milliseconds(1200)) { self.delay = delay }

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        if delay > .zero { try await Task.sleep(for: delay) }
        let tags = RuleTagger.analyze(text)
        if tags.isEmpty { throw TaggingEngineError.nothingToSuggest }
        return tags
    }
}

/// Demo "Tagging fails" state: the first attempt per text fails, retries succeed.
public actor FailingOnceEngine: TaggingEngine {
    private let base: any TaggingEngine
    private var failed: Set<String> = []

    public init(base: any TaggingEngine) { self.base = base }

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        if failed.insert(text).inserted { throw TaggingEngineError.failed }
        return try await base.suggest(text: text, vocabulary: vocabulary)
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/RuleTagger.swift
import Foundation

/// Port of the prototype's RULES/analyze(): first match per rule, no overlaps, at most five.
public enum RuleTagger {
    struct Rule: Sendable {
        let label: String
        let kind: TagKind
        let pattern: String
    }

    static let rules: [Rule] = [
        Rule(label: "Drained", kind: .feeling, pattern: #"(?:i (?:felt|feel|am|was|'m) |i'm )?(?:so |really |completely )?(?:drained|exhausted|wiped out|worn out)"#),
        Rule(label: "Overwhelmed", kind: .feeling, pattern: #"(?:i (?:felt|feel|am|was) |i'm )?(?:so |really )?overwhelm\w*"#),
        Rule(label: "Anxious", kind: .feeling, pattern: #"(?:i (?:felt|feel|am|was) |i'm )?(?:so |really )?(?:anxious|worried|on edge|nervous)"#),
        Rule(label: "Hopeful", kind: .feeling, pattern: #"(?:still |i'm |i feel )?(?:hopeful|optimistic)[^.!?,\n]*"#),
        Rule(label: "Grateful", kind: .feeling, pattern: #"(?:grateful|thankful)[^.!?,\n]*"#),
        Rule(label: "Lonely", kind: .feeling, pattern: #"(?:lonely|left out)"#),
        Rule(label: "Calm", kind: .feeling, pattern: #"(?:felt |feel )?(?:calm|at peace|lighter)[^.!?,\n]*"#),
        Rule(label: "Work deadlines", kind: .situation, pattern: #"(?:(?:back-to-back|tight|endless|too many) )?deadlines?"#),
        Rule(label: "Poor sleep", kind: .situation, pattern: #"(?:couldn't|could not|didn't|barely|can't) (?:get to )?sleep[^.!?,\n]*|slept (?:badly|poorly)|(?:poor|bad|little) sleep"#),
        Rule(label: "Conflict", kind: .situation, pattern: #"(?:argu\w+|fight with|fought|snapped at)[^.!?,\n]*"#),
        Rule(label: "Talking to a friend", kind: .helped, pattern: #"(?:called|talked to|talked with|call with) (?:a friend|my friend|friends|my sister|my brother|my mum|my mom|Priya)"#),
        Rule(label: "Walking helped", kind: .helped, pattern: #"(?:(?:a|the) )?(?:(?:short|long|quick) )?walk\w*[^.!?,\n]*"#),
        Rule(label: "Rest", kind: .helped, pattern: #"(?:a nap|napped|rested|an early night|lay down)[^.!?,\n]*"#),
        Rule(label: "Work", kind: .topic, pattern: #"\b(?:work|office|meeting|manager|sprint|inbox)\b"#),
        Rule(label: "Family", kind: .topic, pattern: #"\b(?:mum|mom|dad|family|parents)\b"#),
        Rule(label: "Relationships", kind: .topic, pattern: #"\b(?:partner|Theo)\b"#),
        Rule(label: "Creativity", kind: .topic, pattern: #"\b(?:paint\w*|drawing|sketch\w*|ceramics|guitar)\b"#),
    ]

    public static func analyze(_ text: String) -> [SuggestedTagDraft] {
        let ns = text as NSString
        var found: [(range: NSRange, draft: SuggestedTagDraft)] = []
        for rule in rules {
            guard let re = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]),
                  let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { continue }
            var quote = ns.substring(with: m.range)
            while let last = quote.last, last.isWhitespace || last == "," { quote.removeLast() }
            let range = NSRange(location: m.range.location, length: (quote as NSString).length)
            if found.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) { continue }
            found.append((range, SuggestedTagDraft(label: rule.label, kind: rule.kind, quote: quote)))
            if found.count >= 5 { break }
        }
        return found.sorted { $0.range.location < $1.range.location }.map(\.draft)
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/SuggestionSanitizer.swift
import Foundation

/// Makes model output safe to store: verbatim quotes, no overlaps, no duplicates, at most five.
public enum SuggestionSanitizer {
    public static let maxLabelLength = 40

    public static func sanitize(_ drafts: [SuggestedTagDraft], text: String,
                                existingLabels: Set<String>, limit: Int = 5) -> [SuggestedTagDraft] {
        var seen = Set(existingLabels.map { $0.lowercased() })
        var taken: [Range<String.Index>] = []
        var out: [SuggestedTagDraft] = []
        for draft in drafts where out.count < limit {
            let label = cleanLabel(draft.label)
            guard !label.isEmpty, !seen.contains(label.lowercased()) else { continue }
            var quote: String?
            if let raw = draft.quote {
                let q = cleanQuote(raw)
                if !q.isEmpty, let r = locate(q, in: text) {
                    if taken.contains(where: { $0.overlaps(r) }) { continue }
                    taken.append(r)
                    quote = String(text[r])
                }
            }
            seen.insert(label.lowercased())
            out.append(SuggestedTagDraft(label: label, kind: draft.kind, quote: quote))
        }
        return out
    }

    static func cleanLabel(_ raw: String) -> String {
        var l = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if l.count > maxLabelLength {
            l = String(l.prefix(maxLabelLength))
            if let space = l.lastIndex(of: " ") { l = String(l[..<space]) }
        }
        return l.prefix(1).uppercased() + l.dropFirst()
    }

    static func cleanQuote(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”‘’")))
    }

    static func locate(_ quote: String, in text: String) -> Range<String.Index>? {
        text.range(of: quote) ?? text.range(of: quote, options: [.caseInsensitive, .diacriticInsensitive])
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `swift test`. Expected: all tests pass. If `capsAtFiveAndNeverOverlaps` yields fewer than 5, print `RuleTagger.analyze(text)` and adjust the *test text* (not the rules, which mirror the prototype) so that six or more rules match.

- [ ] **Step 5: Commit.** `git add Packages && git commit -m "MementoCore: rule tagger and suggestion sanitizer"`

---

### Task 7: SummaryComposer

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/Domain/SummaryComposer.swift`
- Test: `Packages/MementoCore/Tests/MementoCoreTests/SummaryComposerTests.swift`

**Interfaces:**
- Consumes: `Entry`, `DateLabels`, `Excerpt`, `TagKind`.
- Produces:
  - `SummaryPurpose {me, clinician}`
  - `SummaryOptions(purpose:includeQuotes:note:preparedBy:today:)`
  - `SummaryDocument {title, who, range, countLine, narrative, groups:[Group{name,items}], showQuotes, quotes:[Quote{date,text}], note: String?, footer}`
  - `SummaryComposer.compose(entries:options:calendar:)`
  - `SummaryComposer.list(_:)`

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/SummaryComposerTests.swift
import Testing
@testable import MementoCore

@MainActor
@Suite struct SummaryComposerTests {
    func sample() throws -> [Entry] {
        let s = try TestStore()
        s.entry(daysAgo: 1, text: "Couldn't sleep.", tags: [("Poor sleep", .situation, "Couldn't sleep", .kept), ("Restless", .feeling, nil, .suggested)])
        s.entry(daysAgo: 3, text: "Overwhelmed is the word. Took the long way home.", tags: [
            ("Overwhelmed", .feeling, "Overwhelmed is the word", .kept), ("Walking helped", .helped, "Took the long way home", .kept)])
        s.entry(daysAgo: 10, text: "My first bowl.", tags: [("Absorbed", .feeling, nil, .kept)])
        return try s.all()
    }

    @Test func listJoinsWithOxfordlessAnd() {
        #expect(SummaryComposer.list([]) == "")
        #expect(SummaryComposer.list(["a"]) == "a")
        #expect(SummaryComposer.list(["a", "b", "c"]) == "a, b and c")
    }

    @Test func forMeNarrativeAndGroups() throws {
        let doc = SummaryComposer.compose(entries: try sample(),
            options: SummaryOptions(purpose: .me, today: Fixtures.today), calendar: Fixtures.calendar)
        #expect(doc.title == "A look back")
        #expect(doc.who == "For me · October 9, 2026")
        #expect(doc.range == "Sep 29 – Oct 8, 2026")
        #expect(doc.countLine == "3 selected entries")
        #expect(doc.narrative == "Across 3 entries, the feelings you named most were absorbed (1) and overwhelmed (1). You wrote about poor sleep (1). Things you noted helped: walking helped (1).")
        #expect(doc.groups.map(\.name) == ["Feelings", "Situations", "What helped"])
        #expect(doc.groups[0].items == "Absorbed (1), Overwhelmed (1)")
        #expect(doc.quotes.map(\.text) == ["My first bowl.", "Overwhelmed is the word", "Couldn't sleep"])
        #expect(doc.note == nil)
    }

    @Test func clinicianVersionIsFirstPersonWithNoteAndName() throws {
        let doc = SummaryComposer.compose(entries: try sample(),
            options: SummaryOptions(purpose: .clinician, includeQuotes: false, note: "Sleep is worse.", preparedBy: "Maya Lin", today: Fixtures.today),
            calendar: Fixtures.calendar)
        #expect(doc.title == "Journal summary for my appointment")
        #expect(doc.who == "Prepared by Maya Lin · October 9, 2026")
        #expect(doc.narrative.hasPrefix("Across 3 entries I chose, the feelings I named most often were absorbed (1) and overwhelmed (1)."))
        #expect(doc.narrative.hasSuffix("Numbers are how many selected entries carry each tag."))
        #expect(doc.showQuotes == false)
        #expect(doc.note == "Sleep is worse.")
    }

    @Test func emptySelectionAndUntaggedFeelings() {
        let doc = SummaryComposer.compose(entries: [], options: SummaryOptions(purpose: .me, today: Fixtures.today), calendar: Fixtures.calendar)
        #expect(doc.range == "")
        #expect(doc.countLine == "0 selected entries")
        #expect(doc.narrative == "Across 0 entries, the feelings you named most were not tagged yet.")
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail.** Run `swift test`. Expected: compile errors.

- [ ] **Step 3: Implement**

```swift
// File: Packages/MementoCore/Sources/MementoCore/Domain/SummaryComposer.swift
import Foundation

public enum SummaryPurpose: String, Sendable {
    case me, clinician
}

public struct SummaryOptions: Sendable {
    public var purpose: SummaryPurpose
    public var includeQuotes: Bool
    public var note: String
    public var preparedBy: String
    public var today: Date

    public init(purpose: SummaryPurpose, includeQuotes: Bool = true, note: String = "", preparedBy: String = "", today: Date = .now) {
        self.purpose = purpose
        self.includeQuotes = includeQuotes
        self.note = note
        self.preparedBy = preparedBy
        self.today = today
    }
}

public struct SummaryDocument: Equatable, Sendable {
    public struct Group: Equatable, Sendable {
        public let name: String
        public let items: String
    }
    public struct Quote: Equatable, Sendable {
        public let date: String
        public let text: String
    }

    public let title: String
    public let who: String
    public let range: String
    public let countLine: String
    public let narrative: String
    public let groups: [Group]
    public let showQuotes: Bool
    public let quotes: [Quote]
    public let note: String?
    public var footer: String { Self.footer }

    public static let footer = "Made in Memento from entries I selected. Tags are my own reviewed labels and counts of what I wrote — not a diagnosis or assessment."
}

/// Deterministic summary text (spec D14): counts of kept tags plus templated sentences.
public enum SummaryComposer {
    public static func compose(entries: [Entry], options: SummaryOptions, calendar: Calendar = .current) -> SummaryDocument {
        let labels = DateLabels(now: options.today, calendar: calendar)
        let selected = entries.sorted { $0.createdAt < $1.createdAt }
        let clinician = options.purpose == .clinician

        var counts: [(kind: TagKind, label: String, n: Int)] = []
        for entry in selected {
            for tag in entry.keptTags {
                if let i = counts.firstIndex(where: { $0.kind == tag.kind && $0.label == tag.label }) {
                    counts[i].n += 1
                } else {
                    counts.append((tag.kind, tag.label, 1))
                }
            }
        }
        func byKind(_ kind: TagKind) -> [(label: String, n: Int)] {
            counts.enumerated()
                .filter { $0.element.kind == kind }
                .sorted { $0.element.n != $1.element.n ? $0.element.n > $1.element.n : $0.offset < $1.offset }
                .map { ($0.element.label, $0.element.n) }
        }
        func top(_ kind: TagKind) -> [String] { byKind(kind).prefix(3).map { "\($0.label.lowercased()) (\($0.n))" } }

        let f = top(.feeling), si = top(.situation), he = top(.helped)
        let n = selected.count
        let narrative: String
        if clinician {
            narrative = [
                "Across \(n) entries I chose, the feelings I named most often were \(f.isEmpty ? "not tagged" : list(f)).",
                si.isEmpty ? "" : "Situations I wrote about included \(list(si)).",
                he.isEmpty ? "" : "Things I noted as helping: \(list(he)).",
                "Numbers are how many selected entries carry each tag.",
            ].filter { !$0.isEmpty }.joined(separator: " ")
        } else {
            narrative = [
                "Across \(n) entries, the feelings you named most were \(f.isEmpty ? "not tagged yet" : list(f)).",
                si.isEmpty ? "" : "You wrote about \(list(si)).",
                he.isEmpty ? "" : "Things you noted helped: \(list(he)).",
            ].filter { !$0.isEmpty }.joined(separator: " ")
        }

        var range = ""
        if let first = selected.first, let last = selected.last {
            let year = calendar.component(.year, from: last.createdAt)
            range = labels.short(first.createdAt) + (n > 1 ? " – " + labels.short(last.createdAt) : "") + ", \(year)"
        }

        let groups = TagKind.allCases.compactMap { kind -> SummaryDocument.Group? in
            let items = byKind(kind)
            guard !items.isEmpty else { return nil }
            return .init(name: kind.plural, items: items.map { "\($0.label) (\($0.n))" }.joined(separator: ", "))
        }

        let quotes = selected.suffix(6).map { entry in
            SummaryDocument.Quote(date: labels.short(entry.createdAt),
                                  text: entry.keptTags.first(where: { $0.quote != nil })?.quote ?? Excerpt.make(entry.text))
        }

        let name = options.preparedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = options.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return SummaryDocument(
            title: clinician ? "Journal summary for my appointment" : "A look back",
            who: clinician
                ? (name.isEmpty ? "Prepared with Memento" : "Prepared by \(name)") + " · " + labels.fullDate(options.today)
                : "For me · " + labels.fullDate(options.today),
            range: range,
            countLine: "\(n) selected \(n == 1 ? "entry" : "entries")",
            narrative: narrative,
            groups: groups,
            showQuotes: options.includeQuotes,
            quotes: Array(quotes),
            note: clinician && !note.isEmpty ? note : nil
        )
    }

    /// "a", "a and b", "a, b and c" (the prototype's fmtList).
    public static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.joined() }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `swift test`. Expected: all tests pass.

- [ ] **Step 5: Commit.** `git add Packages && git commit -m "MementoCore: deterministic summary composer"`

---

### Task 8: AIAvailability, FoundationModelTagger, TaggingCoordinator

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/AI/{AIAvailability,FoundationModelTagger}.swift`
- Create: `Packages/MementoCore/Sources/MementoCore/Services/TaggingCoordinator.swift`
- Test: `Packages/MementoCore/Tests/MementoCoreTests/{TaggingCoordinatorTests,FoundationModelIntegrationTests}.swift`

**Interfaces:**
- Consumes: `Entry`, `TagIndex`, `TaggingEngine`, `SuggestionSanitizer`.
- Produces:
  - `AIAvailability {ready, needsAppleIntelligence, preparing, unsupported}`, with `.live()` and `.isSupported`
  - `struct FoundationModelTagger: TaggingEngine`
  - `TaggingPhase {running, failed, none, unavailable, unsupported, off, done}`
  - `@MainActor @Observable TaggingCoordinator(context:engine:availability:isEnabled:)`, with `.phase(for:)`, `.enqueue(_:)`, `.retry(_:)`, `.resumePending()`, `.drain()`, and settable `engine`
  - `TaggingCoordinator.maxCharacters = 6000`

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/TaggingCoordinatorTests.swift
import Testing
import Foundation
import SwiftData
@testable import MementoCore

actor RecordingEngine: TaggingEngine {
    var result: Result<[SuggestedTagDraft], TaggingEngineError>
    private(set) var receivedTexts: [String] = []
    private(set) var receivedVocabulary: [String] = []
    init(_ result: Result<[SuggestedTagDraft], TaggingEngineError>) { self.result = result }
    func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        receivedTexts.append(text)
        receivedVocabulary = vocabulary
        return try result.get()
    }
}

@MainActor
@Suite struct TaggingCoordinatorTests {
    func make(_ engine: any TaggingEngine, availability: AIAvailability = .ready, enabled: Bool = true) throws -> (TestStore, TaggingCoordinator) {
        let store = try TestStore()
        let c = TaggingCoordinator(context: store.context, engine: engine, availability: { availability }, isEnabled: { enabled })
        return (store, c)
    }

    @Test func addsSanitizedSuggestionsAndMarksDone() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Drained", kind: .feeling, quote: "I felt drained")]))
        let (store, c) = try make(engine)
        store.entry(daysAgo: 2, tags: [("Walking helped", .helped, nil, .kept)])
        let e = store.entry(text: "I felt drained today.")
        e.tagging = .pending
        c.enqueue(e)
        #expect(c.phase(for: e) == .running)
        await c.drain()
        #expect(c.phase(for: e) == .done)
        #expect(e.tagging == .done)
        #expect(e.suggestedTags.map(\.label) == ["Drained"])
        #expect(await engine.receivedVocabulary == ["Walking helped"])
    }

    @Test func nothingToSuggestShowsNone() async throws {
        let (store, c) = try make(RecordingEngine(.failure(.nothingToSuggest)))
        let e = store.entry(text: "Fine.")
        c.enqueue(e)
        await c.drain()
        #expect(c.phase(for: e) == .none)
        #expect(e.tagging == .done)
    }

    @Test func failureShowsFailedAndRetryRecovers() async throws {
        let engine = RecordingEngine(.failure(.failed))
        let (store, c) = try make(engine)
        let e = store.entry(text: "I felt drained.")
        c.enqueue(e)
        await c.drain()
        #expect(c.phase(for: e) == .failed)
        #expect(e.tagging == .failed)
        await engine.setResult(.success([SuggestedTagDraft(label: "Drained", kind: .feeling, quote: nil)]))
        c.retry(e)
        await c.drain()
        #expect(c.phase(for: e) == .done)
    }

    @Test func gatesOffUnsupportedAndUnavailable() async throws {
        let (s1, off) = try make(RecordingEngine(.success([])), enabled: false)
        let e1 = s1.entry(); off.enqueue(e1)
        #expect(off.phase(for: e1) == .off); #expect(e1.tagging == .skipped)

        let (s2, unsup) = try make(RecordingEngine(.success([])), availability: .unsupported)
        let e2 = s2.entry(); unsup.enqueue(e2)
        #expect(unsup.phase(for: e2) == .unsupported); #expect(e2.tagging == .skipped)

        let (s3, notReady) = try make(RecordingEngine(.success([])), availability: .needsAppleIntelligence)
        let e3 = s3.entry(); e3.tagging = .pending; notReady.enqueue(e3)
        #expect(notReady.phase(for: e3) == .unavailable); #expect(e3.tagging == .pending)
    }

    @Test func resumePendingTagsLeftoverEntries() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Calm", kind: .feeling, quote: nil)]))
        let (store, c) = try make(engine)
        let e = store.entry(text: "Quiet day."); e.tagging = .pending
        try store.context.save()
        c.resumePending()
        await c.drain()
        #expect(e.suggestedTags.map(\.label) == ["Calm"])
    }

    @Test func truncatesLongEntriesBeforeCallingEngine() async throws {
        let engine = RecordingEngine(.failure(.nothingToSuggest))
        let (store, c) = try make(engine)
        let e = store.entry(text: String(repeating: "a", count: 20_000))
        c.enqueue(e)
        await c.drain()
        #expect(await engine.receivedTexts.first?.count == TaggingCoordinator.maxCharacters)
    }

    @Test func deletedEntryDuringTaggingIsIgnored() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Calm", kind: .feeling, quote: nil)]))
        let (store, c) = try make(engine)
        let e = store.entry(text: "Quiet.")
        let id = e.id
        c.enqueue(e)
        store.context.delete(e)
        try store.context.save()
        await c.drain()
        #expect(try store.context.fetchCount(FetchDescriptor<TagMark>()) == 0)
        #expect(c.phases[id] == nil || c.phases[id] == TaggingPhase.none)
    }

    @Test func neverDuplicatesExistingLabels() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "calm", kind: .feeling, quote: nil)]))
        let (store, c) = try make(engine)
        let e = store.entry(text: "Calm.", tags: [("Calm", .feeling, nil, .kept)])
        c.enqueue(e)
        await c.drain()
        #expect(e.tags.count == 1)
        #expect(c.phase(for: e) == .none)
    }
}

extension RecordingEngine {
    func setResult(_ r: Result<[SuggestedTagDraft], TaggingEngineError>) { result = r }
}
```

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/FoundationModelIntegrationTests.swift
import Testing
@testable import MementoCore

/// Runs only where Apple Intelligence is available (e.g. this Mac or a supported iPhone).
@Suite(.enabled(if: AIAvailability.live() == .ready))
struct FoundationModelIntegrationTests {
    @Test func taggerReturnsGroundedSuggestions() async throws {
        let text = "I felt drained after back-to-back deadlines today.\nA short walk helped me settle."
        let drafts = try await FoundationModelTagger().suggest(text: text, vocabulary: ["Walking helped"])
        let clean = SuggestionSanitizer.sanitize(drafts, text: text, existingLabels: [])
        #expect(!clean.isEmpty)
        #expect(clean.allSatisfy { $0.quote.map(text.contains) ?? true })
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail.** Run `swift test`. Expected: compile errors.

- [ ] **Step 3: Implement**

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/AIAvailability.swift
import FoundationModels

/// The system model's state, mapped onto the prototype's AI states (spec §5.1).
public enum AIAvailability: String, CaseIterable, Sendable {
    case ready, needsAppleIntelligence, preparing, unsupported

    public var isSupported: Bool { self != .unsupported }

    public static func live() -> AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .ready
        case .unavailable(.appleIntelligenceNotEnabled): .needsAppleIntelligence
        case .unavailable(.modelNotReady): .preparing
        case .unavailable: .unsupported
        }
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/FoundationModelTagger.swift
import Foundation
import FoundationModels

@Generable
enum GeneratedTagKind {
    case feeling, situation, helped, topic
}

@Generable
struct GeneratedTag {
    @Guide(description: "A short label of one to three words in sentence case, e.g. Drained, Work deadlines, Walking helped")
    var label: String
    @Guide(description: "feeling = an emotion the writer named; situation = what happened or was hard; helped = something the writer said helped; topic = a recurring subject such as Work or Family")
    var kind: GeneratedTagKind
    @Guide(description: "The exact words copied from the entry that support this tag, 2 to 12 words, no paraphrase")
    var quote: String
}

@Generable
struct GeneratedTags {
    @Guide(description: "Up to five details from the entry. Empty if nothing clearly stands out.", .maximumCount(5))
    var tags: [GeneratedTag]
}

/// On-device tag suggestions via Apple's content-tagging adapter (spec §5.2).
public struct FoundationModelTagger: TaggingEngine {
    public init() {}

    static let instructions = """
    You help someone notice what is in their private journal entry. Suggest a few details they \
    might want to keep as tags: feelings they named, situations they described, things they said \
    helped, and recurring topics. These are gentle suggestions, not facts or judgements. \
    Never diagnose, never use clinical terms, and never infer anything the writer did not say. \
    A "helped" tag must be something the writer explicitly said helped. \
    Every quote must be copied word for word from the entry.
    """

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        do {
            return try await run(text: text, vocabulary: vocabulary)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                do {
                    return try await run(text: String(text.prefix(3_000)), vocabulary: [])
                } catch let retry as LanguageModelSession.GenerationError {
                    throw Self.map(retry)
                }
            default:
                throw Self.map(error)
            }
        }
    }

    private func run(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        let session = LanguageModelSession(model: SystemLanguageModel(useCase: .contentTagging), instructions: Self.instructions)
        var prompt = "Journal entry:\n\"\"\"\n\(text)\n\"\"\""
        if !vocabulary.isEmpty {
            prompt += "\n\nLabels this writer already uses (reuse one when it fits): \(vocabulary.joined(separator: ", "))"
        }
        let response = try await session.respond(to: prompt, generating: GeneratedTags.self)
        let drafts = response.content.tags.map { tag in
            SuggestedTagDraft(label: tag.label, kind: Self.kind(tag.kind), quote: tag.quote)
        }
        if drafts.isEmpty { throw TaggingEngineError.nothingToSuggest }
        return drafts
    }

    static func kind(_ k: GeneratedTagKind) -> TagKind {
        switch k {
        case .feeling: .feeling
        case .situation: .situation
        case .helped: .helped
        case .topic: .topic
        }
    }

    static func map(_ error: LanguageModelSession.GenerationError) -> TaggingEngineError {
        switch error {
        case .guardrailViolation, .refusal, .unsupportedLanguageOrLocale: .nothingToSuggest
        default: .failed
        }
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/Services/TaggingCoordinator.swift
import Foundation
import Observation
import SwiftData

public enum TaggingPhase: Equatable, Sendable {
    case running, failed, none, unavailable, unsupported, off, done
}

/// Runs tagging after save, one entry at a time, and records each entry's phase (spec §5.2).
@MainActor
@Observable
public final class TaggingCoordinator {
    public static let maxCharacters = 6_000

    public private(set) var phases: [UUID: TaggingPhase] = [:]
    @ObservationIgnored public var engine: any TaggingEngine
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let availability: () -> AIAvailability
    @ObservationIgnored private let isEnabled: () -> Bool
    @ObservationIgnored private var queue: [UUID] = []
    @ObservationIgnored private var worker: Task<Void, Never>?

    public init(context: ModelContext, engine: any TaggingEngine,
                availability: @escaping () -> AIAvailability, isEnabled: @escaping () -> Bool) {
        self.context = context
        self.engine = engine
        self.availability = availability
        self.isEnabled = isEnabled
    }

    public func phase(for entry: Entry) -> TaggingPhase {
        phases[entry.id] ?? (entry.tagging == .failed ? .failed : .done)
    }

    public func enqueue(_ entry: Entry) {
        if let gate = gate() {
            phases[entry.id] = gate
            if gate == .off || gate == .unsupported { entry.tagging = .skipped }
            save()
            return
        }
        phases[entry.id] = .running
        entry.tagging = .pending
        save()
        if !queue.contains(entry.id) { queue.append(entry.id) }
        startWorker()
    }

    public func retry(_ entry: Entry) {
        phases[entry.id] = nil
        enqueue(entry)
    }

    /// Re-queues entries saved while the app was killed or AI wasn't ready.
    public func resumePending() {
        let pending = (try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.taggingRaw == "pending" }))) ?? []
        for entry in pending { enqueue(entry) }
    }

    /// Waits until the queue is empty (tests and previews).
    public func drain() async {
        while let w = worker { await w.value }
    }

    private func gate() -> TaggingPhase? {
        guard isEnabled() else { return .off }
        switch availability() {
        case .ready: return nil
        case .unsupported: return .unsupported
        case .needsAppleIntelligence, .preparing: return .unavailable
        }
    }

    private func startWorker() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while let self, !self.queue.isEmpty {
                let id = self.queue.removeFirst()
                await self.process(id)
            }
            self?.worker = nil
        }
    }

    private func process(_ id: UUID) async {
        guard let entry = fetch(id) else { phases[id] = nil; return }
        let text = String(entry.text.prefix(Self.maxCharacters))
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { finish(entry, .none, .done); return }
        let vocabulary = TagIndex(entries: allEntries()).topLabels(30)
        do {
            let drafts = try await engine.suggest(text: text, vocabulary: vocabulary)
            guard let entry = fetch(id) else { phases[id] = nil; return }
            let existing = Set(entry.tags.map { $0.label.lowercased() })
            let clean = SuggestionSanitizer.sanitize(drafts, text: entry.text, existingLabels: existing)
            guard !clean.isEmpty else { finish(entry, .none, .done); return }
            for d in clean { entry.addTag(label: d.label, kind: d.kind, quote: d.quote, status: .suggested) }
            finish(entry, .done, .done)
        } catch TaggingEngineError.nothingToSuggest {
            if let entry = fetch(id) { finish(entry, .none, .done) } else { phases[id] = nil }
        } catch {
            if let entry = fetch(id) { finish(entry, .failed, .failed) } else { phases[id] = nil }
        }
    }

    private func finish(_ entry: Entry, _ phase: TaggingPhase, _ status: TaggingStatus) {
        phases[entry.id] = phase
        entry.tagging = status
        save()
    }

    private func fetch(_ id: UUID) -> Entry? {
        try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.id == id })).first
    }

    private func allEntries() -> [Entry] {
        (try? context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }

    private func save() { try? context.save() }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `swift test`. Expected: all tests pass. `FoundationModelIntegrationTests` either runs (if Apple Intelligence is on for this Mac) or shows as skipped; record which. If the `AIAvailability` switch reports non-exhaustiveness, add `@unknown default: .unsupported`.

- [ ] **Step 5: Commit.** `git add Packages && git commit -m "MementoCore: on-device tagger and tagging coordinator"`

---

### Task 9: Sol (conversation model, engines, reflection, safety)

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/AI/{SolEngine,SolConversation,ScriptedSol,FoundationModelSol,ReflectionTemplate,CrisisSignal}.swift`
- Test: `Packages/MementoCore/Tests/MementoCoreTests/SolTests.swift`

**Interfaces:**
- Produces:
  - `SolMessage {id, role: .sol | .me | .support, text}`
  - `SolTurn {reply, suggestions}`
  - `SolEngineError {guardrail, failed}`
  - `@MainActor protocol SolEngine` with `prewarm()`, `reset()`, `reply(to:history:steerTowardReflection:) -> AsyncThrowingStream<SolTurn, any Error>`, and `draftReflection(from:) async throws -> String`
  - `@MainActor @Observable SolConversation(engine:)` with `messages`, `suggestions`, `isResponding`, `isAwaitingFirstToken`, `input`, `userTurns`, `canSend`, `canMakeReflection`, `reachedCap`, `userMessages`, `send(_:) async`, `reset()`, `softCap = 12`, `steerFrom = 8`
  - `ScriptedSol(thinkDelay:wordDelay:)`, `FoundationModelSol()`
  - `ReflectionTemplate.make(userMessages:)`, `ReflectionTemplate.closingPrompt`
  - `CrisisSignal.matches(_:)`, `CrisisSignal.supportMessage`

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/SolTests.swift
import Testing
import Foundation
@testable import MementoCore

@MainActor
final class ThrowingSol: SolEngine {
    let error: any Error
    init(_ error: any Error) { self.error = error }
    func prewarm() {}
    func reset() {}
    func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        let error = self.error
        return AsyncThrowingStream { c in
            c.yield(SolTurn(reply: "Half a", suggestions: []))
            c.finish(throwing: error)
        }
    }
    func draftReflection(from userMessages: [String]) async throws -> String { throw SolEngineError.failed }
}

@MainActor
@Suite struct SolTests {
    func scripted() -> SolConversation { SolConversation(engine: ScriptedSol(thinkDelay: .zero, wordDelay: .zero)) }

    @Test func opensWithStaticGreeting() {
        let c = scripted()
        #expect(c.messages.map(\.role) == [.sol])
        #expect(c.messages[0].text == SolConversation.opening)
        #expect(c.suggestions == SolConversation.openingSuggestions)
        #expect(!c.canMakeReflection)
    }

    @Test func sendStreamsReplyAndReturnsToIdle() async {
        let c = scripted()
        c.input = "The launch date at work"
        await c.send()
        #expect(c.messages.map(\.role) == [.sol, .me, .sol])
        #expect(c.messages[2].text == ScriptedSol.replies[0])
        #expect(!c.isResponding && !c.isAwaitingFirstToken)
        #expect(c.input.isEmpty)
        #expect(c.canSend && c.canMakeReflection)
        #expect(c.suggestions == ScriptedSol.followUps[0])
    }

    @Test func sendWhileRespondingIsIgnored() async {
        let c = SolConversation(engine: ScriptedSol(thinkDelay: .milliseconds(200), wordDelay: .zero))
        async let first: Void = c.send("One")
        try? await Task.sleep(for: .milliseconds(20))
        #expect(c.isResponding)
        await c.send("Two")
        await first
        #expect(c.userMessages == ["One"])
    }

    @Test func streamFailureFallsBackAndReturnsToIdle() async {
        let c = SolConversation(engine: ThrowingSol(SolEngineError.failed))
        await c.send("Hello")
        #expect(c.messages.last?.text == SolConversation.fallbackReply)
        #expect(c.messages.filter { $0.role == .sol }.count == 2)
        #expect(!c.isResponding && c.canSend)
    }

    @Test func guardrailShowsSupportCard() async {
        let c = SolConversation(engine: ThrowingSol(SolEngineError.guardrail))
        await c.send("Hello")
        #expect(c.messages.last?.role == .support)
    }

    @Test func crisisWordsSkipTheModel() async {
        let c = scripted()
        await c.send("Some nights I want to die")
        #expect(c.messages.map(\.role) == [.sol, .me, .support])
        #expect(CrisisSignal.matches("thinking about suicide"))
        #expect(CrisisSignal.matches("I want to end it all"))
        #expect(!CrisisSignal.matches("the end of my day was nice"))
        #expect(!CrisisSignal.matches("this deadline is killing me"))
    }

    @Test func softCapStopsInput() async {
        let c = scripted()
        for i in 0..<SolConversation.softCap { await c.send("Message \(i)") }
        #expect(c.reachedCap && !c.canSend)
        await c.send("One more")
        #expect(c.userTurns == SolConversation.softCap)
        #expect(c.suggestions.isEmpty)
    }

    @Test func reflectionTemplateUsesOnlyUserWords() {
        let t = ReflectionTemplate.make(userMessages: ["The launch date at work.", "That I'll let Dana down"])
        #expect(t == "Tonight I talked through the launch date at work.\n\nWhat came up after that: that I'll let Dana down.\n\nOne thing I'd like to try this week: ")
        #expect(ReflectionTemplate.make(userMessages: []).hasPrefix("Tonight I talked through my day."))
    }

    @Test func resetRestoresOpening() async {
        let c = scripted()
        await c.send("Hi")
        c.reset()
        #expect(c.messages.count == 1 && c.userTurns == 0)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail.** Run `swift test --filter SolTests`. Expected: compile errors.

- [ ] **Step 3: Implement**

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/SolEngine.swift
import Foundation

public struct SolMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable { case sol, me, support }
    public let id: UUID
    public let role: Role
    public var text: String

    public init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

public struct SolTurn: Equatable, Sendable {
    public var reply: String
    public var suggestions: [String]

    public init(reply: String, suggestions: [String]) {
        self.reply = reply
        self.suggestions = suggestions
    }
}

public enum SolEngineError: Error, Equatable {
    case guardrail, failed
}

@MainActor
public protocol SolEngine: AnyObject {
    func prewarm()
    func reset()
    /// Streams growing snapshots of Sol's reply; suggestions are complete on the last element.
    func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error>
    func draftReflection(from userMessages: [String]) async throws -> String
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/SolConversation.swift
import Foundation
import Observation

/// One Sol chat: never persisted (spec §5.3), soft-capped at 12 writer turns (D22).
@MainActor
@Observable
public final class SolConversation {
    public static let opening = "Hi. What’s taking up the most room in your head tonight?"
    public static let openingSuggestions = ["Work, mostly", "Something someone said", "Honestly, I’m not sure"]
    public static let fallbackReply = "I lost my train of thought for a second. Could you say that another way?"
    public static let softCap = 12
    public static let steerFrom = 8

    public private(set) var messages: [SolMessage] = []
    public private(set) var suggestions: [String] = []
    public private(set) var isResponding = false
    public private(set) var isAwaitingFirstToken = false
    public var input = ""
    @ObservationIgnored private let engine: any SolEngine

    public init(engine: any SolEngine) {
        self.engine = engine
        reset()
    }

    public var userTurns: Int { messages.filter { $0.role == .me }.count }
    public var userMessages: [String] { messages.filter { $0.role == .me }.map(\.text) }
    public var reachedCap: Bool { userTurns >= Self.softCap }
    public var canSend: Bool { !isResponding && !reachedCap }
    public var canMakeReflection: Bool { userTurns >= 1 && !isResponding }

    public func reset() {
        messages = [SolMessage(role: .sol, text: Self.opening)]
        suggestions = Self.openingSuggestions
        input = ""
        engine.reset()
    }

    public func prewarm() { engine.prewarm() }

    public func send(_ override: String? = nil) async {
        let text = (override ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, canSend else { return }
        input = ""
        suggestions = []
        let history = messages
        messages.append(SolMessage(role: .me, text: text))
        if CrisisSignal.matches(text) {
            messages.append(SolMessage(role: .support, text: CrisisSignal.supportMessage))
            return
        }
        isResponding = true
        isAwaitingFirstToken = true
        defer {
            isResponding = false
            isAwaitingFirstToken = false
        }
        var replyID: UUID?
        var finalSuggestions: [String] = []
        do {
            let stream = engine.reply(to: text, history: history, steerTowardReflection: userTurns >= Self.steerFrom)
            for try await turn in stream where !turn.reply.isEmpty {
                isAwaitingFirstToken = false
                if let id = replyID, let i = messages.firstIndex(where: { $0.id == id }) {
                    messages[i].text = turn.reply
                } else {
                    let m = SolMessage(role: .sol, text: turn.reply)
                    replyID = m.id
                    messages.append(m)
                }
                finalSuggestions = turn.suggestions
            }
            if replyID == nil { messages.append(SolMessage(role: .sol, text: Self.fallbackReply)) }
        } catch SolEngineError.guardrail {
            removeMessage(replyID)
            messages.append(SolMessage(role: .support, text: CrisisSignal.supportMessage))
        } catch {
            removeMessage(replyID)
            messages.append(SolMessage(role: .sol, text: Self.fallbackReply))
        }
        suggestions = reachedCap ? [] : finalSuggestions
    }

    private func removeMessage(_ id: UUID?) {
        guard let id else { return }
        messages.removeAll { $0.id == id }
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/ScriptedSol.swift
import Foundation

/// Deterministic Sol for UI tests and the demo backup; replies are the prototype's.
@MainActor
public final class ScriptedSol: SolEngine {
    public static let replies = [
        "That sounds like a lot to carry into the evening. If you picture saying no to one thing this week, what comes up first?",
        "So part of you worries that saying no lets people down — and part of you already knows what you need. Would you like to turn this into a reflection you can keep?",
    ]
    public static let followUps: [[String]] = [["That I'll let Dana down", "Relief, honestly"], []]
    public static let closing = "Would you like to turn this into a reflection you can keep?"

    private var step = 0
    private let thinkDelay: Duration
    private let wordDelay: Duration

    public init(thinkDelay: Duration = .milliseconds(700), wordDelay: Duration = .milliseconds(25)) {
        self.thinkDelay = thinkDelay
        self.wordDelay = wordDelay
    }

    public func prewarm() {}
    public func reset() { step = 0 }

    public func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        let index = step
        step += 1
        let full = index < Self.replies.count ? Self.replies[index] : Self.closing
        let chips = index < Self.followUps.count ? Self.followUps[index] : []
        let think = thinkDelay, word = wordDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                if think > .zero { try? await Task.sleep(for: think) }
                let words = full.split(separator: " ")
                var built = ""
                for (i, w) in words.enumerated() {
                    built += (i == 0 ? "" : " ") + w
                    continuation.yield(SolTurn(reply: built, suggestions: i == words.count - 1 ? chips : []))
                    if word > .zero { try? await Task.sleep(for: word) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func draftReflection(from userMessages: [String]) async throws -> String {
        ReflectionTemplate.make(userMessages: userMessages)
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/FoundationModelSol.swift
import Foundation
import FoundationModels

@Generable
struct SolTurnContent {
    @Guide(description: "Sol's reply: warm, at most two short sentences, reflecting the writer's words and ending with one open question")
    var reply: String
    @Guide(description: "Two short first-person replies the writer might tap next, each under seven words", .count(2))
    var suggestions: [String]
}

@Generable
struct ReflectionContent {
    @Guide(description: "A short first-person reflection, two or three short paragraphs, using only what the writer said")
    var text: String
}

/// Sol on Apple's on-device model, one session per conversation (spec §5.3).
@MainActor
public final class FoundationModelSol: SolEngine {
    static let persona = """
    You are Sol, a gentle reflection companion inside Memento, a private journal that runs \
    entirely on this iPhone. Help the writer think things through.
    - Reply in at most two short sentences.
    - Reflect the writer's own words back, then ask one open question.
    - Never diagnose, never name conditions, never give medical, legal or financial advice, \
    and never claim to be a therapist.
    - Do not encourage the writer to rely on you; when it fits, point them toward people they trust.
    - Do not invent facts about the writer's life.
    - Suggestions are two short first-person replies the writer could tap.
    """

    static let reflectionInstructions = """
    Turn the writer's own messages into a short private journal reflection written in the first \
    person ("I"). Use only what the writer said; add no new facts, advice or diagnosis. \
    Plain, warm language. Do not address the reader.
    """

    private var session: LanguageModelSession?

    public init() {}

    private func makeSession(earlier: [SolMessage] = []) -> LanguageModelSession {
        var instructions = Self.persona
        let recent = earlier.suffix(4).filter { $0.role != .support }
        if !recent.isEmpty {
            instructions += "\n\nEarlier in this conversation:\n" + recent.map { "\($0.role == .me ? "Writer" : "Sol"): \($0.text)" }.joined(separator: "\n")
        }
        return LanguageModelSession(instructions: instructions)
    }

    public func prewarm() {
        let s = session ?? makeSession()
        session = s
        s.prewarm()
    }

    public func reset() { session = nil }

    public func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        let prompt = steerTowardReflection
            ? text + "\n\n(Gently offer to turn this conversation into a written reflection the writer can keep.)"
            : text
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    try await self.stream(prompt, into: continuation)
                    continuation.finish()
                } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                    self.session = self.makeSession(earlier: history)
                    do {
                        try await self.stream(prompt, into: continuation)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: Self.map(error))
                    }
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func stream(_ prompt: String, into continuation: AsyncThrowingStream<SolTurn, any Error>.Continuation) async throws {
        let session = self.session ?? makeSession()
        self.session = session
        for try await snapshot in session.streamResponse(to: prompt, generating: SolTurnContent.self) {
            continuation.yield(SolTurn(reply: snapshot.content.reply ?? "", suggestions: snapshot.content.suggestions ?? []))
        }
    }

    public func draftReflection(from userMessages: [String]) async throws -> String {
        let session = LanguageModelSession(instructions: Self.reflectionInstructions)
        let numbered = userMessages.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        do {
            let response = try await session.respond(to: "The writer said:\n\(numbered)", generating: ReflectionContent.self)
            let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw SolEngineError.failed }
            return text + "\n\n" + ReflectionTemplate.closingPrompt
        } catch {
            throw Self.map(error)
        }
    }

    static func map(_ error: any Error) -> SolEngineError {
        if let e = error as? SolEngineError { return e }
        if let g = error as? LanguageModelSession.GenerationError {
            switch g {
            case .guardrailViolation, .refusal: return .guardrail
            default: return .failed
            }
        }
        return .failed
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/ReflectionTemplate.swift
import Foundation

/// Fallback reflection built only from the writer's words (prototype makeReflection).
public enum ReflectionTemplate {
    public static let closingPrompt = "One thing I'd like to try this week: "

    public static func make(userMessages: [String]) -> String {
        let cleaned = userMessages.map { lowerFirst($0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))) }
        var text = "Tonight I talked through \(cleaned.first ?? "my day")."
        if cleaned.count > 1 {
            text += "\n\nWhat came up after that: \(cleaned.dropFirst().joined(separator: "; "))."
        }
        return text + "\n\n" + closingPrompt
    }

    static func lowerFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        if s.hasPrefix("I ") || s.hasPrefix("I'") || s == "I" { return s }
        return first.lowercased() + s.dropFirst()
    }
}
```

```swift
// File: Packages/MementoCore/Sources/MementoCore/AI/CrisisSignal.swift
import Foundation

/// Offline safety net for Sol (spec D17): crisis language shows the Support card instead of a model reply.
public enum CrisisSignal {
    static let patterns = [
        #"\bkill(?:ing)? myself\b"#, #"\bsuicid"#, #"\bend (?:it all|my life)\b"#, #"\bself[- ]?harm"#,
        #"\bhurt(?:ing)? myself\b"#, #"\bwant(?:ed)? to die\b"#, #"\bdon'?t want to (?:be alive|live|be here)\b"#,
        #"\bcut(?:ting)? myself\b"#,
    ]

    public static let supportMessage = "It sounds like you’re carrying something really heavy, and you deserve support from a person right now. If you might act on these thoughts, call your local emergency number. In the US you can call or text 988, any time."

    public static func matches(_ text: String) -> Bool {
        patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `swift test`. Expected: all tests pass. `ReflectionTemplate.make(["The launch date at work.", "That I'll let Dana down"])` must equal the test string exactly. Note that `lowerFirst` lowercases "That" to "that" but keeps "I …".

- [ ] **Step 5: Commit.** `git add Packages && git commit -m "MementoCore: Sol conversation, engines, reflection and safety net"`

---

### Task 10: SampleJournal (the prototype's "Maya" journal, demo seed)

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/Sample/SampleJournal.swift`
- Test: `Packages/MementoCore/Tests/MementoCoreTests/SampleJournalTests.swift`

**Interfaces:**
- Produces:
  - `SampleJournal.load(into:today:calendar:photo:) throws -> Int`, which inserts only the entries not already present
  - `SampleJournal.entryIDs`
  - `SampleJournal.clear(from:)`

- [ ] **Step 1: Write the failing tests**

```swift
// File: Packages/MementoCore/Tests/MementoCoreTests/SampleJournalTests.swift
import Testing
import SwiftData
@testable import MementoCore

@MainActor
@Suite struct SampleJournalTests {
    @Test func loadsEightEntriesOnceWithPrototypeShape() throws {
        let s = try TestStore()
        #expect(try SampleJournal.load(into: s.context, today: Fixtures.today, calendar: Fixtures.calendar) == 8)
        #expect(try SampleJournal.load(into: s.context, today: Fixtures.today, calendar: Fixtures.calendar) == 0)
        let entries = try s.all()
        let index = TagIndex(entries: entries)
        #expect(entries.count == 8)
        #expect(index.count(for: "Walking helped") == 3)
        #expect(index.count(for: "Work deadlines") == 2)
        #expect(JournalInsights.pending(entries).label == "2 suggestions waiting in 2 entries")
        #expect(Streak.compute(entryDates: entries.map(\.createdAt), today: Fixtures.today, calendar: Fixtures.calendar).count == 3)
        #expect(entries.first(where: { $0.mode == .guided })?.prompt == "What are three small things you're grateful for today?")
        #expect(entries.allSatisfy { $0.tagging == .done })
    }

    @Test func clearRemovesEverything() throws {
        let s = try TestStore()
        _ = try SampleJournal.load(into: s.context, today: Fixtures.today, calendar: Fixtures.calendar)
        s.entry(text: "Mine.")
        try SampleJournal.clear(from: s.context)
        #expect(try s.all().isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail.** Run `swift test --filter SampleJournalTests`. Expected: compile error.

- [ ] **Step 3: Implement.** This is a direct port of the prototype's `SEED` (proto L683–692). Each entry's day offset is measured from today: e8 −1 (11:52 PM), e7 −2 (10:05 PM), e6 −3 (7:40 PM), e5 −5 (9:15 AM), e4 −10 (8:30 PM), e3 −15 (11:10 PM), e2 −22 (9:48 PM), e1 −27 (8:02 PM).

```swift
// File: Packages/MementoCore/Sources/MementoCore/Sample/SampleJournal.swift
import Foundation
import SwiftData

/// The prototype's sample journal, loaded from You → Demo (spec D10).
public enum SampleJournal {
    struct Seed {
        let n: Int
        let daysAgo: Int, hour: Int, minute: Int
        let notebook: String
        let mode: WritingMode
        var prompt: String? = nil
        var hasPhoto = false
        let text: String
        let tags: [(String, TagKind, String?, TagStatus)]
    }

    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "4D454D00-0000-4000-8000-%012d", n))! }
    public static var entryIDs: [UUID] { seeds.map { id($0.n) } }

    static let seeds: [Seed] = [
        Seed(n: 8, daysAgo: 1, hour: 23, minute: 52, notebook: "daily", mode: .free,
             text: "Couldn't sleep until almost two. Kept replaying the conversation with Dana about moving the launch date, and everything I should have said.\n\nMade tea at midnight, which didn't help. Writing out a list of what's actually due this week did.",
             tags: [("Poor sleep", .situation, "Couldn't sleep until almost two", .kept), ("Restless", .feeling, "Kept replaying", .suggested),
                    ("Conflict", .situation, "the conversation with Dana about moving the launch date", .kept),
                    ("Writing it down", .helped, "Writing out a list of what's actually due this week did", .kept)]),
        Seed(n: 7, daysAgo: 2, hour: 22, minute: 5, notebook: "daily", mode: .free,
             text: "Finished the book Priya lent me — read the last chapter in the bath. Nothing much happened today and honestly that felt like a gift.",
             tags: [("Calm", .feeling, "that felt like a gift", .kept), ("Reading", .helped, "read the last chapter in the bath", .kept)]),
        Seed(n: 6, daysAgo: 3, hour: 19, minute: 40, notebook: "work", mode: .dump,
             text: "Deadlines everywhere. Sprint review moved up to Thursday, the deck isn't done, and I said yes to mentoring the new hire because apparently I can't say no. Overwhelmed is the word.\n\nTook the long way home through the park and felt like a person again.",
             tags: [("Work deadlines", .situation, "Deadlines everywhere", .kept), ("Boundaries", .situation, "apparently I can't say no", .suggested),
                    ("Overwhelmed", .feeling, "Overwhelmed is the word", .kept), ("Walking helped", .helped, "Took the long way home through the park", .kept)]),
        Seed(n: 5, daysAgo: 5, hour: 9, minute: 15, notebook: "grat", mode: .guided, prompt: "What are three small things you're grateful for today?",
             text: "Sunday pancakes with Theo, even though we burned the first batch.\nTomatoes from the market that actually taste like tomatoes.\nMum calling just to say hi.",
             tags: [("Grateful", .feeling, "Sunday pancakes with Theo", .kept), ("Family", .topic, "Mum calling just to say hi", .kept)]),
        Seed(n: 4, daysAgo: 10, hour: 20, minute: 30, notebook: "daily", mode: .photo, hasPhoto: true,
             text: "My first bowl is lopsided and I love it. Two hours where I didn't check my phone once.",
             tags: [("Absorbed", .feeling, "Two hours where I didn't check my phone once", .kept),
                    ("Making things", .helped, "My first bowl is lopsided and I love it", .kept), ("Creativity", .topic, nil, .kept)]),
        Seed(n: 3, daysAgo: 15, hour: 23, minute: 10, notebook: "work", mode: .free,
             text: "Third late night this week and I'm completely drained. Snapped at Theo over nothing and had to apologise.\n\nWalked to the corner shop just to get out of the flat, and it took the edge off.",
             tags: [("Work deadlines", .situation, "Third late night this week", .kept), ("Drained", .feeling, "I'm completely drained", .kept),
                    ("Conflict", .situation, "Snapped at Theo over nothing", .kept), ("Walking helped", .helped, "Walked to the corner shop just to get out of the flat", .kept)]),
        Seed(n: 2, daysAgo: 22, hour: 21, minute: 48, notebook: "refl", mode: .sol,
             text: "On saying no. I keep agreeing to things before I've checked whether I have room for them. Tonight I noticed it's less about being helpful and more about not wanting to disappoint anyone.\n\nNext time, I'll start with “let me get back to you.”",
             tags: [("Boundaries", .situation, "I keep agreeing to things before I've checked whether I have room for them", .kept),
                    ("Hopeful", .feeling, "Next time, I'll start with “let me get back to you.”", .kept)]),
        Seed(n: 1, daysAgo: 27, hour: 20, minute: 2, notebook: "daily", mode: .free,
             text: "Long walk with Priya after work. Told her about my doubts about the job and she didn't try to fix anything, just listened. Felt lighter on the way home.",
             tags: [("Walking helped", .helped, "Long walk with Priya after work", .kept), ("Talking to a friend", .helped, "she didn't try to fix anything, just listened", .kept),
                    ("Lighter", .feeling, "Felt lighter on the way home", .kept), ("Work", .topic, "my doubts about the job", .kept)]),
    ]

    @MainActor @discardableResult
    public static func load(into context: ModelContext, today: Date = .now, calendar: Calendar = .current, photo: Data? = nil) throws -> Int {
        let existing = Set(try context.fetch(FetchDescriptor<Entry>()).map(\.id))
        var inserted = 0
        for seed in seeds where !existing.contains(id(seed.n)) {
            let day = calendar.date(byAdding: .day, value: -seed.daysAgo, to: calendar.startOfDay(for: today))!
            let date = calendar.date(bySettingHour: seed.hour, minute: seed.minute, second: 0, of: day)!
            let entry = Entry(id: id(seed.n), createdAt: date, notebookID: seed.notebook, mode: seed.mode,
                              prompt: seed.prompt, text: seed.text, photoData: seed.hasPhoto ? photo : nil, tagging: .done)
            context.insert(entry)
            for t in seed.tags { entry.addTag(label: t.0, kind: t.1, quote: t.2, status: t.3) }
            inserted += 1
        }
        try context.save()
        return inserted
    }

    /// Demo → Clear journal: deletes every entry (and, by cascade, every tag).
    @MainActor
    public static func clear(from context: ModelContext) throws {
        try context.delete(model: Entry.self)
        try context.delete(model: TagMark.self)
        try context.save()
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass.** Run `cd Packages/MementoCore && swift test`. Expected: **every** MementoCore test passes. This is the Phase B gate.

- [ ] **Step 5: Commit and push Phase B**

```bash
git add Packages && git commit -m "MementoCore: sample journal seed and clear"
cd Packages/MementoCore && swift test && cd ../.. && git push origin app:main
```

---

## Phase C: design system and app shell

> **UI tasks (11–22):** each one names its prototype source lines, gives the exact state, interfaces and copy, and shows the non-obvious code in full. Markup that is a straight translation of the referenced prototype lines (padding, radii, font sizes) is specified as values rather than repeated as code. The prototype file is in the repo and is the source of truth for them. Each task ends with a build, its UI test, and a screenshot check against the prototype.

### Task 11: Design system (colors, type, components)

**Files:**
- Create: `Memento/Resources/Assets.xcassets/Colors/<token>.colorset/Contents.json`, one per token in Global Constraints, each with light and dark sRGB values
- Create: `Memento/DesignSystem/{Palette,Typography,Chips,Controls,Surfaces,Toast,PaperArt,NotebookCover,Screen}.swift`

**Interfaces:**
- Produces:
  - Colors: `Color.mPage`, `.mBg`, `.mCard`, `.mSheet`, `.mInk`, `.mMut`, `.mLine`, `.mTer`, `.mOnTer`, `.mTerT`, `.mSage`, `.mSageT`, `.mUmb`, `.mUmbT`, `.mSlate`, `.mSlateT`, `.mDanger`
  - `TagKind.color`, `TagKind.tint`, `TagKind.emblem` (asset name `kind-*`)
  - Fonts: `Font.serif(_ size:, relativeTo:, italic:, weight:)`, `Font.ui(_ size:, relativeTo:, weight:)`, `Font.mono(_ size:, relativeTo:)`
  - Text: `Eyebrow(_:)`
  - Chips: `TagChip(label:kind:status:size:count:)` (`.small` / `.regular`), `FilterChip(label:isOn:action:)`
  - Controls: `SegmentedPill(options:selection:)`, `SageToggleStyle`
  - Button styles: `.primaryPill` (terracotta 54 pt, radius 16), `.inkFilled`, `.outlineInk`, `.softPill(tint:)`
  - Surfaces: `.paperCard(radius:padding:)`, `.dashedBorder(radius:color:)`, `SettingsGroup { }`, `SettingsRow(title:value:action:)`
  - `ToastView`
  - `PaperArt(name:size:)`: the asset inside a cream card with a 1 pt line border. If the asset is missing it falls back to the prototype's hatched placeholder, so builds never depend on image generation.
  - `PaperIcon(name:size:)`: the asset on a `mCard` disc
  - `NotebookCover(notebook:showsLabel:)`
  - `Screen { }`: a scroll container with `mBg` background, a 20 pt side gutter, and a 120 pt bottom margin for the tab bar

- [ ] **Step 1: Write the color sets.** A script generates them from the token table: one `Contents.json` per color, with `"appearances":[{"appearance":"luminosity","value":"dark"}]` for the dark variant, `color-space` `srgb`, and components as `0xRR`-style hex strings. Run it once, then commit the output (not the script, which lives in the scratchpad).

- [ ] **Step 2: Typography with optical sizing and Dynamic Type**

```swift
// File: Memento/DesignSystem/Typography.swift
import SwiftUI
import UIKit

extension Font {
    /// Newsreader with the optical-size axis set to the point size (6–72), scaled for Dynamic Type.
    static func serif(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, italic: Bool = false, weight: CGFloat = 400) -> Font {
        let family = italic ? "Newsreader-Italic" : "Newsreader"
        let opsz = min(max(size, 6), 72)
        let variations: [UInt32: CGFloat] = [0x6F70737A /* opsz */: opsz, 0x77676874 /* wght */: weight]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "Newsreader",
            .name: family,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations,
        ])
        let base = UIFont(descriptor: descriptor, size: size)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    static func ui(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight).leading(.standard)
    }

    static func mono(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption, weight: Font.Weight = .medium) -> Font {
        .custom("JetBrains Mono", size: size, relativeTo: style).weight(weight)
    }
}

/// Uppercase tracked label ("TONIGHT", "SUGGESTED · 3").
struct Eyebrow: View {
    let text: String
    var color: Color = .mMut
    init(_ text: String, color: Color = .mMut) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(.ui(12, relativeTo: .caption, weight: .semibold)).tracking(1.2).foregroundStyle(color)
    }
}
```

`.ui` must scale with Dynamic Type. Use `Font.system(size:weight:)` wrapped by the `@ScaledMetric`-free `UIFontMetrics` approach, *or* the simpler `.system(.body)` text styles at the prototype's sizes. Step 6 verifies that both serif and UI text grow at the accessibility XL size.

**Font check.** Add a DEBUG-only `onAppear` print of `UIFont.fontNames(forFamilyName: "Newsreader")` in a preview, and confirm the family registers as `Newsreader` with faces `Newsreader-Regular` (or a similar variable instance name) and an italic face. If the PostScript names differ, update `family` accordingly. This check is recorded in the commit message.

- [ ] **Step 3: Palette and kind colors**

```swift
// File: Memento/DesignSystem/Palette.swift
import SwiftUI
import MementoCore

extension Color {
    static let mPage = Color("page"), mBg = Color("bg"), mCard = Color("card"), mSheet = Color("sheet")
    static let mInk = Color("ink"), mMut = Color("mut"), mLine = Color("line")
    static let mTer = Color("ter"), mOnTer = Color("onTer"), mTerT = Color("terT")
    static let mSage = Color("sage"), mSageT = Color("sageT"), mUmb = Color("umb"), mUmbT = Color("umbT")
    static let mSlate = Color("slate"), mSlateT = Color("slateT"), mDanger = Color("danger")

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension TagKind {
    var color: Color {
        switch self { case .feeling: .mTer; case .situation: .mUmb; case .helped: .mSage; case .topic: .mSlate }
    }
    var tint: Color {
        switch self { case .feeling: .mTerT; case .situation: .mUmbT; case .helped: .mSageT; case .topic: .mSlateT }
    }
    var emblem: String { "kind-\(rawValue)" }
}
```

- [ ] **Step 4: Components.** Values come from the prototype's style helpers (proto L721–726, L814):
  - `TagChip` (`chipSt`):
    - padding 4/9 (small) or 7/12 (regular); font 12/14 weight 500; capsule
    - Suggested: transparent fill, dashed 1 pt border in `kind.color`, text `kind.color`
    - Kept: `kind.tint` fill, text `kind.color`
    - Optional count suffix ` · n` at 0.7 opacity; when `count` is passed it renders as ` n`, the way Discover does
    - Accessibility value is "suggested" or "kept"
  - `FilterChip` (`fchip`): padding 8/14, font 14/500; on = `mInk` fill with `mBg` text; off = `mCard` fill, `mLine` border.
  - `SegmentedPill` (`segSt`): track `mLine` with 3 pt padding and radius 12; selected segment `mCard` with shadow 0 1 3 at 0.12, height 32, radius 9, font 13 (600 when on, 500 otherwise).
  - `SageToggleStyle` (`sw`): 51×31 track, `mSage` on / `mLine` off, 27 pt white knob with shadow 0 2 4 at 0.2, a 0.22 s ease animation unless Reduce Motion is on.
  - `ToastView`: `mInk` background, `mBg` text at 15 pt, padding 14/16, radius 16, an optional "Undo" button in `mTerT` weight 700, shadow 0 10 30 at 0.4.
  - `PaperArt`: shows `Image(name)` if `UIImage(named:)` exists. Otherwise it draws a hatched placeholder: a repeating 135° line pattern in `mLine` over `mCard`, with the asset name in mono 11 pt `mMut`.
  - `NotebookCover`: the cover asset with `.fill` at a 3:4 aspect; corner radii 5/14/14/5 (`UnevenRoundedRectangle`); a 9 pt black spine strip at 0.13 opacity on the leading edge; shadow 0 12 22 −12 in rgba(40,25,10,.55).
    - If the asset is missing, fill with `Color(hex: notebook.coverHex)`.
    - Label plate: `#F7F1E6`, padding 12/14, radius 3, the name in serif 18 with a 40×1 rule in `#C9BBA5` beneath, min width 84.
  - `Screen`: `ScrollView { VStack(alignment: .leading, spacing: 18) { content }.padding(.horizontal, 20).padding(.bottom, 120) }.background(Color.mBg)` with `.scrollIndicators(.hidden)`.

- [ ] **Step 5: Gallery preview.** Create a `#Preview("Design system")` in `Screen.swift` showing every chip state, both kinds of buttons, the toggle, the segmented pill, a toast, and every `PaperArt` placeholder, in light and dark.

- [ ] **Step 6: Verify.** Build (command in Phase A). Then render the preview gallery to PNG with a temporary DEBUG launch argument `-designGallery` that shows the gallery as the root view, and screenshot it with `xcrun simctl io booted screenshot`. Check two things against proto L721–726:
  1. Chips: dashed for suggested, filled for kept, in the correct colors for all four kinds, in light and dark.
  2. Text at `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`: serif and UI text are visibly larger.

- [ ] **Step 7: Commit.** `git add Memento && git commit -m "Design system: color tokens, Newsreader optical sizing, chips, controls, paper art"`

---

### Task 12: App shell (services, routing, tab bar, toast, launch options)

**Files:**
- Create: `Memento/App/{LaunchOptions,Settings,AIStatus,AppServices,Route,AppModel,RootView}.swift`, `Memento/DesignSystem/MementoTabBar.swift`
- Modify: `Memento/App/MementoApp.swift`
- Test: `MementoUITests/MementoUITests.swift` (add `testTabsSwitch`)

**Interfaces:**
- Consumes: `MementoStore`, `TaggingCoordinator`, `RuleTaggingEngine`, `FoundationModelTagger`, `FailingOnceEngine`, `ScriptedSol`, `FoundationModelSol`, `SampleJournal`.
- Produces:
  - `LaunchOptions.current`, with `uiTesting`, `seedSample`, `skipOnboarding`, `taggingEngine`, `solEngine`, `aiState`
  - `SettingsKey`, the `@AppStorage` keys (`hasOnboarded`, `suggestTags`, `solEnabled`, `appearance`, `reminderOn`, `reminderMinutes`, `preparedBy`, `demoAIState`, `demoTaggingEngine`, `demoSolEngine`)
  - `DemoAIState {live, needsAppleIntelligence, preparing, unsupported, failing}`
  - `EngineChoice {onDevice, demo}`
  - `@Observable AIStatus`, with `availability`, `live`, `demoState`, `refresh()`
  - `@Observable AppServices`, with `container`, `tagging: TaggingCoordinator`, `ai: AIStatus`, `makeSolEngine() -> any SolEngine`, `rebuildTaggingEngine()`
  - `enum AppTab {journal, discover, notebooks, you}`
  - `enum Route: Hashable {entry(UUID), tag(String), notebook(String), reminders, onDeviceAI, summary(SummarySeed)}`
  - `SummarySeed: Hashable {ids: [UUID]?}`
  - `enum ActiveSheet: Identifiable {write, addTag(UUID), editTag(entry: UUID, tag: UUID), move(UUID), pickNotebook}`
  - `@Observable AppModel` (described in Step 3)

- [ ] **Step 1: Launch options and settings**

```swift
// File: Memento/App/LaunchOptions.swift
import Foundation

enum EngineChoice: String, CaseIterable { case onDevice, demo }
enum DemoAIState: String, CaseIterable { case live, needsAppleIntelligence, preparing, unsupported, failing }

/// Process arguments used by UI tests and screenshot runs.
struct LaunchOptions {
    var uiTesting = false
    var seedSample = false
    var skipOnboarding = false
    var taggingEngine: EngineChoice?
    var solEngine: EngineChoice?
    var aiState: DemoAIState?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        func value(_ key: String) -> String? {
            guard let i = arguments.firstIndex(of: key), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        uiTesting = arguments.contains("-uiTesting")
        seedSample = arguments.contains("-seedSampleData")
        skipOnboarding = arguments.contains("-skipOnboarding")
        taggingEngine = value("-taggingEngine").flatMap(EngineChoice.init(rawValue:))
        solEngine = value("-solEngine").flatMap(EngineChoice.init(rawValue:))
        aiState = value("-aiState").flatMap(DemoAIState.init(rawValue:))
    }
}
```

`Settings.swift` defines `enum SettingsKey { static let hasOnboarded = "hasOnboarded" … }` and `enum Appearance: String, CaseIterable { case system, light, dark }`, with `colorScheme: ColorScheme?` and `title`. The reminder time is stored as `reminderMinutes: Int`, defaulting to 1230 (8:30 PM).

- [ ] **Step 2: Services**

```swift
// File: Memento/App/AIStatus.swift
import Foundation
import Observation
import MementoCore

/// Live Apple Intelligence state, with the Demo override layered on top (spec D23).
@Observable
final class AIStatus {
    private(set) var live: AIAvailability = AIAvailability.live()
    var demoState: DemoAIState {
        didSet { UserDefaults.standard.set(demoState.rawValue, forKey: SettingsKey.demoAIState); onChange?() }
    }
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var poll: Task<Void, Never>?

    init(override: DemoAIState?) {
        demoState = override ?? DemoAIState(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoAIState) ?? "") ?? .live
    }

    var availability: AIAvailability {
        switch demoState {
        case .live: live
        case .needsAppleIntelligence: .needsAppleIntelligence
        case .preparing: .preparing
        case .unsupported: .unsupported
        case .failing: .ready
        }
    }

    func refresh() {
        let previous = availability
        live = AIAvailability.live()
        if availability != previous { onChange?() }
        poll?.cancel()
        guard live == .preparing else { return }
        poll = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            self?.refresh()
        }
    }
}
```

```swift
// File: Memento/App/AppServices.swift
import Foundation
import Observation
import SwiftData
import MementoCore

/// Owns the store, the AI status and the tagging coordinator for the app's lifetime.
@Observable
final class AppServices {
    let container: ModelContainer
    let ai: AIStatus
    let tagging: TaggingCoordinator
    let options: LaunchOptions

    init(options: LaunchOptions = .current) {
        self.options = options
        container = try! MementoStore.container(inMemory: options.uiTesting)
        ai = AIStatus(override: options.aiState)
        let defaults = UserDefaults.standard
        defaults.register(defaults: [SettingsKey.suggestTags: true, SettingsKey.solEnabled: true,
                                     SettingsKey.reminderMinutes: 1230, SettingsKey.reminderOn: false])
        let ai = self.ai
        tagging = TaggingCoordinator(context: container.mainContext, engine: RuleTaggingEngine(),
                                     availability: { ai.availability },
                                     isEnabled: { UserDefaults.standard.bool(forKey: SettingsKey.suggestTags) })
        rebuildTaggingEngine()
        ai.onChange = { [weak self] in
            self?.rebuildTaggingEngine()
            if self?.ai.availability == .ready { self?.tagging.resumePending() }
        }
        if options.seedSample { try? SampleJournal.load(into: container.mainContext, photo: SamplePhoto.data) }
        if options.skipOnboarding || options.uiTesting && options.seedSample { defaults.set(true, forKey: SettingsKey.hasOnboarded) }
        if options.uiTesting && !options.skipOnboarding && !options.seedSample { defaults.set(false, forKey: SettingsKey.hasOnboarded) }
    }

    var taggingChoice: EngineChoice {
        options.taggingEngine ?? EngineChoice(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoTaggingEngine) ?? "") ?? .onDevice
    }
    var solChoice: EngineChoice {
        options.solEngine ?? EngineChoice(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoSolEngine) ?? "") ?? .onDevice
    }

    func rebuildTaggingEngine() {
        let base: any TaggingEngine = taggingChoice == .demo ? RuleTaggingEngine() : FoundationModelTagger()
        tagging.engine = ai.demoState == .failing ? FailingOnceEngine(base: base) : base
    }

    func makeSolEngine() -> any SolEngine {
        solChoice == .demo ? ScriptedSol() : FoundationModelSol()
    }
}
```

`SamplePhoto.data` is a tiny helper in `AppServices.swift`: `enum SamplePhoto { static var data: Data? { UIImage(named: "sample-ceramics")?.jpegData(compressionQuality: 0.85) } }`, with `import UIKit`.

- [ ] **Step 3: Routing and AppModel**

```swift
// File: Memento/App/Route.swift
import Foundation
import MementoCore

enum AppTab: Hashable, CaseIterable { case journal, discover, notebooks, you }

struct SummarySeed: Hashable { var ids: [UUID]? }

enum Route: Hashable {
    case entry(UUID)
    case tag(String)
    case notebook(String)
    case reminders
    case onDeviceAI
    case summary(SummarySeed)
}

enum ActiveSheet: Identifiable, Hashable {
    case write, addTag(UUID), editTag(entry: UUID, tag: UUID), move(UUID), pickNotebook
    var id: Self { self }
}

extension WritingMode: @retroactive Identifiable { public var id: String { rawValue } }
```

`AppModel` (`@Observable`) owns:
- **State:** `tab: AppTab`; `paths: [AppTab: [Route]]` (exposed as `binding(for:)`); `sheet: ActiveSheet?`; `editorMode: WritingMode?` (full-screen cover); `isSolPresented: Bool`; `toast: Toast?` where `Toast {id, text, undo: (() -> Void)?}`; `justSavedID: UUID?`; `draft: Draft`.
- **Draft:** `Draft {mode, text, promptCategory, promptIndex, photo: Data?, notebookID}`, initialized as `Draft(mode: .free, text: "", promptCategory: .mind, promptIndex: 0, photo: nil, notebookID: "daily")`.
- **Navigation:** `push(_ route:)` appends to the current tab's path. `select(_ tab:)` sets the tab and clears its path (matching the prototype's `tabTo`).
- **Shortcuts:** `openEntry(_ id:)`, `openTag(_ label:)`, `openEditor(_ mode:)` (sets `draft.mode = mode`, `editorMode = mode`), `openSol()`.
- **`showToast(_ text:, undo:)`:** replaces any current toast and auto-dismisses after 4.5 s, using a `Task` keyed on the toast id.
- **`didSave(entryID:)`:** dismisses covers, sets `justSavedID`, resets the draft, and pushes `.entry(id)` on the current tab.

- [ ] **Step 4: RootView and tab bar** (proto L593–601 bar, L603–605 toast)

```swift
// File: Memento/App/RootView.swift
import SwiftUI
import SwiftData
import MementoCore

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system

    var body: some View {
        @Bindable var app = app
        Group {
            if hasOnboarded {
                ZStack(alignment: .bottom) {
                    TabView(selection: $app.tab) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            NavigationStack(path: app.binding(for: tab)) {
                                tabRoot(tab).navigationDestination(for: Route.self, destination: destination)
                            }
                            .toolbarVisibility(.hidden, for: .tabBar)
                            .tag(tab)
                        }
                    }
                    MementoTabBar()
                }
                .ignoresSafeArea(.keyboard)
            } else {
                OnboardingView()
            }
        }
        .overlay(alignment: .bottom) { if let toast = app.toast { ToastView(toast: toast).padding(.horizontal, 16).padding(.bottom, 100) } }
        .sheet(item: $app.sheet) { sheet in sheetView(sheet) }
        .fullScreenCover(item: $app.editorMode) { _ in EditorView() }
        .fullScreenCover(isPresented: $app.isSolPresented) { SolView() }
        .tint(.mTer)
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: scenePhase) { _, phase in if phase == .active { services.ai.refresh(); services.tagging.resumePending() } }
        .task { services.tagging.resumePending() }
    }
    // tabRoot(_:), destination(_:), sheetView(_:) switch over the enums to the feature views (Tasks 14–22).
}
```

`MementoTabBar` follows proto L594–599:
- Height 86 with `.background(.bar)` material in `mBg` at 0.94, and a top 1 pt `mLine` divider.
- Four tab buttons (icons from SF Symbols: `book.closed`, `circle.circle`, `books.vertical`, `person`), each with a 10.5 pt label in `mTer` when active and `mMut` otherwise. Each has identifier `tab.<name>` and the `isSelected` trait.
- A center 46 pt `mTer` circle with "+" (identifier `tab.write`, label "Write") that sets `app.sheet = .write`.
- The bar is only visible in the four tab stacks. That's automatic, because the editor and Sol are full-screen covers and onboarding replaces the root.

**Feature view placeholders.** Until Tasks 14–22 land, every feature view referenced here exists as a one-line stub (`struct JournalView: View { var body: some View { Text("Journal") } }`) in its feature folder, so the shell builds.

- [ ] **Step 5: App entry**

```swift
// File: Memento/App/MementoApp.swift
import SwiftUI

@main
struct MementoApp: App {
    @State private var services = AppServices()
    @State private var app = AppModel()

    init() {
        if LaunchOptions.current.uiTesting { UIView.setAnimationsEnabled(false) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(app)
                .modelContainer(services.container)
        }
    }
}
```

- [ ] **Step 6: UI test for tab switching**

```swift
// add to MementoUITests
func testTabsSwitch() {
    let app = XCUIApplication()
    app.launchArguments = ["-uiTesting", "-seedSampleData", "-skipOnboarding", "-taggingEngine", "demo", "-solEngine", "demo"]
    app.launch()
    for tab in ["discover", "notebooks", "you", "journal"] {
        app.buttons["tab.\(tab)"].tap()
        XCTAssertTrue(app.buttons["tab.\(tab)"].isSelected)
    }
    app.buttons["tab.write"].tap()
    XCTAssertTrue(app.staticTexts["Start writing"].waitForExistence(timeout: 3))
}
```

(The write sheet's title text comes from Task 16. Until then this test step is expected to fail, so add the last two lines in Task 16.)

- [ ] **Step 7: Verify.** Run build and test. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 8: Commit.** `git add Memento MementoUITests && git commit -m "App shell: services, routing, custom tab bar, toast, launch options"`

---

### Task 13: AnnotatedText (tag highlights via TextRenderer)

**Files:**
- Create: `Memento/DesignSystem/AnnotatedText.swift`

**Interfaces:**
- Consumes: `TextSegment`, `QuoteMark` (Task 5), `TagKind.color` / `.tint` (Task 11).
- Produces: `AnnotatedText(segments:activeID:font:lineSpacing:onTap:)`.

- [ ] **Step 1: Implement** (proto `markSt`, L722: suggested = 1.5 pt dashed underline; kept = highlighter on the bottom 38% of the line; active = tint fill plus a 3 pt halo)

```swift
// File: Memento/DesignSystem/AnnotatedText.swift
import SwiftUI
import MementoCore

struct TagMarkAttribute: TextAttribute {
    let kind: TagKind
    let status: TagStatus
    let isActive: Bool
}

struct TagMarkRenderer: TextRenderer {
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if let mark = run[TagMarkAttribute.self] {
                    let bounds = run.typographicBounds
                    let r = bounds.rect
                    if mark.isActive {
                        ctx.fill(Path(roundedRect: r.insetBy(dx: -3, dy: -1), cornerRadius: 3), with: .color(mark.kind.tint))
                    } else if mark.status == .kept {
                        let h = r.height * 0.38
                        ctx.fill(Path(CGRect(x: r.minX, y: r.maxY - h, width: r.width, height: h)), with: .color(mark.kind.tint))
                    } else {
                        var p = Path()
                        let y = bounds.origin.y + max(2, bounds.descent * 0.6)
                        p.move(to: CGPoint(x: r.minX, y: y))
                        p.addLine(to: CGPoint(x: r.maxX, y: y))
                        ctx.stroke(p, with: .color(mark.kind.color), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                ctx.draw(run)
            }
        }
    }
}

/// Entry text with tappable, highlighted quotes. Taps report the tag id.
struct AnnotatedText: View {
    let segments: [TextSegment]
    var activeID: UUID?
    var font: Font = .serif(21, relativeTo: .body)
    var lineSpacing: CGFloat = 8
    var onTap: (UUID) -> Void = { _ in }

    var body: some View {
        segments.reduce(Text(verbatim: "")) { acc, seg in
            guard let mark = seg.mark else { return Text("\(acc)\(Text(verbatim: seg.text))") }
            var s = AttributedString(seg.text)
            s.link = URL(string: "memento://tag/\(mark.id.uuidString)")
            let piece = Text(s).customAttribute(TagMarkAttribute(kind: mark.kind, status: mark.status, isActive: mark.id == activeID))
            return Text("\(acc)\(piece)")
        }
        .font(font)
        .lineSpacing(lineSpacing)
        .foregroundStyle(Color.mInk)
        .tint(Color.mInk)
        .textRenderer(TagMarkRenderer())
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "memento", url.host() == "tag", let id = UUID(uuidString: url.lastPathComponent) { onTap(id) }
            return .handled
        })
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: Preview.** Show the onboarding demo sentence with three marks (suggested, kept, active) in light and dark.
- [ ] **Step 3: Verify.** Build and screenshot the preview through the `-designGallery` root. Check four things: the dashed underline sits under the glyphs, the highlighter covers the lower ~40% of the line, link text stays `mInk` (not tinted), and the active mark shows a filled tint.
  - **Fallback, if links render tinted or `customAttribute` breaks link taps:** replace the link with `.onTapGesture` on the whole text, and map the tap location through `Text.Layout` stored from the renderer via a `PreferenceKey`. Record which approach shipped.
- [ ] **Step 4: Commit and push Phase C.** `git add Memento && git commit -m "AnnotatedText: TextRenderer tag highlights with tappable quotes"`, then build and `&& git push origin app:main`.

---

## Phase D: features

UI tests for Phase D launch with the common arguments:

```swift
let demoArgs = ["-uiTesting", "-seedSampleData", "-skipOnboarding", "-taggingEngine", "demo", "-solEngine", "demo"]
```

**Demo engines count as "ready".** The rule engine and the scripted Sol need no model. `AIStatus` therefore takes `isDemoEngine: () -> Bool` (supplied by `AppServices`, true when `taggingChoice == .demo`). When `demoState == .live`, `isDemoEngine()` is true, and `live != .ready`, `availability` returns `.ready`. This lets UI tests and a backup stage demo run on any simulator. Add this to Task 12's `AIStatus` while implementing Task 14.

### Task 14: Onboarding (4 steps + live demo) (proto L62–173, logic L795–798, L953–960)

**Files:**
- Create: `Memento/Features/Onboarding/OnboardingView.swift`
- Test: `MementoUITests/MementoUITests.swift` → `testOnboardingToJournal`

**Interfaces:**
- Consumes: `RuleTagger`, `TextSegments`, `AnnotatedText`, `AIStatus`, `PaperArt`.
- Produces: sets `SettingsKey.hasOnboarded = true` on finish.

**Behavior and copy:**
- **Step 0.**
  - `PaperArt("onb-hero")`, 320 pt high, radius 28.
  - Eyebrow "MEMENTO" in `mTer`, tracking .16em.
  - Serif 40 "A journal that helps you notice."
  - Body 17 `mMut`: "Write the way you talk to yourself. Memento suggests what’s in there — how you felt, what was hard, what helped — so you can find those moments again."
  - Page dots (active 20×6 `mTer`, others 6×6 `mLine`).
  - Primary button "See how it works" (`onb.primary`).
- **Step 1.**
  - Header: "AN EXAMPLE" with a Skip button (`onb.skip` → step 3), plus `PaperIcon("onb-notice")` at 56 pt top-right.
  - Serif 34 "Write naturally."
  - Card: "Today, 9:12 PM · Daily", then `AnnotatedText` of the demo text: "I felt drained after back-to-back deadlines today.\nA short walk helped me settle." It shows marks only in phase 2.
  - **Phase 0:** outline button "Find the details" (`onb.findDetails`), with "After setup, this happens on your iPhone. Your entry isn’t sent to a server to be tagged."
  - **Phase 1:** a sage dot and "Reading the entry…", lasting 1.5 s (0.4 s with Reduce Motion).
  - **Phase 2:** "MEMENTO NOTICED" with a row per tag. Each row has a chip, the italic quote, and controls:
    - Pending: ✕ (44 pt circle) and "Keep" (`mSageT` pill).
    - Kept: "Kept ✓".
    - Removed: "Undo", with the row at 0.5 opacity.
    - Tapping a row toggles its active highlight.
  - Footer copy: "Suggestions, not facts. Each points to the words behind it — tap one to see them. Keep only what feels true."
  - "Continue" is disabled (`mLine` fill) until phase 2.
- **Step 2.**
  - `PaperIcon("onb-find")` at 56 pt.
  - Serif 34 "…and find that part of your life again."
  - Body "Tap any kept tag to see every moment it appears, across all your notebooks."
  - Card: a kept "Walking helped" chip, with "in 4 entries" if the demo walking tag was kept, else "in 3 earlier entries". Below it, find rows from proto L959 (Today / Tue, Oct 6 / Thu, Sep 24 / Sat, Sep 12 quotes with a `mSageT` highlighter); drop "Today" if the tag wasn't kept.
  - Caption "Memento counts how often you’ve written about something. It won’t tell you what causes what."
- **Step 3.**
  - `PaperArt("onb-private")` at 160 pt.
  - "Private by design." with three sage-dot bullets (proto L142–144, verbatim).
  - AI card, driven by `AIStatus.availability`:
    - `.ready`: "Ready on this iPhone" / "Tagging is set up and works offline."
    - `.needsAppleIntelligence`: "One-time setup" / "Turn on Apple Intelligence in Settings to get on-device suggestions. Nothing is sent to the cloud." with an ink button "Open Settings" that opens `UIApplication.openSettingsURLString`.
    - `.preparing`: "Getting ready…" with an indeterminate sage bar and "Apple Intelligence is downloading its on-device model. You can start writing meanwhile."
    - `.unsupported`: the copy from proto L164–165.
  - Finish button: "Start journaling while it gets ready" (preparing), "Set up later, start journaling" (needs), else "Start journaling".
- **Motion:** with Reduce Motion off, the art fades and rises 8 pt in 0.35 s on step change.

- [ ] **Step 1: Write the failing UI test**

```swift
func testOnboardingToJournal() {
    let app = XCUIApplication()
    app.launchArguments = ["-uiTesting", "-taggingEngine", "demo", "-solEngine", "demo"]
    app.launch()
    app.buttons["onb.primary"].tap()                       // See how it works
    XCTAssertFalse(app.buttons["onb.primary"].isEnabled)    // locked until demo runs
    app.buttons["onb.findDetails"].tap()
    XCTAssertTrue(app.staticTexts["MEMENTO NOTICED"].waitForExistence(timeout: 4))
    app.buttons["Keep Walking helped"].tap()
    XCTAssertTrue(app.staticTexts["Kept ✓"].exists)
    app.buttons["onb.primary"].tap()                        // Continue → step 2
    XCTAssertTrue(app.staticTexts["in 4 entries"].exists)
    app.buttons["onb.primary"].tap()                        // → step 3
    XCTAssertTrue(app.staticTexts["Private by design."].exists)
    app.buttons["onb.primary"].tap()                        // finish
    XCTAssertTrue(app.buttons["tab.journal"].waitForExistence(timeout: 3))
}
```

The Keep buttons carry the accessibility label `"Keep \(label)"`.
- [ ] **Step 2: Run it and confirm it fails.** Run `xcodebuild … test -only-testing:MementoUITests/MementoUITests/testOnboardingToJournal`. Expected: FAIL (stub view).
- [ ] **Step 3: Implement `OnboardingView`** per the behavior above. State: `step`, `demoPhase`, `demoTags: [DemoTag]` (a local struct `{id, draft, status}`) built from `RuleTagger.analyze(demoText)`, and `activeID`.
- [ ] **Step 4: Run the test and confirm it passes.** Then take a screenshot of each step and compare against proto L62–173 rendered in Task 25 (or, for now, read the HTML).
- [ ] **Step 5: Commit.** `git commit -am "Onboarding with live demo tagging"`. Stage new files first.

### Task 15: Journal (proto L175–221, logic L813, L816–824)

**Files:**
- Create: `Memento/Features/Journal/{JournalView,EntryCard}.swift`

**Interfaces:**
- Consumes: `@Query(sort: \Entry.createdAt, order: .reverse) var entries`, `TagIndex`, `Streak`, `JournalInsights`, `DateLabels`, `Excerpt`.
- Produces: `EntryCard(entry:showsMove:onMove:)`, reused by Notebook detail and Discover results.

**Layout:**
1. Eyebrow `DateLabels().longDay(.now)` in uppercase.
2. Serif 36 `greeting()`.
3. Streak row. Serif 34 `mTer` count, then unit 14 `mMut`. On the right, a week strip of seven 30 pt circles:
   - Filled `mTer` with `mOnTer` letter = has entry.
   - Dashed `mTer` = today with no entry.
   - `mLine` = otherwise.
   - Tapping the row pushes `.reminders`.
4. "Tonight" card (`mCard`, radius 24). Contains:
   - `PaperIcon("tonight-ornament")` at 36 pt, top-right.
   - Eyebrow "TONIGHT".
   - Italic serif 24 "What took up the most room in your head today?"
   - Buttons: "Write freely" (`mTer` pill), "Brain dump · 3 min", "Guided". Each calls `app.openEditor(.free/.dump/.guided)`.
5. Pending row, if any: dashed border radius 18, with the `PendingReview.label` and "Review whenever you like. They aren’t counted until kept." Tapping opens the first pending entry.
6. Revisit card, if any: `mSageT` fill, eyebrow "REVISIT" in `mSage`, serif 21 "You’ve written about *walking helped* in 3 entries." (label lowercased, italic), and "See those moments ›". Tapping opens the tag.
7. Eyebrow "RECENT", followed by `EntryCard`s.

**EntryCard:**
- Meta row: "Yesterday · Daily" and the mode title.
- Photo: `Image(uiImage:)` 120 pt, `.fill`, radius 12.
- Excerpt in serif 18.
- Chips: the first three kept chips (small), then "+N", then the dashed "N to review" pill.
- Tapping pushes `.entry(id)`. When `showsMove`, a "Move" capsule button sits top-right.

**Empty journal:** `PaperArt("empty-journal")` at 180 pt, serif 22 "Your first entry can be one sentence.", and a "Write freely" button.

- [ ] **Step 1: Write the UI test (failing)**

```swift
func testJournalShowsSampleState() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    XCTAssertTrue(app.staticTexts["3"].exists)                                    // streak
    XCTAssertTrue(app.staticTexts["2 suggestions waiting in 2 entries"].exists)
    XCTAssertTrue(app.staticTexts["REVISIT"].exists)
}
```

- [ ] **Step 2: Implement.** Run the test and confirm it passes.
- [ ] **Step 3: Screenshot check.** Compare against proto L175–221 in light and dark: streak dots, Tonight card, revisit card colors.
- [ ] **Step 4: Commit.** `"Journal: streak, tonight prompt, review queue, revisit, recent entries"`

### Task 16: Write sheet + Editor (proto L612–624, L223–267, logic L766–773, L877–892)

**Files:**
- Create: `Memento/Features/Write/{WriteSheet,EditorView,BrainDumpTimer}.swift`
- Create: `Memento/Services/{PhotoProcessing,CameraPicker,DictationService}.swift`

**Interfaces:**
- Consumes: `AppModel.draft`, `AppModel.didSave(entryID:)`, `TaggingCoordinator.enqueue`.
- Produces:
  - `GuidedPrompts.categories` (`gratitude`, `day`, `mind`, with prompts from proto L713)
  - `EditorExamples.text(for:)` (proto L714)
  - `DictationService` (`@Observable`: `isAvailable`, `isListening`, `start(onText:)`, `stop()`)
  - `PhotoProcessing.jpegData(from: UIImage) -> Data` (max 2048 px, quality 0.85)

**Write sheet:**
- Background `mSheet`, `.presentationDetents([.fraction(0.78), .large])`, corner radius 28.
- Title serif 26 "Start writing" with a Cancel button.
- Four mode rows, each in a `mCard` with radius 18 and padding 14:
  - `PaperIcon("mode-<mode>")` at 40 pt.
  - Title 16.5/600 and description 14 `mMut`, taken from proto L940.
  - Identifier `write.mode.<mode>`.
- Dashed "Reflect with Sol" row with `PaperIcon("sol-mark")` and "Talk it through, then save a reflection. Optional." Tapping it closes the sheet and runs `app.openSol()`.

**Editor (full screen):**
- **Top bar:** "Cancel" (dismisses, keeps the draft); the notebook chip "Daily ▾", which opens `.pickNotebook` (a sheet presented from the editor cover); "Save" (`editor.save`, 17/700, disabled when the text is empty and there's no photo).
- **Segmented pill:** Free · Brain dump · Guided · Photo. Switching keeps the text.
- **Brain dump:**
  - `BrainDumpTimer` shows mono 34 "3:00" and a toggle labeled Start / Pause / Resume / Again.
  - A 4 pt progress bar in `mTer`.
  - Notes from proto L882.
  - The timer is driven by a `Task` loop with one-second sleeps.
- **Guided:** a sticky card with category `FilterChip`s, an italic serif 21 prompt, and "Another prompt".
- **Photo:**
  - With no photo, a dashed 170 pt box holds "Camera" (only if `UIImagePickerController.isSourceTypeAvailable(.camera)`) and a `PhotosPicker` "Photo library".
  - With a photo, it shows at 210 pt with "Replace".
- **Text field:** `TextEditor` in serif 21 with line spacing 12, a `mBg` background with hidden scroll background, the placeholder from proto L888, and identifier `editor.text`.
- **Dictation:** "Listening… speak naturally." banner while dictating.
- **Bottom bar:**
  - "Speak". Shown only if `DictationService.isAvailable`, which requires `SFSpeechRecognizer(locale: en-US)?.supportsOnDeviceRecognition == true`.
  - "Use example" (`editor.example`), which fills `EditorExamples.text(for: mode)`.
  - Word count.
- **Save:**
  - Create an `Entry` with `notebookID: draft.notebookID`, `mode`, `prompt` (guided only), `text`, `photoData`, `tagging: .pending`.
  - Insert it and `try context.save()`. On failure, show the inline error "Couldn’t save — your words are still here." and keep the draft.
  - Then run `services.tagging.enqueue(entry)` and `app.didSave(entryID:)`.

- [ ] **Step 1: Write the UI test (failing)**

```swift
func testWriteSaveShowsSuggestions() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    app.buttons["tab.write"].tap()
    XCTAssertTrue(app.staticTexts["Start writing"].waitForExistence(timeout: 3))
    app.buttons["write.mode.free"].tap()
    app.buttons["editor.example"].tap()
    app.buttons["editor.save"].tap()
    XCTAssertTrue(app.staticTexts["Saved ✓"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Finding details on this iPhone…"].exists)
    XCTAssertTrue(app.buttons["Keep Drained"].waitForExistence(timeout: 6))
}
```

- [ ] **Step 2: Implement.** Run it and confirm it passes. This depends on the Task 17 entry detail, so implement Task 17's running and suggestion sections before running this test.
- [ ] **Step 3: Manual check of all four modes in the simulator.** Timer counts down. The Guided prompt cycles. Photo library picking works. Switching modes keeps the text.
- [ ] **Step 4: Commit.** `"Write sheet and editor: free, brain dump, guided, photo, dictation"`

### Task 17: Entry detail + tag form + move (proto L269–314, L626–641, logic L753–759, L783–786, L839–848)

**Files:**
- Create: `Memento/Features/Entry/{EntryDetailView,TagFormSheet,MoveSheet}.swift`

**Interfaces:**
- Consumes: `TaggingCoordinator.phase(for:)` / `.retry`, `TagIndex`, `TextSegments`, `AnnotatedText`, `AppModel.showToast`.
- Produces: `EntryActions`, with static functions used by views and tests:
  - `keep(_ tag:)`
  - `remove(_ tag:, app:)`, which shows the toast with Undo restoring the previous status
  - `keepAll(_ entry:, app:)`, which shows "Kept N tags" with Undo
  - `move(_ entry:, to:, app:)`, which shows "Moved to Work" with Undo

**Layout:**
- **Nav bar:** system back button. Toolbar trailing has the "Saved ✓" pill (if `app.justSavedID == id`; cleared on disappear) and "Move".
- **Header:** meta line "Yesterday, 11:52 PM · Daily · Write freely", the guided prompt (italic), the photo, then `AnnotatedText` (active = `activeID`).
- **Details section:** serif 22 "Details" with "+ Add a tag" (`.addTag(id)`). Below that, one phase card:
  - `.running`: sage dot, "Finding details on this iPhone…", and "Your entry is already saved. You can leave — suggestions will be waiting."
  - `.failed`: "Couldn’t finish finding details." with the proto L287 copy and an ink "Try again" button.
  - `.none`: the dashed card from proto L288.
  - `.unavailable` / `.off`: proto L289 copy with "Set up on-device AI ›", which pushes `.onDeviceAI`.
  - `.unsupported`: proto L290.
- **Suggestions:** "SUGGESTED · N" with "Keep all" in `mSage`. Each row has:
  - a chip (tap → edit sheet), the kind name 12 `mMut`, and the italic quote;
  - ✕ (label "Remove \(label)") and "Keep" (label "Keep \(label)").
  - Tapping the row toggles `activeID`.
- **Kept:** "KEPT" with "Edit" / "Done". Kept chips carry a count · n when n > 1. Tapping a chip opens the tag (or the edit sheet in edit mode). Hint text from proto L847.
- **Footer:** caption from proto L311.

**Tag form sheet:**
- Cancel / title ("Edit tag" or "Add a tag") / Save or Add.
- Label field.
- KIND segmented control (`TagKind.shortLabel`).
- "BASED ON YOUR WORDS" quote card (edit mode only).
- "YOUR TAGS" quick picks in add mode: the top eight kept labels not already on the entry.
- "Remove tag" in `mDanger` (edit mode only).
- Caption from proto L633.
- **Save in edit mode:** sets the label and kind, `status = .kept`, `isEdited = true`.
- **Add mode:** `entry.addTag(label:kind:status: .kept, isManual: true)`.

**Move sheet:** "Move to notebook" (or "Save to notebook" for the editor picker). Rows are a cover swatch (22×28, radius 2/5/5/2), the name, and a ✓ on the current notebook.

- [ ] **Step 1: Write the UI test (failing)**

```swift
func testKeepRemoveUndoAndOpenTag() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    app.staticTexts["2 suggestions waiting in 2 entries"].tap()
    XCTAssertTrue(app.buttons["Keep Restless"].waitForExistence(timeout: 3))
    app.buttons["Remove Restless"].tap()
    XCTAssertTrue(app.staticTexts["Removed “Restless”"].waitForExistence(timeout: 2))
    app.buttons["toast.undo"].tap()
    XCTAssertTrue(app.buttons["Keep Restless"].waitForExistence(timeout: 2))
    app.buttons["Keep Restless"].tap()
    app.buttons["kept.Restless"].tap()
    XCTAssertTrue(app.staticTexts["Restless"].waitForExistence(timeout: 2))     // tag detail title
}
```

- [ ] **Step 2: Implement.** Run it and confirm it passes, then run `testWriteSaveShowsSuggestions` (Task 16) and confirm it passes too.
- [ ] **Step 3: Commit.** `"Entry detail: annotated text, suggestions, keep/remove/undo, tag form, move"`

### Task 18: Tag detail + Discover (proto L316–370, logic L850–868)

**Files:**
- Create: `Memento/Features/Tag/TagDetailView.swift`, `Memento/Features/Discover/DiscoverView.swift`

**Tag detail:**
- **Header:**
  - `PaperIcon(kind.emblem)` at 28 pt.
  - Eyebrow with the kind's plural in `kind.color`.
  - Serif 40 label.
  - Meta "Mentioned in 3 entries · 2 notebooks · Sep 12 – Oct 6".
- **Timeline:**
  - Spans whole months from the first entry's month to the last (at least two; if both fall in one month, the previous month is added).
  - A 1 pt `mLine` axis, with dividers between months.
  - A 12 pt dot per entry in `kind.color` with a 2 pt `mBg` ring.
  - Month names below, spaced around.
- **Entry cards:** date and notebook, with the quote in serif 19 and a `kind.tint` 40% highlighter (or the excerpt if there's no quote).
- **"Also kept in these entries":** chips for co-occurring labels with n ≥ 2, top 5, shown as "Conflict in 2".
- **Caveat:** proto L342.
- **Summarize:** outline-ink button "Summarize these N entries", which pushes `.summary(SummarySeed(ids:))`.
- **Empty:** "No entries have this tag right now."

**Discover:**
- **Header:** serif 36 "Discover", then a search field (`mLine` fill, radius 12, height 44), then the basis line "From X of your Y entries with kept tags. Numbers show how many entries mention each."
- **Pending row:** shown when there are pending suggestions.
- **Groups:** four, each with `PaperIcon(kind.emblem)` at 24 pt, serif 23 name, an "N tags" count, and kept chips with counts. Groups with no tags are hidden. Chips are filtered by the query.
- **Results:** when the query is at least 2 characters, "Entries mentioning “q”" followed by `EntryCard`s.
- **"Make a summary" card:** pushes `.summary(SummarySeed(ids: nil))`.
- **Empty state** (no kept tags): `PaperArt("empty-discover")` with "Tags you keep will gather here."

- [ ] **Step 1: Write the UI test (failing)**

```swift
func testDiscoverToTagToSummary() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    app.buttons["tab.discover"].tap()
    app.buttons["chip.Walking helped"].tap()
    XCTAssertTrue(app.staticTexts["Mentioned in 3 entries · 2 notebooks · Sep 12 – Oct 6"].exists || app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Mentioned in 3 entries'")).firstMatch.exists)
    app.buttons["Summarize these 3 entries"].tap()
    XCTAssertTrue(app.staticTexts["New summary"].waitForExistence(timeout: 2))
}
```

The date range depends on the run date, so the test asserts the prefix. Discover chips carry the identifier `chip.<label>`.
- [ ] **Step 2: Implement.** Run the test and confirm it passes.
- [ ] **Step 3: Commit.** `"Tag detail with timeline and co-occurrence; Discover groups and search"`

### Task 19: Notebooks grid + notebook detail (proto L372–404, logic L870–876)

**Files:**
- Create: `Memento/Features/Notebooks/{NotebooksView,NotebookDetailView}.swift`

**Notebooks grid:**
- Serif 36 "Notebooks", then "4 notebooks · N entries".
- A two-column grid (spacing 22/18) of `NotebookCover(showsLabel: true)`, each with the name 15/600 and "N entries" 13 `mMut`.
- Tapping a cover pushes `.notebook(id)`.

**Notebook detail:**
- **Header band:** the cover asset at 160 pt, `.fill`. A frosted "‹ Notebooks" capsule is hidden because the system back button is used. The label plate with serif 22 name is centered.
- **Body:**
  - The count "8 entries · 3 tagged Walking helped".
  - A search field "Search this notebook" that matches entry text or kept labels.
  - Horizontally scrolling `FilterChip`s: "All" plus every kept label in the notebook (in first-seen order).
  - `EntryCard(showsMove: true)`.
  - Empty: `PaperArt("empty-search")` at 140 pt with "No entries match. Try another tag or search."

- [ ] **Step 1: Write the UI test**

```swift
func testNotebookFilterAndMove() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    app.buttons["tab.notebooks"].tap()
    app.buttons["notebook.daily"].tap()
    app.buttons["filter.Walking helped"].tap()
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'tagged Walking helped'")).firstMatch.exists)
    app.buttons["Move"].firstMatch.tap()
    app.buttons["notebook.option.work"].tap()
    XCTAssertTrue(app.staticTexts["Moved to Work"].waitForExistence(timeout: 2))
}
```

- [ ] **Step 2: Implement.** Run the test and confirm it passes.
- [ ] **Step 3: Commit.** `"Notebooks grid with generated covers; notebook detail with search, filters, move"`

### Task 20: You, Reminders, On-device AI, Demo (proto L406–490, logic L927–933)

**Files:**
- Create: `Memento/Features/You/{YouView,RemindersView,OnDeviceAIView,DemoSection}.swift`
- Create: `Memento/Services/{ReminderScheduler,PDFComposer}.swift`. `PDFComposer` is shared with Task 22; the journal export lives here.

**Interfaces:**
- Produces:
  - `ReminderScheduler.setEnabled(_ on: Bool, minutes: Int) async -> Bool`, which returns false if permission is denied. It uses a repeating `UNCalendarNotificationTrigger` with id `memento.daily`, title "Memento", and body "A few lines tonight? Even one sentence counts."
  - `PDFComposer.render(_ attributed: NSAttributedString) -> Data`: US Letter (612×792), 54 pt margins, `CTFramesetter` pagination.
  - `PDFComposer.journal(entries:) -> NSAttributedString` and `PDFComposer.summary(_ doc: SummaryDocument) -> NSAttributedString`.
  - `PDFComposer.write(_ data:, name:) -> URL`, which writes into `FileManager.default.temporaryDirectory`.

**You screen:**
- Serif 36 "You".
- Streak card: `mTerT` fill with `PaperIcon("streak-sprout")` at 44 pt, serif 24 `mTer` "3-day streak", and the copy from proto L409.
- **Group 1:** Daily reminder (value: time or "Off") → `.reminders`; Summaries → `.summary(nil)`; Reflect with Sol → `app.openSol()`.
- **Group 2:**
  - On-device AI (value: Ready / Not set up / Getting ready / Not available) → `.onDeviceAI`.
  - Appearance: a `Picker` (System / Light / Dark) in the menu style.
  - Export journal: a `ShareLink`. The PDF is generated lazily when the row appears and named "Memento – journal export.pdf".
  - Replay welcome: sets `hasOnboarded = false`.
- **Group 3: `DemoSection`** (eyebrow "DEMO"):
  - Load sample journal: `SampleJournal.load`, then the toast "Loaded 8 sample entries".
  - Clear journal: a destructive `confirmationDialog` "Delete every entry on this iPhone?", then `SampleJournal.clear`.
  - AI state: a `Picker` over `DemoAIState`, titled "Live" / "Not set up" / "Getting ready" / "Unsupported" / "Tagging fails".
  - Suggestion engine: On-device model / Built-in rules (backup).
  - Sol engine: On-device model / Scripted (backup).
  - Changing an engine writes `SettingsKey.demo*` and calls `services.rebuildTaggingEngine()`.

**Reminders screen** (proto L429–458):
- The "Remind me to write" toggle (`SageToggleStyle`). On enable, it calls `ReminderScheduler.setEnabled(true, minutes:)`. If that returns false, the toggle reverts and the caption reads "Notifications are off for Memento. Turn them on in Settings to get a gentle nudge."
- A `DatePicker(.hourAndMinute)` and preset `FilterChip`s 8:00 AM / 12:30 PM / 8:30 PM / 10:00 PM.
- A PREVIEW lock-screen card:
  - Background `PaperArt("reminder-scene")`, or the gradient #CDBFA8→#9C8C74 if the asset is missing.
  - A light 52 pt clock and a notification pill (`mCard` at 0.82) showing the app icon at 38 pt (from the `AppIconPreview` image set, a copy of the icon), "Memento", "now", and the body text.
  - Opacity 0.35 when off.
- Caption and "How streaks work" copy from proto L453–455.

**On-device AI screen** (proto L460–490, mapped per spec §5.1):
- State card:
  - READY · WORKS OFFLINE
  - TURN ON APPLE INTELLIGENCE (with an Open Settings button)
  - GETTING READY (with an indeterminate bar)
  - NOT AVAILABLE ON THIS IPHONE (with `PaperArt("ai-unavailable")` at 120 pt)
- If supported, the toggles "Suggest tags after saving" ("Feelings, situations, what helped, topics") and "Sol conversations" ("Early — quality varies by device"), plus the row "On-device model · Managed by Apple Intelligence".
- "What happens to your writing" with two paragraphs. The first is proto L485 verbatim. The second is proto L486 with "exporting a summary PDF" kept.

- [ ] **Step 1: Write the UI test**

```swift
func testYouDemoControlsAndAIStates() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    app.buttons["tab.you"].tap()
    XCTAssertTrue(app.staticTexts["3-day streak"].exists)
    app.buttons["row.onDeviceAI"].tap()
    XCTAssertTrue(app.staticTexts["READY · WORKS OFFLINE"].exists)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.buttons["demo.aiState"].tap(); app.buttons["Unsupported"].tap()
    app.buttons["row.onDeviceAI"].tap()
    XCTAssertTrue(app.staticTexts["NOT AVAILABLE ON THIS IPHONE"].exists)
}
```

- [ ] **Step 2: Implement.** Run the test and confirm it passes. Manual: the reminder fires in the simulator when set two minutes ahead (check with `xcrun simctl` or by waiting). The exported journal PDF opens in the share sheet preview and has more than one page with the sample data.
- [ ] **Step 3: Commit.** `"You: reminders, on-device AI states, appearance, export, demo controls"`

### Task 21: Sol + Sol draft + Support card (proto L492–536, logic L774–780, L893–902)

**Files:**
- Create: `Memento/Features/Sol/{SolView,SolDraftView,SupportCard}.swift`

**Interfaces:**
- Consumes: `SolConversation`, `AppServices.makeSolEngine()`, `AIStatus`, `SettingsKey.solEnabled`, `TaggingCoordinator.enqueue`, `AppModel.didSave`.

**Sol screen** (a full-screen cover with its own `NavigationStack` for the draft):
- **Header:** "Close" on the left (resets the conversation and dismisses); center serif 19 "Sol" with 11 pt "On this iPhone · not saved unless you choose" and `PaperIcon("sol-mark")` at 22 pt; a 1 pt bottom divider.
- **Gate:** shown when not ready, or when Sol is off. Uses the titles, bodies and CTAs from proto L896–898, mapped as follows:
  - unsupported → "Try Guided reflection" opens the editor in guided mode.
  - Otherwise → "Open On-device AI", which dismisses the cover, selects You, and pushes `.onDeviceAI`.
  - Shows `PaperArt("ai-unavailable")` at 140 pt.
- **Open state:**
  - Disclaimer card (proto L507).
  - Messages:
    - Sol messages are serif 20 `mInk`, max width 88%, with a `PaperIcon("sol-mark")` at 20 pt before the first line of each Sol message.
    - The writer's messages are 16 pt bubbles in `mTerT` with radius 20/20/6/20, max width 78%, trailing.
    - `.support` messages render `SupportCard`: a `mCard` box with the message, a "Call or text 988" button (`tel:988`) shown only when `Locale.current.region == .unitedStates`, and "Find a helpline" linking to `https://findahelpline.com`. Tapping that link is the one network action, and it's user-initiated in Safari.
  - "Sol is thinking…" in italic 14 `mMut` while `isAwaitingFirstToken` (identifier `sol.thinking`).
  - "Turn this into a reflection" in `mTer`, 52 pt, when `canMakeReflection` (`sol.makeReflection`).
  - Quick-reply chips from `suggestions`.
  - Input "Reply to Sol…" (`sol.input`) with "Send" (`sol.send`), disabled when `!canSend` or the input is empty.
  - When `reachedCap`, the input is replaced by "That’s a good place to pause. Turn this into a reflection to keep what matters."
  - Auto-scrolls to the bottom with `ScrollViewReader` on the message count and the last text.
- **Make reflection:** shows "Drafting on this iPhone…" while running `engine.draftReflection(from: conversation.userMessages)`. On error it falls back to `ReflectionTemplate.make`. Then it pushes `SolDraftView`.
- **Prewarm:** `conversation.prewarm()` in `.task`.

**Sol draft:**
- "Back" and "Save to journal".
- Serif 32 "Your reflection" and the proto L531 copy.
- A `TextEditor` in a `mCard`, radius 18, serif 20.
- "Discard conversation" in `mMut`, which resets, dismisses, and selects the You tab.
- **Save:** creates an Entry (`notebookID: "refl"`, `mode: .sol`), enqueues tagging, dismisses the cover, and runs `app.didSave`.

- [ ] **Step 1: Write the UI test (the streaming-returns-to-idle check from the global CLAUDE.md rule)**

```swift
func testSolStreamsAndReturnsToIdle() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    app.buttons["tab.you"].tap()
    app.buttons["row.sol"].tap()
    let input = app.textFields["sol.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 3))
    input.tap(); input.typeText("The launch date at work")
    app.buttons["sol.send"].tap()
    XCTAssertTrue(app.staticTexts["sol.thinking"].waitForExistence(timeout: 1))
    let reply = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'That sounds like a lot'")).firstMatch
    XCTAssertTrue(reply.waitForExistence(timeout: 6))
    let idle = NSPredicate(format: "exists == false")
    expectation(for: idle, evaluatedWith: app.staticTexts["sol.thinking"])
    waitForExpectations(timeout: 6)
    XCTAssertTrue(app.buttons["sol.makeReflection"].isEnabled)
    app.buttons["sol.makeReflection"].tap()
    XCTAssertTrue(app.staticTexts["Your reflection"].waitForExistence(timeout: 4))
    app.buttons["Save to journal"].tap()
    XCTAssertTrue(app.staticTexts["Saved ✓"].waitForExistence(timeout: 3))
}
```

UI tests disable animations, so `ScriptedSol` streaming still takes about 0.7 s of thinking plus 25 ms per word, which is enough for the assertions above.

- [ ] **Step 2: Implement.** Run the test and confirm it passes.
- [ ] **Step 3: Commit.** `"Sol: streaming on-device conversation, reflection draft, support card"`

### Task 21b: Sol character (D27)

**Files:**
- Create: `Packages/MementoCore/Sources/MementoCore/AI/SolCharacter.swift`
- Test: `Packages/MementoCore/Tests/MementoCoreTests/SolCharacterTests.swift`
- Modify: `SolConversation` (opening and copy come from `SolCharacter`), `FoundationModelSol` (persona comes from `SolCharacter.persona`), `SolView` (state-driven `sol-*` art)

**Interfaces:**
- Produces:
  - `SolCharacter.opening(at:calendar:)`, with morning, afternoon, evening and late-night variants
  - `SolCharacter.openingSuggestions(at:calendar:)`
  - `SolCharacter.persona`, which includes three few-shot exchanges
  - `SolCharacter.fallbackReply`, `SolCharacter.windDown`, `SolCharacter.drafting`
  - `SolMood {hello, listening, thinking, speaking, reflect, resting}` and `SolMood.asset`
  - `SolConversation(engine:now:)` exposing `mood`

**Steps:**
1. Write failing tests for: the time-of-day openings; the persona containing the voice rules and examples; and `mood` transitions (hello → thinking while awaiting the first token → speaking → listening while the input is non-empty → resting at the cap).
2. Implement.
3. In `SolView`:
   - The header avatar shows `mood.asset`, with a slow 8 s rotation for `.thinking` unless Reduce Motion is on.
   - An empty conversation shows `sol-hello` at 120 pt above the greeting.
   - The draft screen shows `sol-reflect`.
   - The gate and the cap note show `sol-resting`.
4. Re-run the real-model Sol integration test and read two replies to confirm the voice.
5. Commit.

### Task 22: Summary builder, preview, PDF export (proto L538–583, logic L903–925)

**Files:**
- Create: `Memento/Features/Summary/{SummaryView,SummaryPreview}.swift`

**Interfaces:**
- Consumes: `SummaryComposer`, `SummaryOptions`, `PDFComposer.summary`, `PDFComposer.write`, `SettingsKey.preparedBy`.

**Step 0 (build):**
- Serif 34 "New summary".
- Purpose cards "For me" and "For my psychologist or psychiatrist", each with the proto copy. The selected one has a 2 pt `mTer` border.
- "Entries" with an "N selected" count.
- Preset `FilterChip`s: "Last 2 weeks" (createdAt ≥ today − 14 days), "All entries", the top two kept labels by count, and "Clear".
- An entry list with 24 pt checkmarks (`mTer` fill when selected), each row showing "date · first three kept tags" (or "No kept tags") and the excerpt.
- Toggles: "Include my original words" ("Short quotes behind each tag") and "Only tags I’ve kept · Always".
- Clinician only:
  - The note field "ANYTHING YOU WANT TO RAISE? (OPTIONAL)" with the proto placeholder.
  - "PREPARED BY (OPTIONAL)", a text field bound to `@AppStorage(SettingsKey.preparedBy)`.
- "Preview summary" (`summary.preview`, disabled when nothing is selected).
- The initial selection comes from `SummarySeed.ids`, or the last two weeks if nil.

**Step 1 (preview):**
- "Preview" with "PDF · N page(s)", computed from the rendered PDF's page count.
- A paper card (`#FFFDF8`, radius 6, the two shadows from proto L570) that renders the `SummaryDocument` exactly as in proto L571–576.
- "Nothing is shared until you choose where it goes."
- A `ShareLink(item: url, preview: SharePreview(name))` styled as the terracotta "Export PDF…" button. The file is named "Memento – a look back.pdf" or "Memento – appointment summary.pdf".
- The back button reads "Edit selection".

- [ ] **Step 1: Write the UI test**

```swift
func testSummaryPreview() {
    let app = XCUIApplication(); app.launchArguments = demoArgs; app.launch()
    app.buttons["tab.discover"].tap()
    app.buttons["Make a summary"].tap()
    XCTAssertTrue(app.staticTexts["5 selected"].waitForExistence(timeout: 2))
    app.buttons["purpose.clinician"].tap()
    app.buttons["summary.preview"].tap()
    XCTAssertTrue(app.staticTexts["Journal summary for my appointment"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Export PDF…"].exists)
}
```

- [ ] **Step 2: Implement.** Run all UI tests and confirm they pass: `xcodebuild … test`. Expected: `** TEST SUCCEEDED **` with every test from Tasks 12–22.
- [ ] **Step 3: Commit and push Phase D**

```bash
git add Memento MementoUITests && git commit -m "Summary: selection, deterministic preview, PDF export via share sheet"
xcodebuild -project Memento.xcodeproj -scheme Memento -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DD test 2>&1 | tail -3 | grep -q "TEST SUCCEEDED" && git push origin app:main
```

---

## Phase E: assets, visual QA, ship

### Task 23: Review Wave 1, then dispatch Wave 2 (runs whenever Wave 1's `worker_done` arrives)

**Files:**
- Modify: `design-assets/RUN.md` (record verdicts)

- [ ] **Step 1: Validate the settlement.** Check that the `worker_done` matches the Wave 1 dispatch ID and that the outcome is `succeeded`. If it's `failed`, read the summary. If the cause is "image generation unavailable", stop the image track and report it to the user, since the app ships with `PaperArt` placeholders. Otherwise, follow the recovery reference before any retry.
- [ ] **Step 2: Inspect every image.**
  - View each PNG with the Read tool.
  - Run `sips -g pixelWidth -g pixelHeight -g hasAlpha design-assets/generated/*.png`.
  - Accept only if all of these hold: no text or letters, the palette matches STYLE.md, the subject sits inside the central ~70%, the paper-cut medium is visible, and (for `sol-mark`) it's still readable when downscaled to 40 pt. Check that last one with `sips -Z 80 … --out /tmp-in-scratchpad/…` and view the result.
  - Record "accepted" or "rejected: reason" per asset in `RUN.md`.
- [ ] **Step 3: Re-dispatch rejects.** Run `orca orchestration worker-start --spec "<wave1 brief restricted to the rejected assets + reviewer notes>" --task-title "Wave 1 redo" --worktree current --agent codex --json`. At most two redo rounds per asset. After that, keep the best version or fall back to the placeholder.
- [ ] **Step 4: Release the settled Wave 1 worker.** Run `orca orchestration worker-release --dispatch <id> --json`, then acknowledge the delivery.
- [ ] **Step 5: Dispatch Wave 2 in parallel.**

```bash
for w in wave2a wave2b wave2c; do
  orca orchestration worker-start --spec "$(cat design-assets/briefs/$w.md)" --task-title "Assets $w" --worktree current --agent codex --json
done
```

Then run `orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json` in the background again. Review each Wave 2 worker with Steps 2–4 as it settles. Before ending the session, `worker-list --run <run_id> --terminal-state reclaimable --json` must return none.

### Task 24: Import accepted assets into the app

**Files:**
- Create: `Memento/Resources/Assets.xcassets/Art/<name>.imageset/{<name>.png, Contents.json}`, one per accepted asset
- Modify: `Memento/Resources/Assets.xcassets/AppIcon.appiconset/` (add `app-icon.png`) and add an `AppIconPreview.imageset` (a copy for the Reminders preview)
- Create: `design-assets/accepted/` (processed copies, committed)

- [ ] **Step 1: Process the images with sips** (sizes from spec §8)

```bash
cd design-assets && mkdir -p accepted && \
for f in onb-hero onb-private onb-notice onb-find empty-journal empty-discover empty-search ai-unavailable; do sips -Z 768 generated/$f.png --out accepted/$f.png; done && \
for f in sol-mark mode-free mode-dump mode-guided mode-photo kind-feeling kind-situation kind-helped kind-topic streak-sprout tonight-ornament; do sips -Z 256 generated/$f.png --out accepted/$f.png; done && \
for f in cover-daily cover-work cover-gratitude cover-reflections reminder-scene; do sips -z 1152 768 generated/$f.png --out accepted/$f.png; done && \
sips -Z 1536 generated/sample-ceramics.png --out accepted/sample-ceramics.png && \
sips -Z 512 generated/paper-grain.png --out accepted/paper-grain.png && \
sips -s format jpeg generated/app-icon.png --out /tmp/claude-icon.jpg && sips -s format png -z 1024 1024 /tmp/claude-icon.jpg --out accepted/app-icon.png && \
sips -g hasAlpha accepted/app-icon.png
```

Expected: `hasAlpha: no` for the app icon. Skip any asset that wasn't accepted. The `/tmp` path above must be the session scratchpad when this runs.

- [ ] **Step 2: Write the image sets.** A script writes one `Contents.json` per asset: `{"images":[{"filename":"<name>.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}`. The AppIcon set's single entry gets `"filename":"app-icon.png"`.
- [ ] **Step 3: Paper grain (only if it tiles cleanly).**
  - Tile `paper-grain` 3×3 with a scratchpad script, view the result, and look for seams.
  - If it's clean, add to `Screen` and the `paperCard` modifier: `.background { Image("paper-grain").resizable(resizingMode: .tile).opacity(0.25).blendMode(.multiply) }` in light mode, and `0.08` with `.screen` in dark.
  - If seams show, drop the asset and note that in `RUN.md`.
- [ ] **Step 4: Verify.** Build, run all UI tests, then screenshot onboarding, write sheet, notebooks, Discover, Sol gate, Reminders, and You. Confirm that every placeholder has been replaced and that the art sits in cream cards in dark mode (spec D19).
- [ ] **Step 5: Commit and push**

```bash
git add Memento/Resources design-assets/accepted design-assets/RUN.md && git commit -m "Add Codex-generated paper-cut asset kit and app icon" && \
xcodebuild -project Memento.xcodeproj -scheme Memento -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DD build 2>&1 | grep -q "BUILD SUCCEEDED" && git push origin app:main
```

### Task 25: Visual QA against the prototype

**Files:**
- Create: `MementoUITests/ScreenshotTour.swift`
- Create (scratchpad only): the Playwright reference script

- [ ] **Step 1: Reference renders of the prototype.**
  - In a scratchpad folder, run `npm init -y && npm i playwright@1.55.0`.
  - Serve `design-reference/` with `python3 -m http.server`.
  - Load `Memento Prototype.dc.html` at a 1280×1000 viewport.
  - For each "Jump to a screen" button (proto L950: Onboarding, Journal, Write sheet, Editor, Entry + suggestions, Tag detail, Discover, Notebooks, Notebook detail, Sol, Summary, Reminders, On-device AI), click it and screenshot the 414×868 phone frame element.
  - Repeat with the Tweaks set to dark if the runtime exposes them. Otherwise light only.
  - Save to `scratchpad/ref/<screen>.png`.
- [ ] **Step 2: App screenshot tour.** `ScreenshotTour.testTour` launches with `demoArgs`, visits the same 13 screens, and attaches `XCUIScreen.main.screenshot()` with `lifetime = .keepAlways` and name `<screen>-<light|dark|axl>`. It runs three times:
  1. default appearance;
  2. `-AppleInterfaceStyle Dark`;
  3. `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`.

  Export the attachments with `xcrun xcresulttool export attachments --path <xcresult> --output-path scratchpad/app/`.
- [ ] **Step 3: Compare side by side.** View the reference and app images in pairs. For each screen, list the discrepancies in hierarchy, spacing, colors, copy, and states, and fix them. Discrepancies that are deliberate under spec decisions D2, D8, D12, D13, D15, D26 stay, and are listed in the final report.
  - **Accessibility XL:** no truncated primary actions, nothing clipped horizontally, and the stacks reflow (the Journal streak row stacks vertically, and the write buttons wrap).
- [ ] **Step 4: Commit.** `git add MementoUITests Memento && git commit -m "Visual QA fixes against prototype; screenshot tour"`

### Task 26: Real on-device AI check, README, demo script, final review

**Files:**
- Create: `README.md`, `docs/demo-script.md`

- [ ] **Step 1: Real Foundation Models check.**
  - On this Mac, run `cd Packages/MementoCore && swift test --filter FoundationModelIntegrationTests` and record whether it ran or was skipped.
  - Launch the app in the simulator with no engine overrides (`-skipOnboarding -seedSampleData` only). Check the On-device AI screen's state.
  - If it says READY, write a new entry with "Use example", save, and confirm that suggestions arrive from the real model with valid highlights. Then chat with Sol for two turns.
  - If the simulator reports "not set up" or "unavailable", record that verbatim as a blocker for simulator verification and note that the physical-iPhone check is in the demo script. Don't retry more than twice.
- [ ] **Step 2: README.** It covers:
  - What Memento is (the three-line pitch from the prototype aside).
  - Screenshots: four from the tour, copied to `docs/screens/` at 50% scale.
  - The privacy model: on-device, no network.
  - Requirements: Xcode 26, iOS 26, an iPhone with Apple Intelligence for live AI, and the demo engines for everything else.
  - Run steps: open `Memento.xcodeproj`, set the team, choose a device, Run.
  - Architecture: the app target, the MementoCore package, and the Foundation Models usage, with file links.
  - How the art was made: Codex image generation orchestrated through Orca, the style bible, and the prompts in `design-assets/briefs`.
  - Tests: `swift test` and the `xcodebuild test` commands.
  - Credits: Newsreader and JetBrains Mono under SIL OFL.
- [ ] **Step 3: Demo script** (`docs/demo-script.md`, spec §11). This is the 3-minute flow, the pre-demo checklist, and the backup plan: if the device's AI misbehaves on stage, switch Demo → Suggestion engine and Sol engine to the backups. It's word-for-word what to tap and what to say.
- [ ] **Step 4: Final verification gate.** All of the following must succeed:

```bash
cd Packages/MementoCore && swift test && cd ../.. && \
xcodebuild -project Memento.xcodeproj -scheme Memento -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DD test 2>&1 | tail -3 && \
xcodebuild -project Memento.xcodeproj -scheme Memento -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/DDR CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -2
```

Expected: tests pass, then `** TEST SUCCEEDED **`, then `** BUILD SUCCEEDED **` for the device Release build.
- [ ] **Step 5: Whole-branch review.** Dispatch one fresh reviewer on the most capable model over `git diff bea71b7..HEAD`. Its focus: the Review Focus list, concurrency (MainActor and Sendable), and SwiftData misuse. Apply confirmed fixes and re-run Step 4.
- [ ] **Step 6: Commit and push**

```bash
git add README.md docs && git commit -m "README, demo script, and final verification" && git push origin app:main
gh repo view Kands221/memento --json url,visibility
```

- [ ] **Step 7: Close out orchestration.** `orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json` must return none. Release any worker still settled.

---

## Self-review (completed while writing)

- **Spec coverage:**
  - §1 → Tasks 14–22, 25
  - D1–D2 → 8, 12, 20
  - D3–D7 → 2
  - D8 → 12
  - D9 → 2, 11
  - D10, D23 → 10, 20
  - D11 → 14
  - D12 → 15, 9
  - D13 → 20
  - D14 → 7, 22
  - D15 → 20, 22
  - D16 → 16
  - D17, D22 → 9, 21
  - D18, D26 → 1, 23, 24
  - D19 → 11, 24
  - D20 → 19
  - D21, D24 → 2, 26
  - D25 → done (repo created), 26
  - §5.1 → 8, 12, 20
  - §5.2 → 6, 8, 17
  - §5.3 → 9, 21
  - §6 rows → 14–22
  - §7 → 11, 13
  - §8 → 1, 23, 24
  - §9 → 16 (save error), 20 (notification denial), 16 (photo downscale), 22 (PDF failure via toast in `PDFComposer.write` catch)
  - §10 → tests in 3–22, 25, 26
  - §11 → 26
- **Placeholders:** UI markup values are specified by prototype line reference by design, as stated at the top of Phase C. There are no TBDs.
- **Type consistency:** these names are checked across tasks: `TaggingCoordinator.phase(for:)`, `enqueue`, `retry`, `resumePending`, `drain`, `engine`; `SolConversation.send/reset/prewarm/canMakeReflection/isAwaitingFirstToken`; `SummaryOptions(purpose:includeQuotes:note:preparedBy:today:)`; `EngineChoice {onDevice, demo}`; `DemoAIState`; `Route`; `ActiveSheet`.
