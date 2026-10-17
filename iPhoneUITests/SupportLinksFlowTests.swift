import XCTest

final class SupportLinksFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testSettingsLinksOpenPublishedPagesAndReturnToApp() {
        checkLinks(accessible: false)
    }

    @MainActor func testSettingsLinksAtAccessibilitySize() {
        checkLinks(accessible: true)
    }

    @MainActor private func checkLinks(accessible: Bool) {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())"]
        if accessible {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchSkippingIntroduction()
        XCTAssertTrue(app.buttons["appSettings"].waitForExistence(timeout: 10))
        app.buttons["appSettings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("Settings Support Links")

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        for (identifier, heading) in [("privacyPolicyLink", "Privacy policy"), ("contactSupportLink", "Support")] {
            let link = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            reveal(link, in: app)
            XCTAssertTrue(link.isHittable)
            capture("Settings \(heading) Link")
            link.tap()
            XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
            // Safari may ask for its first-run search-provider/continuation choice.
            let continueButton = safari.buttons["Continue"]
            if continueButton.waitForExistence(timeout: 2) { continueButton.tap() }
            let webHeading = safari.webViews.staticTexts[heading].firstMatch
            XCTAssertTrue(webHeading.waitForExistence(timeout: 25), safari.debugDescription)
            XCTAssertTrue(safari.webViews.links["teleprompterpal.com"].firstMatch.exists)
            if identifier == "contactSupportLink" {
                let contact = safari.webViews.links["contact@teleprompterpal.com"].firstMatch
                for _ in 0..<8 where !contact.isHittable { safari.swipeUp() }
                XCTAssertTrue(contact.isHittable)
            }
            capture("Published \(heading)")
            app.activate()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        }

        // The existing offline summary remains reachable without opening Camera.
        for _ in 0..<6 where !app.buttons["Beta Information"].isHittable { app.swipeDown() }
        app.buttons["Beta Information"].tap()
        XCTAssertTrue(app.staticTexts["Purchases disabled"].waitForExistence(timeout: 5))
        let privacy = app.buttons["betaPrivacy"]
        reveal(privacy, in: app); privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        let fullPolicy = app.descendants(matching: .any).matching(identifier: "betaFullPrivacyPolicyLink").firstMatch
        reveal(fullPolicy, in: app)
        XCTAssertTrue(fullPolicy.isHittable)
        capture("Offline Privacy Summary Full Policy Link")
        app.terminate()
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.exists || !element.isHittable { app.swipeUp() }
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
