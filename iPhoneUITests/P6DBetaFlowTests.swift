import XCTest

final class P6DBetaFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testBetaInformationPrivacyAndUncappedCameraCopy() {
        checkBeta(accessible: false)
    }

    @MainActor func testBetaInformationAtAccessibilitySize() {
        checkBeta(accessible: true)
    }

    @MainActor private func checkBeta(accessible: Bool) {
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())"]
        if accessible {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["premiumEntry"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["premiumEntry"].label, "Beta Information")
        capture("P6D Scripts")
        app.buttons["premiumEntry"].tap()
        XCTAssertTrue(app.navigationBars["Beta Information"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Purchases disabled"].exists)
        capture("P6D Beta Access")
        let policyRow = app.descendants(matching: .any).matching(identifier: "betaRecordingPolicy").firstMatch
        reveal(policyRow, app)
        XCTAssertTrue(policyRow.exists)
        XCTAssertEqual(policyRow.value as? String, "None")
        XCTAssertFalse(app.buttons["viewSubscriptionPlans"].exists)
        XCTAssertFalse(app.buttons["restoreSubscription"].exists)
        capture("P6D Beta Information")
        let privacy = app.buttons["betaPrivacy"]
        reveal(privacy, app); privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        capture("P6D Privacy Top")
        let diagnostics = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'no analytics upload service'")).firstMatch
        reveal(diagnostics, app)
        XCTAssertTrue(diagnostics.isHittable)
        capture("P6D Privacy Diagnostics")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let feedback = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'If you installed this beta'")).firstMatch
        reveal(feedback, app)
        capture("P6D Beta Feedback")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["trySampleScript"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        app.buttons["recordFromEditor"].tap()
        XCTAssertTrue(app.buttons["cameraOptions"].waitForExistence(timeout: 10))
        app.buttons["cameraOptions"].tap()
        XCTAssertTrue(app.staticTexts["No time limit · about 2 GB free to start"].waitForExistence(timeout: 5))
        capture("P6D Camera Settings")
        app.buttons["Done"].tap()
        app.buttons["closeReader"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["appSettings"].tap()
        let help = app.buttons["gettingStarted"]
        reveal(help, app); help.tap()
        let policy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'There is no recording time limit.'")).firstMatch
        reveal(policy, app)
        XCTAssertTrue(policy.isHittable)
        capture("P6D Getting Started")
        app.terminate()
    }

    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<8 where !element.exists || !element.isHittable {
            app.swipeUp()
        }
    }

    @MainActor private func capture(_ name: String) {
        let ready = expectation(description: "Native transition settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { ready.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 4), .completed)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
