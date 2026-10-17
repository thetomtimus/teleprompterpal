import XCTest

/// Explicit opt-in scheme; never part of the routine Simulator test scheme.
final class CameraTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    @MainActor func test01ShortFrontCaptureAndMP4Export() throws {
        try requirePhysicalDevice()
        let app = launchCamera()
        record(app, seconds: 15)
        exportLatest(app)
    }

    @MainActor func test02CameraAndOrientationMatrix() throws {
        try requirePhysicalDevice()
        let app = launchCamera()
        for side in ["Front", "Rear"] {
            for orientation in ["portrait", "landscapeLeft", "landscapeRight"] {
                app.buttons["Camera and orientation"].tap()
                app.buttons[side].tap()
                waitUntilRecordEnabled(app)
                app.buttons["Camera and orientation"].tap()
                app.buttons[orientation].tap()
                record(app, seconds: 5)
            }
        }
        exportLatest(app)
    }

    @MainActor func test03BackgroundAndTerminationRecovery() throws {
        try requirePhysicalDevice()
        let app = launchCamera()
        beginRecording(app)
        waitForTimer(app, seconds: 5)
        XCUIDevice.shared.press(.home)
        // Require a real background transition before bringing the app forward.
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        waitForSavedTake(app)
        app.buttons["Camera"].tap()
        waitUntilRecordEnabled(app)
        beginRecording(app)
        waitForTimer(app, seconds: 8)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["sampleTake"].waitForExistence(timeout: 15))
        // Recovery truth is also inspected from the durable journal; unfinished MOV is not promised.
        XCTAssertFalse(app.buttons["stopRecording"].exists)
    }

    @MainActor func test04TenMinuteFrontCaptureWithContinuousPrompt() throws {
        try requirePhysicalDevice()
        let app = launchCamera()
        beginRecording(app)
        XCTAssertTrue(app.buttons["togglePrompt"].label.contains("Pause"))
        // The app has no duration ceiling. This legacy acceptance test ends its own take.
        waitForTimer(app, seconds: 600)
        app.buttons["stopRecording"].tap()
        waitForSavedTake(app, timeout: 50)
        XCTAssertFalse(app.buttons["stopRecording"].exists)
        XCTAssertTrue(app.buttons["recordTake"].isEnabled)
        exportLatest(app)
    }

    @MainActor private func launchCamera() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--p1-long-script"]
        app.launch()
        XCTAssertTrue(app.buttons["Camera"].waitForExistence(timeout: 15))
        app.buttons["Camera"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 3) {
                let text = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
                XCTAssertTrue(
                    text.contains("Record a video while reading your script") || text.contains("Include your voice"),
                    text)
                let allow = alert.buttons["Allow"].exists ? alert.buttons["Allow"] : alert.buttons["OK"]
                XCTAssertTrue(allow.exists)
                allow.tap()
            }
        }
        waitUntilRecordEnabled(app)
        return app
    }

    @MainActor private func waitUntilRecordEnabled(_ app: XCUIApplication) {
        let button = app.buttons["recordTake"]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 20), .completed,
            app.staticTexts["statusMessage"].exists ? app.staticTexts["statusMessage"].label : "Camera not ready")
    }

    @MainActor private func beginRecording(_ app: XCUIApplication) {
        app.buttons["recordTake"].tap()
        XCTAssertTrue(app.staticTexts["recordingTimer"].waitForExistence(timeout: 15))
    }

    @MainActor private func waitForTimer(_ app: XCUIApplication, seconds: Int) {
        // Frequent accessibility queries of the long UITextView can take seconds on device.
        // Once capture's start indicator exists, wait on the test process's clock instead.
        XCTAssertTrue(app.staticTexts["recordingTimer"].exists)
        let elapsed = expectation(description: "At least \(seconds) seconds of camera capture")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(seconds)) { elapsed.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [elapsed], timeout: Double(seconds + 5)), .completed)
    }

    @MainActor private func record(_ app: XCUIApplication, seconds: Int) {
        beginRecording(app)
        waitForTimer(app, seconds: seconds)
        app.buttons["stopRecording"].tap()
        waitForSavedTake(app)
    }

    @MainActor private func waitForSavedTake(_ app: XCUIApplication, timeout: Double = 30) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label IN %@", ["Take saved.", "Playable interrupted take preserved."]),
            object: app.staticTexts["statusMessage"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    @MainActor private func exportLatest(_ app: XCUIApplication) {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'take_'")).firstMatch.tap()
        let export = app.buttons["exportMP4"]
        XCTAssertTrue(export.waitForExistence(timeout: 15))
        app.segmentedControls["cropPicker"].buttons["1:1"].tap()
        app.sliders["trimStart"].adjust(toNormalizedSliderPosition: 0.1)
        export.tap()
        XCTAssertTrue(app.buttons["shareMP4"].waitForExistence(timeout: 300))
        app.buttons["Done"].tap()
    }

    private func requirePhysicalDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("The physical camera scheme requires a real iPhone.")
        #endif
    }
}
