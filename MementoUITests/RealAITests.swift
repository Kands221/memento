import XCTest

/// End-to-end checks against Apple's on-device model (no demo engines). Skips where Apple Intelligence is off.
@MainActor
final class RealAITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchLive() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData", "-skipOnboarding"]
        app.launch()
        app.buttons["tab.you"].tap()
        let row = app.buttons["row.onDeviceAI"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        try XCTSkipUnless(row.label.hasSuffix("Ready"), "Apple Intelligence not ready here: \(row.label)")
        return app
    }

    func testLiveTaggingSuggestsGroundedTags() throws {
        let app = try launchLive()
        app.buttons["tab.write"].tap()
        app.buttons["write.mode.free"].tap()
        XCTAssertTrue(app.buttons["editor.example"].waitForExistence(timeout: 3))
        app.buttons["editor.example"].tap()
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Saved ✓"].waitForExistence(timeout: 3))
        let keep = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Keep '")).firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 90), "No on-device suggestions arrived")
        let labels = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Keep '")).allElementsBoundByIndex.map(\.label)
        print("LIVE-TAGS:", labels)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "live-tagging"; shot.lifetime = .keepAlways; add(shot)
    }

    func testLiveSolReplies() throws {
        let app = try launchLive()
        app.buttons["row.sol"].tap()
        let input = app.textFields["sol.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        input.typeText("Work has been a lot and I keep saying yes to everything")
        app.buttons["sol.send"].tap()
        XCTAssertTrue(app.buttons["sol.makeReflection"].waitForExistence(timeout: 60), "Sol never finished replying")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "live-sol"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertFalse(app.staticTexts["sol.thinking"].exists)
    }
}
