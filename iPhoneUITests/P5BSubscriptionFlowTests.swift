import StoreKitTest
import XCTest

final class P5BSubscriptionFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testPlansDisclosuresCloseAndExistingExportRemainAvailable() throws {
        let session = try localSession()
        let app = launch(extra: ["--p4b-stage-crop-fixtures"])
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app)
        capture("P5B Settings Light")
        app.buttons["viewSubscriptionPlans"].tap()
        let monthly = app.buttons["subscriptionPlan_local.teleprompter.pro.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 10), app.debugDescription)
        capture("P5B Plans Light")
        let annual = app.buttons["subscriptionPlan_local.teleprompter.pro.annual"]
        reveal(annual, app); annual.tap()
        let terms = app.staticTexts["subscriptionTerms"]
        reveal(terms, app)
        XCTAssertTrue(terms.label.contains("$9.99 every year"), terms.label)
        if annual.label.contains("Free trial available") {
            XCTAssertTrue(terms.label.contains("Free for 1 week"), terms.label)
        } else {
            XCTAssertFalse(terms.label.contains("Free for"), terms.label)
        }
        XCTAssertFalse(terms.label.contains("60-second"))
        let purchase = purchaseButton(app)
        for _ in 0..<5 where !app.frame.insetBy(dx: 0, dy: 60).contains(purchase.frame) { app.swipeUp() }
        capture("P6B Paywall Actions")
        capture("P5B Annual Terms Light")
        let privacy = app.buttons["paywallPrivacyLink"]
        reveal(privacy, app); privacy.tap()
        XCTAssertTrue(app.navigationBars["Prototype Privacy"].waitForExistence(timeout: 5))
        capture("P5B Privacy")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["closePaywall"].waitForExistence(timeout: 5))
        let legal = app.buttons["paywallTermsLink"]
        reveal(legal, app); legal.tap()
        XCTAssertTrue(app.navigationBars["Prototype Terms"].waitForExistence(timeout: 5))
        capture("P6B Prototype Terms")
        app.buttons["Done"].tap()
        app.buttons["closePaywall"].tap()
        XCTAssertTrue(app.staticTexts["subscriptionStatus"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["subscriptionStatus"].label, "No active subscription")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["videosTab"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("Crop sample 0\n")
        let take = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_C40B'")).firstMatch
        reveal(take, app); take.tap()
        let edit = app.buttons["editVideo"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, app); edit.tap()
        let export = app.buttons["exportMP4"]
        XCTAssertTrue(export.waitForExistence(timeout: 10)); reveal(export, app); export.tap()
        expect(app.staticTexts["mp4ExportStatus"], contains: "MP4 ready", app)
        XCTAssertFalse(app.buttons["subscribe"].exists)
    }

    @MainActor func testNativePurchaseRelaunchRestoreAndSubscriptionManagement() throws {
        let session = try localSession()
        let app = launch()
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app); app.buttons["viewSubscriptionPlans"].tap()
        purchaseButton(app).tap()
        expect(app.staticTexts["subscriptionStatus"], contains: "Pro active", app)
        capture("P5B Verified Purchase Settings")
        XCTAssertEqual(session.allTransactions().count, 1)
        app.terminate(); app.launchSkippingIntroduction(); openSettings(app)
        expect(app.staticTexts["subscriptionStatus"], contains: "Pro active", app)
        let restore = app.buttons["restoreSubscription"]
        reveal(restore, app); restore.tap()
        expect(app.staticTexts["subscriptionResult"], contains: "Purchases restored", app)
        let manage = app.buttons["manageSubscription"]
        reveal(manage, app); session.disableDialogs = false; manage.tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let title = system.navigationBars["Edit Subscription"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), system.debugDescription)
        capture("P5B Native Manage Subscription")
        let done = system.buttons["xmark"]
        XCTAssertTrue(done.exists, system.debugDescription); done.tap()
        let resumed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: manage)
        XCTAssertEqual(XCTWaiter.wait(for: [resumed], timeout: 5), .completed)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        expect(app.staticTexts["subscriptionStatus"], contains: "No active subscription", app)
        let result = app.staticTexts["subscriptionResult"]
        XCTAssertEqual(result.label, "Purchases restored.")
        XCTAssertFalse(result.label.contains("Pro is active"))
        capture("P5B Refunded Subscription Settings")
    }

    @MainActor func testPendingApprovalUpdatesWithoutRepurchase() throws {
        let session = try localSession()
        session.askToBuyEnabled = true
        let app = launch()
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app); app.buttons["viewSubscriptionPlans"].tap()
        purchaseButton(app).tap()
        expect(app.staticTexts["paywallResult"], contains: "Awaiting purchase approval", app)
        capture("P5B Pending Approval")
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        expect(app.staticTexts["subscriptionStatus"], contains: "Pro active", app)
        XCTAssertEqual(session.allTransactions().count, 1)
    }

    @MainActor func testNativePaymentSheetCancellationKeepsThePaywallDismissible() throws {
        let session = try localSession()
        session.disableDialogs = false
        let app = launch()
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app); app.buttons["viewSubscriptionPlans"].tap()
        purchaseButton(app).tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let paymentSheet = springboard.otherElements["payment-sheet"]
        XCTAssertTrue(paymentSheet.waitForExistence(timeout: 10), springboard.debugDescription)
        let cancel = springboard.buttons["dismiss"]
        XCTAssertTrue(cancel.exists, springboard.debugDescription)
        capture("P5B Native Purchase Sheet"); cancel.tap()
        XCTAssertTrue(app.staticTexts["paywallResult"].waitForExistence(timeout: 20), app.debugDescription)
        expect(app.staticTexts["paywallResult"], contains: "Purchase cancelled", app)
        XCTAssertEqual(session.allTransactions().count, 0)
        app.buttons["closePaywall"].tap()
        expect(app.staticTexts["subscriptionStatus"], contains: "No active subscription", app)
    }

    @MainActor func testNoPurchaseRestoreAndUnconfiguredBuildAreHonest() throws {
        let session = try localSession()
        let app = launch()
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app)
        app.buttons["restoreSubscription"].tap()
        expect(app.staticTexts["subscriptionResult"], contains: "No active subscription", app)
        app.terminate()
        app.launchArguments = ["--p2-test-root=\(UUID())"]
        app.launchSkippingIntroduction(); openSettings(app)
        expect(app.staticTexts["subscriptionStatus"], contains: "not configured", app)
        XCTAssertFalse(app.buttons["restoreSubscription"].isEnabled)
        XCTAssertFalse(app.buttons["manageSubscription"].isEnabled)
        app.buttons["viewSubscriptionPlans"].tap()
        XCTAssertTrue(app.buttons["closePaywall"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["subscribe"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'subscriptionPlan_'")).count, 0)
        let settled = expectation(description: "The unconfigured paywall finishes its system sheet transition")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
        capture("P5B Unconfigured Paywall")
    }

    @MainActor func testCatalogPurchaseAndRestoreFailuresCanBeRetried() async throws {
        let session = try localSession()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitLoadProductsAPI())
        let app = launch()
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app); app.buttons["viewSubscriptionPlans"].tap()
        let unavailable = app.staticTexts["subscriptionCatalogError"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 10), app.debugDescription)
        capture("P5B Catalog Unavailable")
        XCTAssertFalse(app.buttons["subscribe"].exists)
        try await session.setSimulatedError(nil, forAPI: StoreKitLoadProductsAPI())
        let retry = app.buttons["Retry Loading Plans"]
        reveal(retry, app); retry.tap()
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: StoreKitPurchaseAPI())
        purchaseButton(app).tap()
        expect(app.staticTexts["paywallResult"], contains: "could not be completed", app)
        capture("P5B Purchase Failed")
        try await session.setSimulatedError(nil, forAPI: StoreKitPurchaseAPI())
        purchaseButton(app).tap()
        expect(app.staticTexts["subscriptionStatus"], contains: "Pro active", app)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitAppStoreSyncAPI())
        let restore = app.buttons["restoreSubscription"]
        reveal(restore, app); restore.tap()
        expect(app.staticTexts["subscriptionResult"], contains: "could not be completed", app)
        XCTAssertEqual(app.staticTexts["subscriptionStatus"].label, "Pro active")
        try await session.setSimulatedError(nil, forAPI: StoreKitAppStoreSyncAPI())
        restore.tap()
        expect(app.staticTexts["subscriptionResult"], contains: "Purchases restored", app)
    }

    @MainActor func testUnverifiedPurchaseNeverClaimsActiveAccess() async throws {
        let session = try localSession()
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: StoreKitVerificationAPI())
        let app = launch()
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app); app.buttons["viewSubscriptionPlans"].tap()
        purchaseButton(app).tap()
        expect(app.staticTexts["paywallResult"], contains: "could not be verified", app)
        capture("P5B Unverified Purchase")
        app.buttons["closePaywall"].tap()
        let status = app.staticTexts["subscriptionStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertNotEqual(status.label, "Pro active")
    }

    @MainActor func testDarkLargeLandscapePlansAndActionsRemainReachable() throws {
        let session = try localSession()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(extra: ["--p4a-dark-appearance", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], portrait: false)
        defer { app.terminate(); session.resetToDefaultState(); session.clearTransactions() }
        openSettings(app)
        capture("P5B Settings Dark Large Landscape")
        let plans = app.buttons["viewSubscriptionPlans"]
        reveal(plans, app); plans.tap()
        XCTAssertTrue(app.buttons["closePaywall"].waitForExistence(timeout: 5))
        capture("P5B Plans Dark Large Landscape Top")
        let purchase = purchaseButton(app)
        XCTAssertGreaterThanOrEqual(purchase.frame.height, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["closePaywall"].frame.height, 44)
        capture("P5B Plans Dark Large Landscape Actions")
        let restore = app.buttons["paywallRestore"]
        reveal(restore, app); XCTAssertTrue(restore.isEnabled)
        let privacy = app.buttons["paywallPrivacyLink"]
        reveal(privacy, app); privacy.tap()
        XCTAssertTrue(app.navigationBars["Prototype Privacy"].waitForExistence(timeout: 5))
        let done = app.buttons["Done"]
        XCTAssertTrue(done.isHittable)
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        capture("P5B Privacy Dark Large Landscape")
        done.tap()
        XCTAssertTrue(app.buttons["closePaywall"].waitForExistence(timeout: 5))
        app.buttons["closePaywall"].tap()
        XCTAssertTrue(app.navigationBars["Subscription"].waitForExistence(timeout: 5))
    }

    @MainActor private func localSession() throws -> SKTestSession {
        guard ProcessInfo.processInfo.environment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] == "1" else {
            throw NSError(domain: "P5BTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use the TeleprompterPhone-P5 scheme"])
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TeleprompterLocal", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState(); session.clearTransactions()
        session.disableDialogs = true; session.timeRate = .realTime
        return session
    }
    @MainActor private func launch(extra: [String] = [], portrait: Bool = true) -> XCUIApplication {
        if portrait { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p5-local-paywall"] + extra
        app.launchEnvironment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] = "1"
        app.launchSkippingIntroduction(); return app
    }
    @MainActor private func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 10)); app.buttons["Library"].tap()
        let settings = app.buttons["subscriptionSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), app.debugDescription); settings.tap()
        XCTAssertTrue(app.buttons["viewSubscriptionPlans"].waitForExistence(timeout: 5), app.debugDescription)
    }
    @MainActor private func purchaseButton(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["subscribe"]
        reveal(button, app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed, app.debugDescription)
        reveal(button, app); return button
    }
    @MainActor private func expect(_ element: XCUIElement, contains: String, _ app: XCUIApplication) {
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true AND label CONTAINS[c] %@", contains), object: element)
        if XCTWaiter.wait(for: [settled], timeout: 3) == .completed { return }
        reveal(element, app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label CONTAINS[c] %@", contains), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed, app.debugDescription)
    }
    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let lower = origin.withOffset(CGVector(dx: app.frame.width * 0.65, dy: app.frame.height * 0.8))
        let upper = origin.withOffset(CGVector(dx: app.frame.width * 0.65, dy: app.frame.height * 0.32))
        for _ in 0..<18 where !element.exists || !element.isHittable { lower.press(forDuration: 0.05, thenDragTo: upper) }
        if !element.isHittable { for _ in 0..<18 where !element.isHittable { upper.press(forDuration: 0.05, thenDragTo: lower) } }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    @MainActor private func capture(_ name: String) {
        let settled = expectation(description: "Native screenshot transition settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 4), .completed)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
