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
}
