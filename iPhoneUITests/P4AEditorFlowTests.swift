import XCTest

final class P4AEditorFlowTests: XCTestCase {
    private let firstID = "3231FD8A-2B93-4D0E-AB79-24A3CE000001"
    override func setUp() { continueAfterFailure = false }

    @MainActor func testSavedTrimSurvivesCancelAndRelaunch() throws {
        let app = launch()
        openEditor(app)
        trim(app, startFraction: 0.2, endFraction: 0.8)
        let start = app.staticTexts["trimStartValue"].label
        let end = app.staticTexts["trimEndValue"].label
        XCTAssertNotEqual(start, "0:00.00")
        XCTAssertNotEqual(end, "0:03.00")
        app.sliders["editorPlayhead"].adjust(toNormalizedSliderPosition: 0.5)
        let playhead = app.staticTexts["editorPlayheadTime"].label
        XCTAssertNotEqual(playhead, start)
        XCTAssertNotEqual(playhead, end)
        capture("P4A Trim Portrait Light")
        app.buttons["playTrimSelection"].tap()
        XCUIDevice.shared.orientation = .landscapeRight
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Play selection"),
                                                object: app.buttons["playTrimSelection"])
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 8), .completed)
        capture("P4A Trim Landscape Right")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["saveVideoEdit"].tap()
        XCTAssertTrue(app.buttons["editVideo"].waitForExistence(timeout: 5))
        app.buttons["editVideo"].tap()
        waitReady(app)
        XCTAssertEqual(app.staticTexts["trimStartValue"].label, start)
        XCTAssertEqual(app.staticTexts["trimEndValue"].label, end)
        trim(app, startFraction: 0.1, endFraction: 0.9)
        app.buttons["cancelVideoEdit"].tap()
        XCTAssertTrue(app.buttons["editVideo"].waitForExistence(timeout: 5))
        app.terminate(); app.launchSkippingIntroduction()
        openEditor(app)
        XCTAssertEqual(app.staticTexts["trimStartValue"].label, start)
        XCTAssertEqual(app.staticTexts["trimEndValue"].label, end)
        capture("P4A Saved Trim Relaunch")
    }

    @MainActor func testLandscapeResetAndAccessibleDarkEditor() throws {
        let app = launch()
        openEditor(app, takeID: "3231FD8A-2B93-4D0E-AB79-24A3CE000002")
        trim(app, startFraction: 0.2, endFraction: 0.8)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["resetVideoEdit"].waitForExistence(timeout: 5))
        app.buttons["resetVideoEdit"].tap()
        waitReady(app)
        XCTAssertEqual(app.staticTexts["trimStartValue"].label, "0:00.00")
        XCTAssertEqual(app.staticTexts["trimEndValue"].label, "0:03.00")
        let playbackControls = app.scrollViews.containing(.button, identifier: "playTrimSelection").firstMatch
        for _ in 0..<3 where !app.buttons["playTrimSelection"].isHittable { playbackControls.swipeUp() }
        capture("P4A Trim Landscape Light")
        XCTAssertTrue(app.buttons["playTrimSelection"].isHittable)
        app.buttons["playTrimSelection"].tap()
        let ended = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Play selection"),
                                              object: app.buttons["playTrimSelection"])
        let playbackResult = XCTWaiter.wait(for: [ended], timeout: 8)
        let playbackPosition = app.staticTexts["editorPlayheadTime"].label
        let playbackControl = app.buttons["playTrimSelection"].label
        print("P4A reset playback: result=\(playbackResult.rawValue), position=\(playbackPosition), control=\(playbackControl)")
        app.buttons["cancelVideoEdit"].tap()
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        var arguments = app.launchArguments
        if let style = arguments.firstIndex(of: "-AppleInterfaceStyle") { arguments[style + 1] = "Dark" }
        app.launchArguments = arguments + ["--p4a-dark-appearance", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchSkippingIntroduction()
        openEditor(app)
        capture("P4A Trim Portrait Dark Large")
        XCTAssertTrue(app.buttons["saveVideoEdit"].isHittable)
        XCTAssertTrue(app.buttons["cancelVideoEdit"].isHittable)
        let later = app.buttons["trimEndEarlier"]
        for _ in 0..<4 where !later.isHittable { app.swipeUp() }
        XCTAssertTrue(later.isHittable)
        XCTAssertGreaterThanOrEqual(later.frame.height, 44)
        XCTAssertGreaterThanOrEqual(later.frame.width, 44)
        later.tap()
        XCTAssertNotEqual(app.staticTexts["trimEndValue"].label, "0:03.00")
        capture("P4A Dark Large Time Controls")
        app.buttons["cancelVideoEdit"].tap()
        XCTAssertEqual(playbackResult, .completed, "Selection playback stopped at \(playbackPosition)")
    }

    @MainActor func testFutureRecipeKeepsOriginalPreviewAndPreventsSaving() throws {
        let app = launch(extra: ["--p4a-stage-future-edit"])
        app.buttons["videosTab"].tap()
        let row = app.buttons["video_\(firstID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 20)); row.tap()
        XCTAssertTrue(app.buttons["editVideo"].waitForExistence(timeout: 5)); app.buttons["editVideo"].tap()
        XCTAssertTrue(app.staticTexts["videoEditMessage"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["videoEditMessage"].label.contains("newer"))
        XCTAssertFalse(app.buttons["saveVideoEdit"].isEnabled)
        XCTAssertTrue(app.otherElements["editorPreview"].exists)
        capture("P4A Future Edits Read Only")
        app.buttons["cancelVideoEdit"].tap()
        XCTAssertTrue(app.otherElements["originalVideoPlayer"].waitForExistence(timeout: 5))
    }

    @MainActor private func launch(extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p3c-stage-take-fixtures", "-AppleInterfaceStyle", "Light"] + extra
        app.launchSkippingIntroduction()
        return app
    }

    @MainActor private func openEditor(_ app: XCUIApplication, takeID: String? = nil) {
        app.buttons["videosTab"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Lesson\n")
        let row = app.buttons["video_\(takeID ?? firstID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 20)); row.tap()
        XCTAssertTrue(app.buttons["editVideo"].waitForExistence(timeout: 5)); app.buttons["editVideo"].tap()
        waitReady(app)
    }

    @MainActor private func waitReady(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["saveVideoEdit"].waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["saveVideoEdit"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }

    @MainActor private func trim(_ app: XCUIApplication, startFraction: Double, endFraction: Double) {
        let start = app.descendants(matching: .any).matching(identifier: "trimStartHandle").firstMatch
        let end = app.descendants(matching: .any).matching(identifier: "trimEndHandle").firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5), app.debugDescription); XCTAssertTrue(end.exists)
        if !start.isHittable { app.swipeUp() }
        // Portrait controls are inset inside this scroll view. Cropped video
        // and AX child unions do not represent the full source timeline width.
        let column = app.scrollViews.containing(.any, identifier: "trimStartHandle").firstMatch.frame.insetBy(dx: 18, dy: 0)
        let left = column.minX + 22, width = column.width - 44
        let screen = app.coordinate(withNormalizedOffset: .zero)
        let startOrigin = start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let startTarget = screen.withOffset(CGVector(dx: left + width * startFraction, dy: start.frame.midY))
        startOrigin.press(forDuration: 0.1, thenDragTo: startTarget)
        let endOrigin = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let endTarget = screen.withOffset(CGVector(dx: left + width * endFraction, dy: end.frame.midY))
        endOrigin.press(forDuration: 0.1, thenDragTo: endTarget)
        XCTAssertEqual(seconds(app.staticTexts["trimStartValue"].label), 3 * startFraction, accuracy: 0.06)
        XCTAssertEqual(seconds(app.staticTexts["trimEndValue"].label), 3 * endFraction, accuracy: 0.06)
    }

    private func seconds(_ label: String) -> Double {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) else {
            XCTFail("Unexpected editor time: \(label)"); return .nan
        }
        return minutes * 60 + seconds
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
