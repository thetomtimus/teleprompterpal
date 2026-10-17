import StoreKit
import StoreKitTest
import XCTest

final class P5CSubscriptionPolicyFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private let monthly = "local.teleprompter.pro.monthly"
    private let annual = "local.teleprompter.pro.annual"

    @MainActor func testSubscriptionChangesDuringTakeKeepRecordingAndEditedExportAvailable() async throws {
        let session = try localSession(), app = launch(root: UUID())
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        startTake(app)
        let monthlyTransaction = try await session.buyProduct(identifier: monthly)
        recordingContinues(app)
        try session.disableAutoRenewForTransaction(identifier: UInt(monthlyTransaction.id))
        try session.expireSubscription(productIdentifier: monthly)
        recordingContinues(app)
        let annualTransaction = try await session.buyProduct(identifier: annual)
        recordingContinues(app)
        try session.refundTransaction(identifier: UInt(annualTransaction.id))
        recordingContinues(app)
        capture("P5C Recording After Subscription Refund")
        finishTakeAndReturnToLibrary(app)
        openSettings(app)
        wait(app.staticTexts["subscriptionStatus"], "label == 'No active subscription'")
        capture("P5C Inactive After Saved Take")
        backToScripts(app)
        openFirstTakeEditor(app)
        let later = app.buttons["trimStartLater"]
        reveal(later, app); later.tap()
        let start = app.staticTexts["trimStartValue"].label
        XCTAssertNotEqual(start, "0:00.00")
        let crop = app.buttons["editCrop"]
        reveal(crop, app); crop.tap()
        let square = app.buttons["cropPreset_square"]
        XCTAssertTrue(square.waitForExistence(timeout: 5)); square.tap()
        app.buttons["applyCrop"].tap()
        XCTAssertTrue(crop.waitForExistence(timeout: 5))
        XCTAssertFalse(crop.label.contains("Original"))
        let export = app.buttons["exportMP4"]
        reveal(export, app); export.tap()
        wait(app.staticTexts["mp4ExportStatus"], "label CONTAINS 'MP4 ready'", timeout: 20)
        XCTAssertFalse(app.buttons["subscribe"].exists)
        capture("P5C Edited MP4 Without Subscription")
        app.terminate(); app.launchSkippingIntroduction()
        openFirstTakeEditor(app)
        XCTAssertEqual(app.staticTexts["trimStartValue"].label, start)
        XCTAssertFalse(app.buttons["editCrop"].label.contains("Original"))
    }

    @MainActor func testUnavailableAndUnconfiguredBillingStillAllowNewTakes() async throws {
        let session = try localSession(), root = UUID()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitLoadProductsAPI())
        let app = launch(root: root)
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        startTake(app); finishTakeAndReturnToLibrary(app)
        openSettings(app); app.buttons["viewSubscriptionPlans"].tap()
        XCTAssertTrue(app.staticTexts["subscriptionCatalogError"].waitForExistence(timeout: 10))
        app.buttons["closePaywall"].tap()
        app.terminate()
        // Same saved library, but ordinary unconfigured billing; the local marker alone cannot opt in.
        app.launchArguments.removeAll { $0 == "--p5-local-paywall" }
        app.launchSkippingIntroduction()
        startTake(app); finishTakeAndReturnToLibrary(app)
        openSettings(app)
        wait(app.staticTexts["subscriptionStatus"], "label CONTAINS 'not configured'")
        XCTAssertFalse(app.buttons["restoreSubscription"].isEnabled)
        backToScripts(app)
        app.buttons["videosTab"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).allElementsBoundByIndex
        XCTAssertEqual(rows.count, 2)
        capture("P5C Two Takes With Billing Unavailable")
    }

    @MainActor private func localSession() throws -> SKTestSession {
        #if !targetEnvironment(simulator)
        throw XCTSkip("P5C uses synthetic Simulator capture only")
        #else
        guard ProcessInfo.processInfo.environment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] == "1" else {
            throw NSError(domain: "P5CTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use TeleprompterPhone-P5"])
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TeleprompterLocal", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState(); session.clearTransactions()
        session.disableDialogs = true; session.timeRate = .realTime
        return session
        #endif
    }

    @MainActor private func launch(root: UUID) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(root)", "--p3d-stage-script", "--p3d-simulate-capture", "--p5-local-paywall"]
        app.launchEnvironment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] = "1"
        app.launchSkippingIntroduction(); return app
    }

    @MainActor private func startTake(_ app: XCUIApplication) {
        let script = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(script.waitForExistence(timeout: 15)); script.tap()
        app.openRehearsal()
        let camera = app.segmentedControls.buttons["Camera"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5)); camera.tap()
        app.buttons["cameraOptions"].tap()
        XCTAssertTrue(app.staticTexts["No time limit · about 2 GB free to start"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let record = app.buttons["recordTake"]
        wait(record, "enabled == true")
        record.tap()
        wait(captureState(app), "label BEGINSWITH 'Recording'", timeout: 10)
        XCTAssertEqual(app.buttons["togglePrompt"].label, "Pause text")
    }

    @MainActor private func recordingContinues(_ app: XCUIApplication) {
        let state = captureState(app), previous = captureState(app).label
        let condition = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH 'Recording' AND label != %@", previous), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: 5), .completed, app.debugDescription)
        XCTAssertTrue(app.buttons["stopRecording"].isEnabled)
        XCTAssertFalse(app.buttons["subscribe"].exists)
    }

    @MainActor private func finishTakeAndReturnToLibrary(_ app: XCUIApplication) {
        app.buttons["stopRecording"].tap()
        wait(app.staticTexts["statusMessage"], "label BEGINSWITH 'Take saved.'", timeout: 15)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        backToScripts(app)
    }

    @MainActor private func backToScripts(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 5))
    }

    @MainActor private func openSettings(_ app: XCUIApplication) {
        app.buttons["Library"].tap()
        let settings = app.buttons["subscriptionSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.tap()
        XCTAssertTrue(app.buttons["viewSubscriptionPlans"].waitForExistence(timeout: 5))
    }

    @MainActor private func openFirstTakeEditor(_ app: XCUIApplication) {
        app.buttons["videosTab"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        let edit = app.buttons["editVideo"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, app); edit.tap()
        wait(app.buttons["saveVideoEdit"], "enabled == true")
    }

    @MainActor private func captureState(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "captureState").firstMatch
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
