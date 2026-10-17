import XCTest

final class PhysicalCaptureFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testCountdownCancellationShortTakeAndBackgroundRecovery() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the paired physical iPhone camera and microphone")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID().uuidString)"]
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["createScriptTile"].waitForExistence(timeout: 10))
        app.buttons["createScriptTile"].tap()
        app.textViews["scriptText"].tap()
        app.textViews["scriptText"].typeText(String(repeating: "P3B camera check. Keep speaking at your own pace.\n", count: 12))
        app.openRehearsal()
        let modes = app.segmentedControls.firstMatch
        XCTAssertTrue(modes.buttons["Camera"].waitForExistence(timeout: 5))
        modes.buttons["Camera"].tap()
        let record = app.buttons["recordTake"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
        record.tap()
        let stop = app.buttons["stopRecording"]
        XCTAssertTrue(stop.waitForExistence(timeout: 3))
        stop.tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.isEnabled)

        record.tap()
        let state = app.descendants(matching: .any).matching(identifier: "captureState").firstMatch
        let recording = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Recording'"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [recording], timeout: 10), .completed)
        waitOnClock(seconds: 8)
        stop.tap()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Take saved.'"), object: app.staticTexts["statusMessage"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 20), .completed)
        XCTAssertTrue(record.isEnabled)

        record.tap()
        let secondRecording = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Recording'"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [secondRecording], timeout: 10), .completed)
        waitOnClock(seconds: 8)
        XCUIDevice.shared.press(.home)
        waitOnClock(seconds: 2)
        XCTAssertNotEqual(app.state, .runningForeground)
        app.activate()
        let recovered = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH 'Take saved.' AND label CONTAINS 'inactive'"),
            object: app.staticTexts["statusMessage"])
        XCTAssertEqual(XCTWaiter.wait(for: [recovered], timeout: 20), .completed)
        XCTAssertFalse(record.isEnabled)
        let controls = app.scrollViews.firstMatch
        for _ in 0..<3 where !app.buttons["Retry Camera"].isHittable { controls.swipeUp() }
        XCTAssertTrue(app.buttons["Retry Camera"].isHittable)
        app.buttons["Retry Camera"].tap()
        let reentered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [reentered], timeout: 20), .completed)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        #endif
    }

    @MainActor private func waitOnClock(seconds: Double) {
        let elapsed = expectation(description: "Physical capture local clock")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { elapsed.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [elapsed], timeout: seconds + 5), .completed)
    }
}
