import XCTest

final class TakeLibraryFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private let firstID = "3231FD8A-2B93-4D0E-AB79-24A3CE000001"
    private let recoveredID = "3231FD8A-2B93-4D0E-AB79-24A3CE000003"
    private let incompleteID = "3231FD8A-2B93-4D0E-AB79-24A3CE000004"
    private let missingID = "3231FD8A-2B93-4D0E-AB79-24A3CE000005"

    @MainActor func testGroupingPlaybackConfirmedDeletionAndRelaunch() throws {
        let app = launchFixtures()
        let first = app.buttons["video_\(firstID)"]
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        settle(1)
        capture("P3C Grouped Library Portrait")
        first.tap()
        XCTAssertTrue(app.buttons["closeTake"].waitForExistence(timeout: 5))
        app.otherElements["originalVideoPlayer"].tap()
        let transport = app.buttons["Play/Pause"]
        XCTAssertTrue(transport.waitForExistence(timeout: 2))
        XCTAssertEqual(transport.label, "Pause")
        capture("P3C Original Playback")
        app.buttons["closeTake"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.press(forDuration: 1)
        app.buttons["Delete Original"].tap()
        XCTAssertTrue(app.staticTexts["Delete original recording?"].waitForExistence(timeout: 5))
        capture("P3C Delete Confirmation")
        // iOS 27 presents this as a native popover, dismissed by tapping outside.
        app.staticTexts["한국어 Lesson (sample)"].tap()
        XCTAssertFalse(app.staticTexts["Delete original recording?"].exists)
        XCTAssertTrue(first.exists)
        first.press(forDuration: 1)
        app.buttons["Delete Original"].tap()
        app.buttons["Delete Original"].tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: first)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 10), .completed)
        app.terminate()
        app.launchSkippingIntroduction()
        app.buttons["videosTab"].tap()
        XCTAssertTrue(app.buttons["video_\(recoveredID)"].waitForExistence(timeout: 10))
        XCTAssertFalse(first.exists)
    }

    @MainActor func testRecoveryStatesAndLandscapeLibrary() throws {
        let app = launchFixtures()
        XCTAssertTrue(app.buttons["video_\(firstID)"].waitForExistence(timeout: 15))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Café Update\n")
        let recovered = app.buttons["video_\(recoveredID)"]
        XCTAssertTrue(recovered.waitForExistence(timeout: 5))
        XCTAssertTrue(recovered.label.contains("Recovered recording"))
        let incomplete = app.descendants(matching: .any).matching(identifier: "video_\(incompleteID)").firstMatch
        let missing = app.descendants(matching: .any).matching(identifier: "video_\(missingID)").firstMatch
        XCTAssertTrue(incomplete.label.contains("Incomplete original retained"))
        XCTAssertTrue(missing.label.contains("Original file missing"))
        settle(1)
        capture("P3C Recovery States")
        recovered.tap()
        XCTAssertTrue(app.buttons["closeTake"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(2)
        capture("P3C Playback Landscape")
        XCTAssertTrue(app.buttons["closeTake"].isHittable)
        app.buttons["closeTake"].tap()
        XCUIDevice.shared.orientation = .portrait
        settle(1)
        app.buttons["Close"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        settle(3)
        capture("P3C Library Landscape")
        XCTAssertTrue(app.buttons["refreshTakes"].isHittable)
    }

    @MainActor func testEmptyLibraryAndAccessibleRowPlayback() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())"]
        app.launchSkippingIntroduction()
        app.buttons["videosTab"].tap()
        XCTAssertTrue(app.staticTexts["No recordings yet"].waitForExistence(timeout: 10))
        settle(1)
        capture("P3C Empty Library")
        app.terminate()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p3c-stage-take-fixtures"]
        app.launchSkippingIntroduction()
        app.buttons["videosTab"].tap()
        let row = app.buttons["video_\(firstID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        settle(1)
        capture("P3C Appearance Library")
        row.tap()
        XCTAssertTrue(app.buttons["closeTake"].waitForExistence(timeout: 5))
        settle(1)
        capture("P3C Appearance Playback")
        app.buttons["closeTake"].tap()
    }

    @MainActor private func launchFixtures() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p3c-stage-take-fixtures"]
        app.launchSkippingIntroduction()
        app.buttons["videosTab"].tap()
        return app
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func settle(_ seconds: Double) {
        let settled = expectation(description: "Native take screen settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: seconds + 3), .completed)
    }
}
