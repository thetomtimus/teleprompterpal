import StoreKitTest
import XCTest

/// Native functional coverage. The verification script reads the UUID-scoped journal
/// afterward; the app gains no diagnostic screen or test-only accessibility payload.
final class P5DLocalEventFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testScriptPurchaseCaptureAllDestinationsAndRelaunch() throws {
        let session = try localSession(), app = launch(scenario: "activation")
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        let create = app.buttons["createScriptTile"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
        let title = app.textFields["scriptTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("P5D local test")
        let text = app.textViews["scriptText"]
        text.tap(); text.typeText("Local event test. This script stays on the device. Read naturally and record a short take.")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openSettings(app); app.buttons["viewSubscriptionPlans"].tap()
        let subscribe = app.buttons["subscribe"]
        wait(subscribe, "enabled == true")
        let privacy = app.buttons["paywallPrivacyLink"]
        reveal(privacy, app); privacy.tap()
        XCTAssertTrue(app.navigationBars["Prototype Privacy"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        reveal(subscribe, app); subscribe.tap()
        wait(app.staticTexts["subscriptionStatus"], "label == 'Pro active'")
        app.buttons["restoreSubscription"].tap()
        wait(app.staticTexts["subscriptionResult"], "label CONTAINS 'Purchases restored'")
        app.buttons["viewSubscriptionPlans"].tap()
        XCTAssertTrue(app.buttons["closePaywall"].waitForExistence(timeout: 5)); app.buttons["closePaywall"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let script = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(script.waitForExistence(timeout: 5)); script.tap(); app.openRehearsal()
        let camera = app.segmentedControls.buttons["Camera"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5)); camera.tap()
        XCTAssertTrue(app.staticTexts["No time limit · about 2 GB free to start"].exists)
        let record = app.buttons["recordTake"]
        wait(record, "enabled == true"); record.tap()
        wait(app.descendants(matching: .any).matching(identifier: "captureState").firstMatch, "label BEGINSWITH 'Recording'", timeout: 15)
        app.buttons["stopRecording"].tap()
        wait(app.staticTexts["statusMessage"], "label BEGINSWITH 'Take saved.'", timeout: 15)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(text.waitForExistence(timeout: 5)); app.navigationBars.buttons.element(boundBy: 0).tap()
        openEditor(app)
        reveal(app.buttons["trimStartLater"], app); app.buttons["trimStartLater"].tap()
        let start = app.staticTexts["trimStartValue"].label
        reveal(app.buttons["editCrop"], app); app.buttons["editCrop"].tap()
        let square = app.buttons["cropPreset_square"]
        XCTAssertTrue(square.waitForExistence(timeout: 5)); square.tap(); app.buttons["applyCrop"].tap()
        export(app)
        action("photos", app).tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let allow = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' AND NOT label CONTAINS[c] 'Don'")).firstMatch
            XCTAssertTrue(allow.exists); allow.tap()
        }
        result("photos", "Saved to Photos", app)
        action("files", app).tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 15)); app.buttons["Save"].tap()
        result("files", "Saved to Files", app)
        action("share", app).tap()
        let copy = app.cells.matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10)); copy.tap(); result("share", "Share completed", app)
        capture("P5D All Destinations Confirmed")
        app.terminate(); app.launchSkippingIntroduction(); openEditor(app)
        XCTAssertEqual(app.staticTexts["trimStartValue"].label, start)
        XCTAssertTrue(app.buttons["editCrop"].label.contains("1:1"))
        export(app)
        for (destination, message) in [("photos", "Saved to Photos"), ("files", "Saved to Files"), ("share", "Share completed")] {
            result(destination, message, app)
        }
        XCTAssertFalse(action("photos", app).isEnabled)
        capture("P5D Receipts And Edit After Relaunch")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
    }

    @MainActor func testCancelledExportAndUnknownDeliveryRecoverWithoutFalseSuccess() throws {
        let session = try localSession()
        let app = launch(scenario: "recovery", extra: ["--p4b-stage-crop-fixtures", "--p4c-export-probe", "--p4d-delivery-probe=photo-pending"])
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openEditor(app)
        reveal(app.buttons["exportMP4"], app); app.buttons["exportMP4"].tap()
        let cancel = app.buttons["cancelMP4Export"]
        wait(cancel, "enabled == true"); cancel.tap()
        wait(app.staticTexts["mp4ExportStatus"], "label CONTAINS[c] 'cancelled'", timeout: 20)
        capture("P5D Export Cancelled")
        let retry = app.buttons["retryMP4Export"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5)); retry.tap()
        wait(app.staticTexts["mp4ExportStatus"], "label == 'MP4 ready'", timeout: 30)
        action("photos", app).tap(); result("photos", "Saving to Photos", app)
        app.terminate(); app.launchSkippingIntroduction(); openEditor(app); export(app)
        result("photos", "unknown", app)
        capture("P5D Unknown Delivery After Relaunch")
        action("photos", app).tap()
        let confirm = app.buttons["Try Photos Again"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        result("photos", "Saved to Photos", app)
        capture("P5D Explicit Retry Confirmed")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
    }

    @MainActor private func localSession() throws -> SKTestSession {
        #if !targetEnvironment(simulator)
        throw XCTSkip("P5D is Simulator-only synthetic capture")
        #else
        guard ProcessInfo.processInfo.environment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] == "1" else {
            throw NSError(domain: "P5D", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use TeleprompterPhone-P5"])
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TeleprompterLocal", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true; session.timeRate = .realTime
        return session
        #endif
    }

    @MainActor private func launch(scenario: String, extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(), root = UUID()
        print("P5D_EVENT_ROOT scenario=\(scenario) id=\(root)")
        app.launchArguments = ["--p2-test-root=\(root)", "--p3d-simulate-capture", "--p5-local-paywall"] + extra
        app.launchEnvironment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] = "1"
        app.launchSkippingIntroduction(); return app
    }
    @MainActor private func openSettings(_ app: XCUIApplication) {
        let menu = app.buttons["Library"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10)); menu.tap()
        app.buttons["subscriptionSettings"].tap()
        XCTAssertTrue(app.buttons["viewSubscriptionPlans"].waitForExistence(timeout: 5))
    }
    @MainActor private func openEditor(_ app: XCUIApplication) {
        app.buttons["videosTab"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15)); row.tap()
        let edit = app.buttons["editVideo"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, app); edit.tap()
        wait(app.buttons["saveVideoEdit"], "enabled == true")
    }
    @MainActor private func export(_ app: XCUIApplication) {
        reveal(app.buttons["exportMP4"], app); app.buttons["exportMP4"].tap()
        wait(app.staticTexts["mp4ExportStatus"], "label == 'MP4 ready'", timeout: 30)
    }
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
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let lower = origin.withOffset(.init(dx: app.frame.width * 0.65, dy: app.frame.height * 0.8))
        let upper = origin.withOffset(.init(dx: app.frame.width * 0.65, dy: app.frame.height * 0.32))
        for _ in 0..<10 where !element.exists || !element.isHittable { lower.press(forDuration: 0.05, thenDragTo: upper) }
        for _ in 0..<10 where !element.isHittable { upper.press(forDuration: 0.05, thenDragTo: lower) }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
