import XCTest
import UIKit

final class P3DIntegrationFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testLongReaderRotationPreservesPlayingPosition() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("The staged long script is a Debug Simulator fixture")
        #else
        let rootID = UUID().uuidString
        print("P3D_ROTATION_ROOT=\(rootID)")
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(rootID)", "--p3d-stage-script"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchSkippingIntroduction()
        let script = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(script.waitForExistence(timeout: 10)); script.tap()
        app.openRehearsal()
        let play = app.buttons["togglePrompt"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        app.sliders["Prompt font"].adjust(toNormalizedSliderPosition: 0.45)
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            settle(2)
            XCTAssertTrue(play.isHittable)
            XCTAssertEqual(play.label, "Pause text")
        }
        play.tap()
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        // The scoped on-disk checkpoint and per-reader geometry trace are checked
        // alongside this UI result; no internal position is added to product UI.
        #endif
    }

    @MainActor func testSimulatedCaptureLongReaderPlaybackAndRecovery() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("This flow explicitly validates synthetic Simulator capture")
        #else
        let rootID = UUID().uuidString
        print("P3D_SIMULATOR_ROOT=\(rootID)")
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(rootID)", "--p3d-stage-script", "--p3d-simulate-capture"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchSkippingIntroduction()
        let script = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(script.waitForExistence(timeout: 15))
        script.tap()
        let editor = app.textViews["scriptText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual((editor.value as? String ?? "").split(whereSeparator: \.isWhitespace).count, 10_000)
        app.openRehearsal()
        let camera = app.segmentedControls.buttons["Camera"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5)); camera.tap()
        let record = app.buttons["recordTake"]
        wait(record, predicate: "enabled == true", timeout: 10)
        record.tap()
        let stop = app.buttons["stopRecording"]
        XCTAssertTrue(stop.waitForExistence(timeout: 3)); stop.tap()
        wait(record, predicate: "enabled == true", timeout: 5)
        record.tap()
        let state = app.descendants(matching: .any).matching(identifier: "captureState").firstMatch
        wait(state, predicate: "label BEGINSWITH 'Recording'", timeout: 10)
        let play = app.buttons["togglePrompt"]
        XCTAssertEqual(play.label, "Pause text")
        capture("P3D Simulated Recording Portrait")

        app.buttons["promptSize"].tap()
        let font = app.sliders["Prompt font"]
        XCTAssertTrue(font.isHittable); font.adjust(toNormalizedSliderPosition: 0.45)
        XCTAssertEqual(play.label, "Pause text", "Font relayout keeps reading")
        app.buttons["Done"].tap(); app.buttons["promptSpeed"].tap()
        app.sliders["Prompt pace"].adjust(toNormalizedSliderPosition: 0.18)
        app.buttons["Done"].tap()
        XCTAssertEqual(play.label, "Pause text", "Pace changes keep reading")
        app.buttons["readerSettings"].tap()
        XCTAssertTrue(app.switches["Reading band"].waitForExistence(timeout: 5))
        app.switches["Reading band"].coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5)).tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Alignment'")).firstMatch.tap()
        app.buttons["Right"].tap()
        let move = app.descendants(matching: .any).matching(identifier: "movePrompt").firstMatch
        let resize = app.descendants(matching: .any).matching(identifier: "resizePrompt").firstMatch
        let settingsDone = app.navigationBars["Reader Settings"].buttons["Done"]
        // The iOS 27 menu can leave a stale {-1,-1} accessibility hit point.
        // This is the Done position in the captured portrait Settings sheet.
        for _ in 0..<3 where !move.isHittable {
            if settingsDone.isHittable { settingsDone.tap() }
            else { app.coordinate(withNormalizedOffset: .init(dx: 0.87, dy: 0.115)).tap() }
            settle(0.5)
        }
        XCTAssertFalse(settingsDone.exists)
        XCTAssertEqual(play.label, "Pause text", "Settings keep reading")
        XCTAssertTrue(move.isHittable && resize.isHittable)
        let origin = move.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.1, thenDragTo: origin.withOffset(.init(dx: 0, dy: 28)))
        let lower = resize.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        lower.press(forDuration: 0.1, thenDragTo: lower.withOffset(.init(dx: 0, dy: -24)))
        XCTAssertTrue(state.label.hasPrefix("Recording"))
        // A slow Simulator gesture can exceed the engine's 500 ms safety gap.
        // The position stays put; resume deliberately, as after any guarded pause.
        if play.label == "Play text" { play.tap() }
        XCTAssertEqual(play.label, "Pause text")
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            settle(2)
            XCTAssertTrue(stop.isHittable)
            XCTAssertTrue(state.label.hasPrefix("Recording"))
            capture(orientation == .landscapeLeft ? "P3D Simulated Recording Left" : "P3D Simulated Recording Right")
        }
        XCUIDevice.shared.orientation = .portrait
        settle(2)
        app.textViews["promptReader"].swipeUp()
        wait(play, predicate: "label == 'Play text'", timeout: 5)
        XCTAssertTrue(state.label.hasPrefix("Recording"))
        play.tap()
        // Real CADisplayLink/UI execution. The saved MOV remains an explicitly
        // synthetic 3-second fixture; no camera endurance or sync claim follows.
        settle(60)
        XCTAssertTrue(state.label.hasPrefix("Recording"))
        stop.tap()
        let status = app.staticTexts["statusMessage"]
        wait(status, predicate: "label BEGINSWITH 'Take saved.'", timeout: 15)
        wait(record, predicate: "enabled == true", timeout: 5)
        record.tap()
        wait(state, predicate: "label BEGINSWITH 'Recording'", timeout: 10)
        settle(2)
        XCUIDevice.shared.press(.home)
        settle(2)
        app.activate()
        wait(status, predicate: "label BEGINSWITH 'Take saved.' AND label CONTAINS 'inactive'", timeout: 15)
        XCTAssertFalse(record.isEnabled)
        capture("P3D Simulated Background Recovery")
        let controls = app.scrollViews.firstMatch
        for _ in 0..<4 where !app.buttons["Retry Camera"].isHittable { controls.swipeUp() }
        app.buttons["Retry Camera"].tap()
        wait(record, predicate: "enabled == true", timeout: 10)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["videosTab"].tap()
        let takes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).allElementsBoundByIndex
        XCTAssertEqual(takes.count, 2)
        XCTAssertTrue(takes[0].label.contains("Recovered recording"))
        takes[0].tap()
        XCTAssertTrue(app.buttons["closeTake"].waitForExistence(timeout: 5))
        app.otherElements["originalVideoPlayer"].tap()
        let transport = app.buttons["Play/Pause"]
        XCTAssertTrue(transport.waitForExistence(timeout: 2)); XCTAssertEqual(transport.label, "Pause")
        capture("P3D Recovered Synthetic Playback")
        app.buttons["closeTake"].tap()
        app.buttons["scriptsTab"].tap()
        script.tap(); app.openRehearsal()
        camera.tap(); wait(record, predicate: "enabled == true", timeout: 10)
        app.buttons["closeReader"].tap()
        app.terminate(); app.launchSkippingIntroduction()
        app.buttons["videosTab"].tap()
        let restored = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).count, 2)
        #endif
    }

    @MainActor private func wait(_ element: XCUIElement, predicate: String, timeout: Double) {
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: timeout), .completed)
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func settle(_ seconds: Double) {
        let settled = expectation(description: "P3D native integration clock")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: seconds + 3), .completed)
    }
}
