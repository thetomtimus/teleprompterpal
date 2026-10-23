import XCTest

/// Opt-in captures of the actual app for the multilingual help guide.
/// Run only on the dedicated, pre-seeded guide simulator (see Marketing/docs/help-center.md).
final class HelpGuideCaptureTests: XCTestCase {
    private let rootID = "8D47F5E6-3E86-4C8C-9503-87E4ACB12345"
    private let takeID = "C40B0001-1111-4444-8888-123456789012"
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PAL_HELP_CAPTURE"] == "1", "Manual help capture only")
    }

    @MainActor private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(rootID)", "--p3d-simulate-capture", "-AppleInterfaceStyle", "Dark"]
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["recordFromLibrary"].waitForExistence(timeout: 20))
        return app
    }
    @MainActor private func mark(_ name: String) { print("HELP_MARK \(name) \(Date().timeIntervalSince1970)") }
    @MainActor private func settle(_ seconds: Double = 0.8) {
        let settled = expectation(description: "Settle native transition")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: seconds + 3), .completed)
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        settle()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "help-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func wait(_ element: XCUIElement, _ predicate: String, timeout: Double = 15) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)], timeout: timeout), .completed)
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func openScript(_ app: XCUIApplication) {
        let script = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_' AND label CONTAINS 'Garden update'")).firstMatch
        XCTAssertTrue(script.waitForExistence(timeout: 10)); script.tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
    }

    @MainActor func test01ImportAndRehearse() {
        let app = launch()
        app.buttons["Library"].tap()
        capture("import-menu", app: app)
        app.buttons["Import Text"].tap()
        let search = app.searchFields["Search"]
        XCTAssertTrue(search.waitForExistence(timeout: 15)); search.tap(); search.typeText("Garden update.txt\n")
        let file = app.scrollViews["Search results"].cells.matching(NSPredicate(format: "label CONTAINS 'Garden update'")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 20))
        capture("import-picker", app: app); file.tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 10))
        capture("imported-editor", app: app)
        app.buttons["scriptActions"].tap(); capture("script-actions", app: app)
        app.buttons["openReader"].tap()
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        capture("rehearsal", app: app)
        mark("rehearsal-start")
        app.buttons["togglePrompt"].tap(); settle(3)
        app.textViews["promptReader"].swipeUp()
        settle(1)
        XCTAssertEqual(app.buttons["togglePrompt"].label, "Play text")
        app.buttons["restartPrompt"].tap(); settle(1)
        mark("rehearsal-end")
        app.sliders["Prompt pace"].adjust(toNormalizedSliderPosition: 0.16)
        app.sliders["Prompt font"].adjust(toNormalizedSliderPosition: 0.2)
        capture("rehearsal-controls", app: app)
    }

    @MainActor func test02Recording() {
        let app = launch(); openScript(app)
        app.buttons["recordFromEditor"].tap()
        let record = app.buttons["recordTake"]
        XCTAssertTrue(record.waitForExistence(timeout: 10)); wait(record, "enabled == true")
        capture("camera", app: app)
        mark("recording-start"); record.tap()
        capture("countdown", app: app)
        let state = app.descendants(matching: .any).matching(identifier: "captureState").firstMatch
        wait(state, "label BEGINSWITH 'Recording'")
        capture("recording", app: app); settle(2)
        app.buttons["stopRecording"].tap()
        wait(record, "enabled == true", timeout: 20); settle(1)
        mark("recording-end")
        app.buttons["promptSpeed"].tap(); capture("speed", app: app)
    }

    @MainActor func test03TrimCropAndDeliver() {
        let app = launch()
        app.buttons["videosTab"].tap()
        let row = app.buttons["video_\(takeID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 20)); reveal(row, app: app); row.tap()
        XCTAssertTrue(app.buttons["editVideo"].waitForExistence(timeout: 10))
        capture("original-video", app: app)
        app.buttons["editVideo"].tap()
        let save = app.buttons["saveVideoEdit"]
        XCTAssertTrue(save.waitForExistence(timeout: 15)); wait(save, "enabled == true")
        capture("trim-before", app: app)
        let start = app.descendants(matching: .any).matching(identifier: "trimStartHandle").firstMatch
        let end = app.descendants(matching: .any).matching(identifier: "trimEndHandle").firstMatch
        reveal(start, app: app)
        let column = app.scrollViews.containing(.any, identifier: "trimStartHandle").firstMatch.frame.insetBy(dx: 18, dy: 0)
        let left = column.minX + 22, width = column.width - 44
        let screen = app.coordinate(withNormalizedOffset: .zero)
        mark("trim-start")
        start.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.2, thenDragTo: screen.withOffset(.init(dx: left + width * 0.16, dy: start.frame.midY)))
        settle(1)
        end.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.2, thenDragTo: screen.withOffset(.init(dx: left + width * 0.78, dy: end.frame.midY)))
        settle(1); capture("trim", app: app)
        let play = app.buttons["playTrimSelection"]; reveal(play, app: app); play.tap(); settle(3); play.tap(); settle(1)
        mark("trim-end")
        let crop = app.buttons["editCrop"]; reveal(crop, app: app); crop.tap()
        XCTAssertTrue(app.buttons["cropPreset_square"].waitForExistence(timeout: 5))
        mark("crop-start"); app.buttons["cropPreset_square"].tap(); settle(1)
        let horizontal = app.sliders["cropHorizontal"]; reveal(horizontal, app: app); horizontal.adjust(toNormalizedSliderPosition: 0.62)
        capture("crop", app: app)
        app.buttons["applyCrop"].tap(); settle(1); mark("crop-end")
        capture("cropped-video", app: app)
        let export = app.buttons["exportMP4"]; reveal(export, app: app); export.tap()
        wait(app.staticTexts["mp4ExportStatus"], "label == 'MP4 ready'", timeout: 40)
        capture("export-ready", app: app)
        let share = app.buttons["deliverMP4_share"]; reveal(share, app: app)
        capture("destinations", app: app)
        let photos = app.buttons["deliverMP4_photos"]; reveal(photos, app: app); photos.tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 4) {
            alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' AND NOT label CONTAINS[c] 'Don'")).firstMatch.tap()
        }
        wait(app.staticTexts["deliveryResult_photos"], "label CONTAINS 'Saved to Photos'", timeout: 20)
        capture("photos-saved", app: app)
        let files = app.buttons["deliverMP4_files"]; reveal(files, app: app); files.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 15))
        capture("files-picker", app: app); app.buttons["Save"].tap()
        wait(app.staticTexts["deliveryResult_files"], "label CONTAINS 'Saved to Files'", timeout: 20)
        reveal(app.staticTexts["deliveryResult_files"], app: app); capture("files-saved", app: app)
        reveal(share, app: app); share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)); capture("share-sheet", app: app)
    }
}
