import XCTest

@MainActor
final class MementoUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    let demoArgs = ["-uiTesting", "-seedSampleData", "-skipOnboarding", "-taggingEngine", "demo", "-solEngine", "demo"]

    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = demoArgs + extra
        app.launch()
        return app
    }

    func testTabsSwitch() {
        let app = launch()
        for tab in ["discover", "notebooks", "you", "journal"] {
            app.buttons["tab.\(tab)"].tap()
            XCTAssertTrue(app.buttons["tab.\(tab)"].isSelected, tab)
        }
    }

    func testLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testOnboardingToJournal() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-taggingEngine", "demo", "-solEngine", "demo"]
        app.launch()
        app.buttons["onb.primary"].tap()                       // See how it works
        XCTAssertFalse(app.buttons["onb.primary"].isEnabled)    // locked until the demo runs
        app.buttons["onb.findDetails"].tap()
        XCTAssertTrue(app.staticTexts["MEMENTO NOTICED"].waitForExistence(timeout: 4))
        app.buttons["Keep Walking helped"].tap()
        XCTAssertTrue(app.staticTexts["Kept ✓"].exists)
        app.buttons["onb.primary"].tap()                        // Continue → find again
        XCTAssertTrue(app.staticTexts["in 4 entries"].exists)
        app.buttons["onb.primary"].tap()                        // → private by design
        XCTAssertTrue(app.staticTexts["Private by design."].exists)
        app.buttons["onb.primary"].tap()                        // finish
        XCTAssertTrue(app.buttons["tab.journal"].waitForExistence(timeout: 3))
    }
}
