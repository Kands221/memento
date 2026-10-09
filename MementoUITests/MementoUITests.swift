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

    func testJournalShowsSampleState() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["journal.streak"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["journal.streak"].label, "3")
        XCTAssertTrue(app.staticTexts["2 suggestions waiting in 2 entries"].exists)
        XCTAssertTrue(app.staticTexts["REVISIT"].exists)
    }

    func testWriteSaveShowsSuggestions() {
        let app = launch()
        app.buttons["tab.write"].tap()
        XCTAssertTrue(app.staticTexts["Start writing"].waitForExistence(timeout: 3))
        app.buttons["write.mode.free"].tap()
        XCTAssertTrue(app.buttons["editor.example"].waitForExistence(timeout: 3))
        app.buttons["editor.example"].tap()
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Saved ✓"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Finding details on this iPhone…"].exists)
        XCTAssertTrue(app.buttons["Keep Drained"].waitForExistence(timeout: 6))
    }

    func testKeepRemoveUndo() {
        let app = launch()
        app.staticTexts["2 suggestions waiting in 2 entries"].tap()
        XCTAssertTrue(app.buttons["Keep Restless"].waitForExistence(timeout: 3))
        app.buttons["Remove Restless"].tap()
        XCTAssertTrue(app.staticTexts["Removed “Restless”"].waitForExistence(timeout: 2))
        app.buttons["toast.undo"].tap()
        XCTAssertTrue(app.buttons["Keep Restless"].waitForExistence(timeout: 2))
        app.buttons["Keep Restless"].tap()
        XCTAssertTrue(app.buttons["kept.Restless"].waitForExistence(timeout: 2))
    }
}
