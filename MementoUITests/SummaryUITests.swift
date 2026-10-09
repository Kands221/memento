import XCTest

/// Summaries with Sol's look-back: in UI tests (no -liveSummary) the paragraph stays deterministic.
@MainActor
final class SummaryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Scrolls until the element sits fully on screen above the custom tab bar (as in MementoUITests).
    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let visible = CGRect(x: window.minX, y: window.minY + 60, width: window.width, height: window.height - 60 - 110)
        var tries = 0
        while !(element.exists && visible.contains(element.frame)) && tries < 6 {
            app.swipeUp()
            tries += 1
        }
    }

    func testLookBackToggleHiddenAndPreviewDeterministicInUITests() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData", "-skipOnboarding", "-taggingEngine", "demo", "-solEngine", "demo"]
        app.launch()
        app.buttons["tab.discover"].tap()
        let summary = app.buttons["discover.summary"]
        reveal(summary, in: app)
        summary.tap()
        XCTAssertTrue(app.staticTexts["5 selected"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["summary.lookBack"].exists)
        let preview = app.buttons["summary.preview"]
        reveal(preview, in: app)
        preview.tap()
        XCTAssertTrue(app.staticTexts["A look back"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["summary.editLookBack"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Across 5 entries'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Export PDF…"].exists)
    }

    /// Live, on Apple's on-device model: Sol drafts the look-back, it's labelled, and it can be edited. Needs MEMENTO_LIVE_SUMMARY=1.
    func testLiveLookBackDraftsLabelsAndEdits() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MEMENTO_LIVE_SUMMARY"] == "1", "Live model test")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData", "-skipOnboarding", "-taggingEngine", "demo", "-liveSummary"]
        app.launch()
        app.buttons["tab.discover"].tap()
        let summary = app.buttons["discover.summary"]
        reveal(summary, in: app)
        summary.tap()
        let toggle = app.descendants(matching: .any)["summary.lookBack"]
        try XCTSkipUnless(toggle.waitForExistence(timeout: 3), "On-device model isn't ready here")
        let preview = app.buttons["summary.preview"]
        reveal(preview, in: app)
        preview.tap()
        XCTAssertTrue(app.staticTexts["A look back"].waitForExistence(timeout: 40))
        let edit = app.buttons["summary.editLookBack"]
        XCTAssertTrue(edit.exists, "Sol's draft didn't pass the checks (deterministic paragraph shown)")
        XCTAssertTrue(app.staticTexts[SolCredit.text].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "live-look-back"; shot.lifetime = .keepAlways; add(shot)
        let tappable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: edit)
        wait(for: [tappable], timeout: 5)
        edit.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText(" Edited by me.")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Edited by me.'")).firstMatch.waitForExistence(timeout: 3))
    }
}

enum SolCredit {
    static let text = "Sol drafted this paragraph on this iPhone from your kept tags."
}
