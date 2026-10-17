import XCTest
import UIKit

final class LibraryFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testCreateEditSearchReaderAndRelaunchPreserveUnicode() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID().uuidString)"]
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["createScriptTile"].waitForExistence(timeout: 10))
        app.buttons["createScriptTile"].tap()
        let title = app.textFields["scriptTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.press(forDuration: 1)
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
        } else {
            title.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        }
        title.typeText("P2 Unicode Lesson")
        let editor = app.textViews["scriptText"]
        editor.tap()
        let clipboard = UIPasteboard.general.string
        defer { UIPasteboard.general.string = clipboard }
        UIPasteboard.general.string = "한국어 café 🎥\n" + String(repeating: "Read this line at a comfortable pace. ", count: 35)
        editor.press(forDuration: 1)
        let paste = app.menuItems["Paste"].exists ? app.menuItems["Paste"] : app.buttons["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        if app.buttons["Allow Paste"].exists { app.buttons["Allow Paste"].tap() }
        app.openRehearsal()
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        let stageSettled = expectation(description: "Reader transition settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { stageSettled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [stageSettled], timeout: 3), .completed)
        let readerShot = XCTAttachment(screenshot: app.screenshot())
        readerShot.name = "P3 Portrait Reader"
        readerShot.lifetime = .keepAlways
        add(readerShot)
        app.buttons["togglePrompt"].tap()
        let elapsed = expectation(description: "Reader advances")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { elapsed.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [elapsed], timeout: 5), .completed)
        app.buttons["togglePrompt"].tap()
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.staticTexts["librarySaveStatus"].waitForExistence(timeout: 5))
        let saved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Saved on this iPhone'"),
            object: app.staticTexts["librarySaveStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        app.terminate()
        app.launchSkippingIntroduction()
        app.buttons["Library"].tap(); app.buttons["Search Scripts"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("한국어")
        let script = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(script.waitForExistence(timeout: 5))
        script.tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textViews["scriptText"].value as? String ?? "").hasPrefix("한국어 café 🎥"))
        let settled = expectation(description: "Navigation transition settles before native evidence capture")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "P2 Saved Unicode Editor"
        shot.lifetime = .keepAlways
        add(shot)
    }

    // A Debug-only, UUID-scoped fixture is staged, then selected through the real Files picker.
    @MainActor func testFilesImportDuplicateDeleteAndRestore() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        let testID = UUID().uuidString
        app.launchArguments = ["--p2-test-root=\(testID)", "--p2-stage-import-fixture"]
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 10))
        app.buttons["Library"].tap()
        app.buttons["Import Text"].tap()
        // Files remembers its last folder and exposes different sidebar states
        // on compact phones. Find this UUID-named document through its real
        // Search field rather than depending on a previous browse location.
        let filesSearch = app.searchFields["Search"]
        XCTAssertTrue(filesSearch.waitForExistence(timeout: 10), app.debugDescription)
        filesSearch.tap(); filesSearch.typeText("P2-Import-\(testID)\n")
        let fixture = app.scrollViews["Search results"].cells
            .matching(NSPredicate(format: "label CONTAINS %@", "P2-Import-\(testID)")).firstMatch
        XCTAssertTrue(fixture.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(fixture.isHittable, app.debugDescription)
        fixture.tap()
        let editor = app.textViews["scriptText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue((editor.value as? String ?? "").hasPrefix("한국어 café 🎥"))
        XCTAssertEqual(app.textFields["scriptTitle"].value as? String, "P2-Import-\(testID)")
        let editorShot = XCTAttachment(screenshot: app.screenshot())
        editorShot.name = "P2 Imported Editor"
        editorShot.lifetime = .keepAlways
        add(editorShot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1)
        app.buttons["Duplicate"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).count, 2)
        let libraryShot = XCTAttachment(screenshot: app.screenshot())
        libraryShot.name = "P2 Scripts Library"
        libraryShot.lifetime = .keepAlways
        add(libraryShot)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch.press(forDuration: 1)
        app.buttons["Delete"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).count, 1)
        app.buttons["Library"].tap()
        app.buttons["Recently Deleted"].tap()
        let restore = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'restore_'")).firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        let deletedShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        deletedShot.name = "P6B Recently Deleted"; deletedShot.lifetime = .keepAlways; add(deletedShot)
        restore.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).count, 2)
    }
}

final class ReaderStudioFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testUnavailableCameraKeepsRehearsalAndRecoveryReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID().uuidString)"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["createScriptTile"].waitForExistence(timeout: 10))
        app.buttons["createScriptTile"].tap()
        app.textViews["scriptText"].tap()
        app.textViews["scriptText"].typeText("Camera recovery test. 한국어 café 🎥\n" + String(repeating: "Keep reading at your own pace.\n", count: 6))
        app.openRehearsal()
        let modes = app.segmentedControls.firstMatch
        XCTAssertTrue(modes.buttons["Camera"].waitForExistence(timeout: 5))
        modes.buttons["Camera"].tap()
        XCTAssertTrue(app.staticTexts["statusMessage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["statusMessage"].label.contains("Simulator"))
        XCTAssertFalse(app.buttons["recordTake"].isEnabled)
        let controls = app.scrollViews.firstMatch
        for _ in 0..<5 where !(app.buttons["Retry Camera"].isHittable && app.buttons["Open Settings"].isHittable) { controls.swipeUp() }
        XCTAssertTrue(app.buttons["Retry Camera"].isHittable)
        XCTAssertTrue(app.buttons["Open Settings"].isHittable)
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "P3B Camera Recovery Portrait"; portrait.lifetime = .keepAlways; add(portrait)
        app.buttons["Retry Camera"].tap()
        XCTAssertTrue(app.staticTexts["statusMessage"].label.contains("Simulator"))
        XCUIDevice.shared.orientation = .landscapeLeft
        let settled = expectation(description: "Camera recovery landscape settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        for _ in 0..<5 where !(app.buttons["Retry Camera"].isHittable && app.buttons["Open Settings"].isHittable) { controls.swipeUp() }
        XCTAssertTrue(app.buttons["Retry Camera"].isHittable)
        XCTAssertTrue(app.buttons["Open Settings"].isHittable)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "P3B Camera Recovery Landscape"; landscape.lifetime = .keepAlways; add(landscape)
        for _ in 0..<4 where !modes.buttons["Rehearsal"].isHittable { controls.swipeDown() }
        XCTAssertTrue(modes.buttons["Rehearsal"].isHittable)
        modes.buttons["Rehearsal"].tap()
        let play = app.buttons["togglePrompt"]
        XCTAssertTrue(play.isHittable)
        play.tap()
        XCTAssertEqual(play.label, "Pause text")
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
    }

    @MainActor func testManualScrollSettingsAndRotationKeepTransportReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID().uuidString)"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["createScriptTile"].waitForExistence(timeout: 10))
        app.buttons["createScriptTile"].tap()
        let editor = app.textViews["scriptText"]
        editor.tap()
        editor.typeText(String(repeating: "Look into the lens. Speak at your own pace. 한국어 🎥\n", count: 40))
        app.openRehearsal()
        let play = app.buttons["togglePrompt"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        let portraitSettled = expectation(description: "Portrait studio settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { portraitSettled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [portraitSettled], timeout: 3), .completed)
        let portraitShot = XCTAttachment(screenshot: app.screenshot())
        portraitShot.name = "P3 Portrait Reader"
        portraitShot.lifetime = .keepAlways
        add(portraitShot)
        play.tap()
        app.textViews["promptReader"].swipeUp()
        let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Play text'"), object: play)
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 5), .completed)
        app.buttons["readerSettings"].tap()
        XCTAssertTrue(app.switches["Reading band"].waitForExistence(timeout: 5))
        // Native Form exposes the entire labeled row as a Switch; hit its trailing control.
        app.switches["Reading band"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let bandEnabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == '1'"), object: app.switches["Reading band"])
        XCTAssertEqual(XCTWaiter.wait(for: [bandEnabled], timeout: 5), .completed)
        app.buttons["Light"].tap()
        let settingsShot = XCTAttachment(screenshot: app.screenshot())
        settingsShot.name = "P3 Reader Settings"
        settingsShot.lifetime = .keepAlways
        add(settingsShot)
        app.navigationBars["Reader Settings"].buttons["Done"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        let settled = expectation(description: "Landscape layout settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        XCTAssertTrue(play.isHittable)
        XCTAssertTrue(app.buttons["restartPrompt"].isHittable)
        let landscapeShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscapeShot.name = "P3 Landscape Reader"
        landscapeShot.lifetime = .keepAlways
        add(landscapeShot)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        app.openRehearsal()
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["togglePrompt"].label, "Play text")
        let returnSettled = expectation(description: "Reopened rehearsal settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { returnSettled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [returnSettled], timeout: 4), .completed)
        let returnShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        returnShot.name = "P6B Reader Return Paused"; returnShot.lifetime = .keepAlways; add(returnShot)
        app.buttons["closeReader"].tap()
    }

    @MainActor func testReaderStageTransportRemainsReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID().uuidString)"]
        XCUIDevice.shared.orientation = .portrait
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["createScriptTile"].waitForExistence(timeout: 10))
        app.buttons["createScriptTile"].tap()
        app.textViews["scriptText"].tap()
        app.textViews["scriptText"].typeText("Take a breath. Look into the lens.\n\n한국어 café 🎥\n\n" + String(repeating: "Speak at your own pace.\n", count: 10))
        app.openRehearsal()
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["togglePrompt"].isHittable)
        XCTAssertTrue(app.buttons["restartPrompt"].isHittable)
        let settled = expectation(description: "Native reader evidence settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "P3 Reader Appearance"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
    }
}
