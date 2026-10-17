import XCTest
import UIKit

/// A real native journey using explicitly opted-in synthetic Simulator capture.
/// No camera or microphone capture, remote recipient, or physical-phone claim.
final class P4EIntegrationFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testScriptThroughMarkedTakeTrimCropAllDestinationsAndRelaunch() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("This journey requires the Debug Simulator capture fixture")
        #else
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication(), root = UUID().uuidString
        print("P4E_NATIVE_ROOT=\(root)")
        app.launchArguments = ["--p2-test-root=\(root)", "--p3d-stage-script", "--p3d-simulate-capture",
            "-AppleInterfaceStyle", "Light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launchSkippingIntroduction()
        let script = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(script.waitForExistence(timeout: 15)); script.tap(); app.openRehearsal()
        let camera = app.segmentedControls.buttons["Camera"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5)); camera.tap()
        let record = app.buttons["recordTake"]
        wait(record, "enabled == true"); record.tap()
        let state = app.descendants(matching: .any).matching(identifier: "captureState").firstMatch
        wait(state, "label BEGINSWITH 'Recording'", timeout: 15)
        app.buttons["stopRecording"].tap()
        wait(app.staticTexts["statusMessage"], "label BEGINSWITH 'Take saved.'", timeout: 15)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["videosTab"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).count, 1)
        XCTAssertTrue(app.staticTexts["Simulator integration sample"].exists); row.tap()
        capture("P6B Original Take")
        openEditor(app)
        // Use labelled one-frame controls and the scrubber as accessible native
        // alternatives to the already covered drag handles.
        reveal(app.buttons["trimStartLater"], app); app.buttons["trimStartLater"].tap()
        let start = app.staticTexts["trimStartValue"].label
        XCTAssertEqual(start, "0:00.03")
        reveal(app.buttons["trimEndEarlier"], app); app.buttons["trimEndEarlier"].tap()
        let end = app.staticTexts["trimEndValue"].label
        XCTAssertEqual(end, "0:02.97")
        reveal(app.sliders["editorPlayhead"], app); app.sliders["editorPlayhead"].adjust(toNormalizedSliderPosition: 0.5)
        crop(app, custom: false)
        capture("P4E Saved Trim and Preset")
        app.buttons["saveVideoEdit"].tap(); openEditor(app)
        XCTAssertEqual(app.staticTexts["trimStartValue"].label, start)
        XCTAssertEqual(app.staticTexts["trimEndValue"].label, end)
        crop(app, custom: true)
        reveal(app.buttons["exportMP4"], app); app.buttons["exportMP4"].tap()
        ready(app)
        capture("P4E Marked MP4 Portrait")
        reveal(app.buttons["playExportedMP4"], app); app.buttons["playExportedMP4"].tap()
        wait(app.buttons["playExportedMP4"], "label == 'Pause MP4'", timeout: 3)
        action("photos", app).tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let allow = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' AND NOT label CONTAINS[c] 'Don'")).firstMatch
            XCTAssertTrue(allow.exists, alert.debugDescription); allow.tap()
        }
        result("photos", "Saved to Photos", app)
        XCTAssertFalse(action("photos", app).isEnabled)
        capture("P4E Photos Saved")
        action("files", app).tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), app.debugDescription)
        capture("P6B Save to Files Picker"); save.tap()
        result("files", "Saved to Files", app)
        capture("P4E Files Saved")
        action("share", app).tap()
        let copy = app.cells.matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10), app.debugDescription)
        capture("P6B Native Share Sheet"); copy.tap()
        result("share", "Share completed", app)
        capture("P4E Three Confirmed Destinations")
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            let share = action("share", app)
            XCTAssertGreaterThanOrEqual(share.frame.height, 44)
            // Exercise the visible control instead of XCTest's transient activation
            // point calculation immediately after an opposite-landscape flip.
            share.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(copy.waitForExistence(timeout: 10)); copy.tap()
            result("share", "Share completed", app)
            XCTAssertGreaterThan(app.buttons["backFromMP4"].frame.height, 0)
            capture(orientation == .landscapeLeft ? "P4E Landscape Left Results" : "P4E Landscape Right Results")
        }
        app.terminate(); XCUIDevice.shared.orientation = .portrait; app.launchSkippingIntroduction()
        app.buttons["videosTab"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap(); openEditor(app)
        XCTAssertEqual(app.staticTexts["trimStartValue"].label, start)
        XCTAssertEqual(app.staticTexts["trimEndValue"].label, end)
        XCTAssertTrue(app.buttons["editCrop"].label.contains("Custom"))
        reveal(app.buttons["exportMP4"], app); app.buttons["exportMP4"].tap(); ready(app)
        for (destination, text) in [("photos", "Saved to Photos"), ("files", "Saved to Files"), ("share", "Share completed")] {
            result(destination, text, app)
        }
        XCTAssertFalse(action("photos", app).isEnabled)
        capture("P4E All Receipts Relaunch")
        app.buttons["backFromMP4"].tap(); app.buttons["cancelVideoEdit"].tap()
        XCTAssertTrue(app.buttons["deleteOriginal"].waitForExistence(timeout: 5))
        app.buttons["closeTake"].tap(); app.buttons["scriptsTab"].tap()
        XCTAssertTrue(script.waitForExistence(timeout: 5)); script.tap(); app.openRehearsal()
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["togglePrompt"].label, "Play text")
        capture("P4E Reader Return Paused")
        #endif
    }

    @MainActor private func crop(_ app: XCUIApplication, custom: Bool) {
        reveal(app.buttons["editCrop"], app); app.buttons["editCrop"].tap()
        let preset = app.buttons[custom ? "cropPreset_custom" : "cropPreset_portrait"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); reveal(preset, app); preset.tap()
        if custom {
            for (id, fraction) in [("cropWidth", 0.7), ("cropHeight", 0.8), ("cropHorizontal", 0.7)] {
                let slider = app.sliders[id]; reveal(slider, app); slider.adjust(toNormalizedSliderPosition: fraction)
            }
        }
        capture(custom ? "P4E Custom Crop" : "P4E Preset Crop")
        app.buttons["applyCrop"].tap()
    }
    @MainActor private func openEditor(_ app: XCUIApplication) {
        let edit = app.buttons["editVideo"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, app); edit.tap()
        wait(app.buttons["saveVideoEdit"], "enabled == true")
        capture("P6B Video Trim Editor")
    }
    @MainActor private func ready(_ app: XCUIApplication) { wait(app.staticTexts["mp4ExportStatus"], "label == 'MP4 ready'", timeout: 25) }
    @MainActor private func action(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["deliverMP4_" + id]; reveal(button, app); return button
    }
    @MainActor private func result(_ id: String, _ text: String, _ app: XCUIApplication) {
        let label = app.staticTexts["deliveryResult_" + id]
        wait(label, "label CONTAINS[c] '\(text)'", timeout: 20); reveal(label, app)
    }
    @MainActor private func wait(_ element: XCUIElement, _ predicate: String, timeout: Double = 10) {
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: timeout), .completed)
    }
    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        // During a 180-degree landscape flip XCTest can expose a transient invalid
        // activation point. Use the native scroll container after rotation instead
        // of cached screen coordinates; callers still exercise the real control.
        let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? app.scrollViews.firstMatch
        func visible() -> Bool {
            guard element.exists else { return false }
            let frame = element.frame
            return frame.width > 0 && frame.height > 0 && app.frame.insetBy(dx: 1, dy: 1).contains(frame)
        }
        for _ in 0..<12 where !visible() { scroll.swipeUp() }
        for _ in 0..<12 where !visible() { scroll.swipeDown() }
        XCTAssertTrue(visible(), app.debugDescription)
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
