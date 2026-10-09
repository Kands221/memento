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

    /// Eight messages through the real app UI on the live on-device model (the Mac's Apple Intelligence in the simulator).
    func testLiveSolEightMessages() throws {
        let app = try launchLive()
        app.buttons["row.sol"].tap()
        let input = app.textFields["sol.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        let solRows = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Sol: '"))
        let script = ["hi", "Work has been chaotic this week", "My manager keeps moving the launch deadline",
                      "I stayed late three nights in a row", "Honestly I'm exhausted and a bit resentful",
                      "A walk at lunch today helped a little", "I think I need to say no more often",
                      "Maybe I'll block my calendar on Friday afternoons"]
        let scripted = ["Deadlines have a way", "Ah, the fear of letting people down", "Would you like to turn this into a reflection you can keep?"]
        var transcript: [String] = []
        for (i, text) in script.enumerated() {
            let before = solRows.count
            input.tap()
            input.typeText(text)
            app.buttons["sol.send"].tap()
            let more = expectation(for: NSPredicate(format: "count > %d", before), evaluatedWith: solRows)
            wait(for: [more], timeout: 60)
            let idle = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["sol.thinking"])
            wait(for: [idle], timeout: 60)
            Thread.sleep(forTimeInterval: 1.5) // let the stream finish its last tokens
            let reply = String(solRows.element(boundBy: solRows.count - 1).label.dropFirst(5))
            transcript.append("TURN \(i + 1) ME: \(text)\n         SOL: \(reply)")
            XCTAssertFalse(scripted.contains { reply.hasPrefix($0) }, "turn \(i + 1) used the scripted engine")
            XCTAssertFalse(reply.hasPrefix("Forgive me, I lost the thread"), "turn \(i + 1) fell back")
            XCTAssertTrue(app.buttons["sol.send"].exists, "turn \(i + 1) composer missing")
        }
        print("APP-TRANSCRIPT\n" + transcript.joined(separator: "\n"))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "live-sol-8"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(app.buttons["sol.makeReflection"].exists)
    }
}
