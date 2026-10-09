import XCTest

/// Visits the primary screens and attaches screenshots (Task 25 visual QA, README images).
@MainActor
final class ScreenshotTour: XCTestCase {
    private var variant = "light"

    override func setUp() { continueAfterFailure = true }

    func testTourLight() { tour(extra: [], name: "light") }
    func testTourDark() { tour(extra: ["-appearance", "dark"], name: "dark") }
    func testTourLargeText() { tour(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"], name: "axl") }

    private func shot(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = "\(name)-\(variant)"
        a.lifetime = .keepAlways
        add(a)
    }

    private func back(_ app: XCUIApplication) { app.navigationBars.buttons.firstMatch.tap() }

    private func tour(extra: [String], name: String) {
        variant = name
        let onboarding = XCUIApplication()
        onboarding.launchArguments = ["-uiTesting", "-taggingEngine", "demo", "-solEngine", "demo"] + extra
        onboarding.launch()
        shot(onboarding, "01-onboarding")
        onboarding.buttons["onb.primary"].tap()
        onboarding.buttons["onb.findDetails"].tap()
        _ = onboarding.staticTexts["MEMENTO NOTICED"].waitForExistence(timeout: 4)
        shot(onboarding, "02-onboarding-demo")
        onboarding.terminate()

        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData", "-skipOnboarding", "-taggingEngine", "demo", "-solEngine", "demo"] + extra
        app.launch()
        shot(app, "03-journal")
        app.buttons["tab.write"].tap()
        _ = app.staticTexts["Start writing"].waitForExistence(timeout: 3)
        shot(app, "04-write-sheet")
        app.buttons["write.mode.guided"].tap()
        _ = app.buttons["editor.example"].waitForExistence(timeout: 3)
        shot(app, "05-editor-guided")
        app.buttons["Cancel"].firstMatch.tap()
        app.staticTexts["2 suggestions waiting in 2 entries"].tap()
        _ = app.buttons["Keep Restless"].waitForExistence(timeout: 3)
        shot(app, "06-entry")
        app.swipeUp()
        if app.buttons["kept.Conflict"].waitForExistence(timeout: 2) { app.buttons["kept.Conflict"].tap() }
        _ = app.staticTexts["tag.title"].waitForExistence(timeout: 3)
        shot(app, "07-tag")
        app.buttons["tab.discover"].tap()
        shot(app, "08-discover")
        app.buttons["tab.notebooks"].tap()
        shot(app, "09-notebooks")
        app.buttons["notebook.daily"].tap()
        shot(app, "10-notebook")
        app.buttons["tab.you"].tap()
        shot(app, "11-you")
        app.buttons["row.reminders"].tap()
        shot(app, "12-reminders")
        back(app)
        app.buttons["row.onDeviceAI"].tap()
        shot(app, "13-ai")
        back(app)
        app.buttons["row.sol"].tap()
        _ = app.textFields["sol.input"].waitForExistence(timeout: 3)
        shot(app, "14-sol")
        app.buttons["Close"].tap()
        app.buttons["tab.discover"].tap()
        app.swipeUp(); app.swipeUp()
        app.buttons["discover.summary"].tap()
        _ = app.staticTexts["New summary"].waitForExistence(timeout: 3)
        shot(app, "15-summary")
        app.swipeUp(); app.swipeUp()
        app.buttons["summary.preview"].tap()
        _ = app.staticTexts["Preview"].waitForExistence(timeout: 3)
        shot(app, "16-summary-preview")
    }
}
