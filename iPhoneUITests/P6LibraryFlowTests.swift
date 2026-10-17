import XCTest

final class P6LibraryFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testFirstUseRecordSelectionAndSettings() throws {
        let app = launch()
        let record = app.buttons["recordFromLibrary"]
        XCTAssertTrue(record.waitForExistence(timeout: 10)); capture("P6 Empty Scripts")
        record.tap()
        XCTAssertTrue(app.navigationBars["Choose a Script"].waitForExistence(timeout: 5))
        app.buttons["recordingCreateScript"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        record.tap()
        let blank = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recordingScript_'")).firstMatch
        XCTAssertTrue(blank.waitForExistence(timeout: 5)); XCTAssertFalse(blank.isEnabled)
        app.buttons["Cancel"].tap()
        // The create tile also works with an empty saved draft; use it to prepare
        // actual text, and prove selection doesn't start a take by itself.
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        card.tap(); app.textViews["scriptText"].tap()
        app.textViews["scriptText"].typeText("P6 recording chooser check. Read at your own pace.")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        record.tap(); capture("P6 Script Chooser")
        let selected = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recordingScript_'")).firstMatch
        XCTAssertTrue(selected.isEnabled); selected.tap()
        XCTAssertTrue(app.staticTexts["statusMessage"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["statusMessage"].label.contains("Simulator"))
        XCTAssertFalse(app.buttons["recordTake"].isEnabled)
        XCTAssertFalse(app.buttons["stopRecording"].exists)
        XCTAssertEqual(app.buttons["togglePrompt"].label, "Play text")
        app.buttons["closeReader"].tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        app.buttons["videosTab"].tap()
        XCTAssertTrue(app.staticTexts["No recordings yet"].waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.navigationBars["Choose a Script"].waitForExistence(timeout: 5)); app.buttons["Cancel"].tap()
        record.tap(); app.buttons["recordingCreateScript"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["scriptsTab"].isSelected)
        app.buttons["videosTab"].tap()
        app.buttons["appSettings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5)); capture("P6 Settings")
        app.buttons["gettingStarted"].tap()
        XCTAssertTrue(app.navigationBars["Getting Started"].waitForExistence(timeout: 5)); capture("P6 Getting Started")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["defaultReaderSettings"].tap()
        XCTAssertTrue(app.sliders["Font size"].waitForExistence(timeout: 5))
        app.sliders["Font size"].adjust(toNormalizedSliderPosition: 0.65)
        let savedFont = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' pt'")).firstMatch.label
        app.buttons["Done"].tap()
        app.terminate(); app.launchSkippingIntroduction()
        app.buttons["appSettings"].tap()
        app.buttons["defaultReaderSettings"].tap()
        XCTAssertTrue(app.sliders["Font size"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[savedFont].exists, app.debugDescription)
    }

    @MainActor func testSampleAndGroupedTakesAcrossOrientations() throws {
        let app = launch(fixtures: true)
        let sample = app.buttons["trySampleScript"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10)); sample.tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["scriptTitle"].value as? String, "My first take")
        XCTAssertTrue((app.textViews["scriptText"].value as? String ?? "").contains("Your original recording stays in the library."))
        app.openRehearsal()
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recordTake"].exists)
        app.buttons["closeReader"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap(); capture("P6 Scripts Sample")
        app.buttons["videosTab"].tap()
        let first = app.buttons["video_3231FD8A-2B93-4D0E-AB79-24A3CE000001"]
        XCTAssertTrue(first.waitForExistence(timeout: 15)); capture("P6 Grouped Takes Portrait")
        tapTake(first, app)
        XCTAssertTrue(app.buttons["closeTake"].waitForExistence(timeout: 5)); app.buttons["closeTake"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(); capture("P6 Grouped Takes Landscape")
        XCTAssertTrue(app.buttons["recordFromLibrary"].isHittable)
        app.buttons["recordFromLibrary"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Script"].waitForExistence(timeout: 5)); capture("P6 Chooser Landscape")
        app.buttons["Cancel"].tap()
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testDarkAccessibilityLibraryChooserAndHelp() throws {
        let app = launch(fixtures: true, accessible: true)
        XCTAssertTrue(app.buttons["trySampleScript"].waitForExistence(timeout: 10))
        capture("P6 Empty Scripts Dark Large")
        let sample = app.buttons["trySampleScript"]
        for _ in 0..<4 where !sample.isHittable { app.swipeUp() }
        sample.tap(); XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["recordFromLibrary"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Script"].waitForExistence(timeout: 5)); capture("P6 Chooser Dark Large")
        app.buttons["Cancel"].tap(); app.buttons["videosTab"].tap()
        let first = app.buttons["video_3231FD8A-2B93-4D0E-AB79-24A3CE000001"]
        capture("P6 Grouped Takes Dark Large")
        capture("P6 Accessible Linked Take")
        tapTake(first, app)
        XCTAssertTrue(app.buttons["closeTake"].waitForExistence(timeout: 5)); app.buttons["closeTake"].tap()
        app.buttons["appSettings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5)); capture("P6 Settings Dark Large")
        let help = app.buttons["gettingStarted"]
        tapSettingsHelp(help, app)
        XCTAssertTrue(app.navigationBars["Getting Started"].waitForExistence(timeout: 5)); capture("P6 Guide Dark Large")
    }

    @MainActor private func launch(fixtures: Bool = false, accessible: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())"]
        if fixtures { app.launchArguments.append("--p3c-stage-take-fixtures") }
        if accessible {
            app.launchArguments += ["--p4a-dark-appearance", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchSkippingIntroduction(); return app
    }
    @MainActor private func settle() {
        let settled = expectation(description: "Native transition settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 4), .completed)
    }
    @MainActor private func tapTake(_ take: XCUIElement, _ app: XCUIApplication) {
        let gallery = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if take.exists {
                let top = app.navigationBars.firstMatch.frame.maxY + 8
                let bottom = app.buttons["recordFromLibrary"].frame.minY - 8
                let visible = CGRect(x: 0, y: top, width: app.frame.width, height: max(0, bottom - top))
                let intersection = take.frame.intersection(visible)
                if intersection.width >= 44, intersection.height >= 44 {
                    // SwiftUI can report the offscreen center as hittable. Tap
                    // the actual visible part, clear of native bars/insets.
                    app.coordinate(withNormalizedOffset: .zero).withOffset(
                        CGVector(dx: intersection.midX, dy: intersection.midY)).tap()
                    return
                }
                if take.frame.midY < top { gallery.swipeDown() } else { gallery.swipeUp() }
            } else { gallery.swipeUp() }
        }
        XCTFail("Could not reveal the take clear of the navigation and Record bars: \(app.debugDescription)")
    }
    @MainActor private func tapSettingsHelp(_ help: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<12 {
            let top = app.navigationBars["Settings"].frame.maxY + 8
            let bottom = app.buttons["recordFromLibrary"].frame.minY - 8
            let visible = CGRect(x: 0, y: top, width: app.frame.width, height: max(0, bottom - top))
            if help.exists {
                let intersection = help.frame.intersection(visible)
                if intersection.width >= 44, intersection.height >= 44 {
                    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: intersection.midX, dy: intersection.midY)).tap()
                    return
                }
            }
            (app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? app).swipeUp()
        }
        XCTFail("Help could not be revealed clear of the persistent dock: \(app.debugDescription)")
    }
    @MainActor private func capture(_ name: String) {
        settle()
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
