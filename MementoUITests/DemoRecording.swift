import XCTest

/// Scripted scenes for the demo video, recorded from the iOS Simulator with live on-device AI
/// (`marketing/memento-demo/record.sh`). Skipped unless MEMENTO_DEMO=1. Each scene prints SCENE_START and
/// SCENE_END with wall-clock times so the recording can be trimmed to the moment.
@MainActor
final class DemoRecording: XCTestCase {
    static let spoken = "Work stress is back this week. What helped me last time?"
    static let spokenNext = "Maybe I will text Priya and we can walk after work tomorrow."

    override func setUp() { continueAfterFailure = false }

    func launch() throws -> XCUIApplication {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MEMENTO_DEMO"] == "1", "Run through marketing/memento-demo/record.sh")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData", "-skipOnboarding", "-demoRecording", "-liveSummary",
                               "-demoSpeech", Self.spoken + " | " + Self.spokenNext]
        app.launch()
        XCTAssertTrue(app.buttons["tab.journal"].waitForExistence(timeout: 10))
        return app
    }

    func mark(_ what: String) { print("\(what) \(Date().timeIntervalSince1970)") }
    func hold(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    /// Taps until `result` appears: a tap that lands while a list is still gliding only stops the scroll.
    func tap(_ element: XCUIElement, until results: XCUIElement..., timeout: Double = 2.5) {
        for _ in 0..<3 {
            element.tap()
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if results.contains(where: \.exists) { return }
                hold(0.1)
            }
        }
        XCTFail("\(element) didn't lead to \(results)")
    }

    /// Scrolls until the element sits fully above the tab bar (iOS still calls it hittable when it's underneath).
    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let visible = CGRect(x: window.minX, y: window.minY + 60, width: window.width, height: window.height - 60 - 120)
        var tries = 0
        while !(element.exists && visible.contains(element.frame)) && tries < 6 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        hold(1.2)
    }

    func type(_ text: String, into field: XCUIElement) {
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            field.typeText(String(word) + " ")
            hold(0.06)
        }
    }

    func testScene1Journal() throws {
        let app = try launch()
        hold(1.0)
        mark("SCENE_START")
        hold(2.5)
        app.swipeUp()
        hold(1.6)
        mark("SCENE_END")
    }

    func testScene2Write() throws {
        let app = try launch()
        hold(0.8)
        mark("SCENE_START")
        app.buttons["tab.write"].tap()
        XCTAssertTrue(app.buttons["write.mode.free"].waitForExistence(timeout: 5))
        hold(0.6)
        app.buttons["write.mode.free"].tap()
        let editor = app.textViews["editor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        type("Stayed late again to finish the deck and felt drained by the time I got home. A walk with Priya after dinner helped me reset.", into: editor)
        hold(0.6)
        app.buttons["editor.save"].tap()
        mark("SAVED")
        let keep = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Keep '")).firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 40), "No on-device suggestions arrived")
        mark("TAGS")
        hold(2.2)
        let walking = app.buttons["Keep Walking helped"]
        (walking.exists ? walking : keep).tap()
        mark("KEPT")
        hold(2.0)
        mark("SCENE_END")
    }

    func testScene3FindAgain() throws {
        let app = try launch()
        app.buttons["tab.discover"].tap()
        XCTAssertTrue(app.buttons["chip.Walking helped"].waitForExistence(timeout: 5))
        hold(0.8)
        mark("SCENE_START")
        hold(0.8)
        app.buttons["chip.Walking helped"].tap()
        hold(2.4)
        app.swipeUp()
        hold(1.6)
        mark("SCENE_END")
    }

    func testScene4Sol() throws {
        let app = try launch()
        app.buttons["tab.you"].tap()
        app.buttons["row.sol"].tap()
        XCTAssertTrue(app.buttons["sol.mic"].waitForExistence(timeout: 5))
        hold(1.0)
        mark("SCENE_START")
        hold(1.8)
        app.buttons["sol.mic"].tap()
        mark("LISTENING")
        let input = app.textFields["sol.input"]
        let heard = expectation(for: NSPredicate(format: "value CONTAINS 'last time?'"), evaluatedWith: input)
        wait(for: [heard], timeout: 20)
        hold(0.5)
        app.buttons["Stop and send"].tap()
        mark("SENT")
        let idle = expectation(for: NSPredicate(format: "value == 'Ready'"), evaluatedWith: app.buttons["sol.send"])
        wait(for: [idle], timeout: 60)
        mark("REPLIED")
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Sol: '"))
        print("SOL_REPLY: \(rows.element(boundBy: rows.count - 1).label.dropFirst(5))")
        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'From your journal'")).firstMatch
        print("SOL_CITED: \(chip.exists ? chip.label : "none")")
        hold(3.0)
        app.buttons["sol.mic"].tap()
        mark("LISTENING2")
        let heardNext = expectation(for: NSPredicate(format: "value CONTAINS 'tomorrow'"), evaluatedWith: input)
        wait(for: [heardNext], timeout: 20)
        hold(0.5)
        app.buttons["Stop and send"].tap()
        mark("SENT2")
        let idleAgain = expectation(for: NSPredicate(format: "value == 'Ready'"), evaluatedWith: app.buttons["sol.send"])
        wait(for: [idleAgain], timeout: 60)
        mark("REPLIED2")
        print("SOL_REPLY2: \(rows.element(boundBy: rows.count - 1).label.dropFirst(5))")
        hold(3.0)
        let drafting = app.staticTexts["Gathering your words…"]
        let draft = app.staticTexts["Your reflection"]
        tap(app.buttons["sol.makeReflection"], until: drafting, draft, timeout: 3)
        mark("REFLECTING")
        XCTAssertTrue(draft.waitForExistence(timeout: 30))
        mark("REFLECTION")
        hold(3.0)
        app.buttons["Save to journal"].tap()
        XCTAssertTrue(app.staticTexts["Saved ✓"].waitForExistence(timeout: 5))
        hold(1.2)
        mark("SCENE_END")
    }

    func testScene5Summary() throws {
        let app = try launch()
        app.buttons["tab.discover"].tap()
        let summary = app.buttons["discover.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        hold(0.8)
        mark("SCENE_START")
        reveal(summary, in: app)
        let preview = app.buttons["summary.preview"]
        tap(summary, until: app.staticTexts["New summary"])
        hold(1.6)
        reveal(preview, in: app)
        tap(preview, until: app.buttons["Export PDF…"], timeout: 4)
        mark("DRAFTING")
        let credit = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Drafted by Sol'")).firstMatch
        XCTAssertTrue(credit.waitForExistence(timeout: 40), "No look-back paragraph")
        mark("DRAFTED")
        hold(3.5)
        mark("SCENE_END")
    }
}
