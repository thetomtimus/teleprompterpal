import XCTest

final class P4DDeliveryFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testPhotosPermissionDenialKeepsFilesAndShareAvailable() {
        let app = launch(); openExport(app)
        action(.photos, app).tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), app.debugDescription)
        capture("P4D Photos Permission")
        let deny = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Don’t Allow")).firstMatch
        if deny.exists { deny.tap() } else { alert.buttons["Don't Allow"].tap() }
        result(.photos, contains: "access is off", app)
        XCTAssertTrue(action(.files, app).isEnabled)
        XCTAssertTrue(action(.share, app).isEnabled)
        capture("P4D Photos Denied")
        action(.files, app).tap()
        cancelFiles(app)
        result(.files, contains: "cancelled", app)
    }

    @MainActor func testPhotosSaveAndReopenWithoutDuplicate() {
        let app = launch(); openExport(app)
        action(.photos, app).tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), app.debugDescription)
        capture("P4D Photos Add Only Permission")
        let allow = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' AND NOT label CONTAINS[c] 'Don'")).firstMatch
        XCTAssertTrue(allow.exists, alert.debugDescription); allow.tap()
        result(.photos, contains: "Saved to Photos", app)
        XCTAssertFalse(action(.photos, app).isEnabled)
        capture("P4D Photos Saved")
        app.terminate(); app.launchSkippingIntroduction(); openExport(app)
        result(.photos, contains: "Saved to Photos", app)
        XCTAssertFalse(action(.photos, app).isEnabled)
        capture("P4D Photos Saved Relaunch")
    }

    @MainActor func testFilesSaveAndShareCancelThenCopy() {
        let app = launch(); openExport(app)
        action(.files, app).tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), app.debugDescription)
        capture("P4D Save to Files")
        save.tap()
        result(.files, contains: "Saved to Files", app)
        capture("P4D Files Saved")
        action(.share, app).tap()
        let copy = app.cells.matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10), app.debugDescription)
        capture("P4D Share Sheet")
        let activity = app.otherElements["ActivityListView"]
        XCTAssertTrue(activity.exists, app.debugDescription)
        let outside = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: max(120, activity.frame.minY - 40)))
        outside.tap()
        result(.share, contains: "cancelled", app)
        action(.share, app).tap()
        XCTAssertTrue(copy.waitForExistence(timeout: 10), app.debugDescription); copy.tap()
        result(.share, contains: "Share completed", app)
        capture("P4D Share Completed")
        XCTAssertTrue(app.staticTexts["mp4ExportStatus"].label == "MP4 ready")
    }

    @MainActor func testRecoveryRequiresConfirmationBeforeAnotherPhotosSave() {
        let app = launch(extra: ["--p4d-delivery-probe=photo-pending"]); openExport(app)
        action(.photos, app).tap()
        result(.photos, contains: "Saving to Photos", app)
        app.terminate(); app.launchSkippingIntroduction(); openExport(app)
        result(.photos, contains: "unknown", app)
        capture("P4D Delivery Unknown")
        action(.photos, app).tap()
        let retry = app.buttons["Try Photos Again"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5), app.debugDescription)
        capture("P4D Confirm Unknown Retry")
        retry.tap()
        result(.photos, contains: "Saved to Photos", app)
    }

    @MainActor func testDarkLargeLandscapeDestinationsAndFilesCancel() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(extra: ["--p4a-dark-appearance", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], landscape: true)
        openExport(app)
        let files = action(.files, app)
        XCTAssertGreaterThanOrEqual(files.frame.height, 44)
        capture("P4D Dark Large Delivery Controls")
        files.tap()
        XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 15))
        capture("P4D Dark Large Files")
        cancelFiles(app)
        result(.files, contains: "cancelled", app)
        XCTAssertTrue(app.buttons["backFromMP4"].isHittable)
    }

    private enum Destination: String { case photos, files, share }
    @MainActor private func cancelFiles(_ app: XCUIApplication) {
        let picker = app.otherElements["Browse View (Picker)"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15), app.debugDescription)
        if app.frame.width > app.frame.height {
            // The iOS 27 remote picker reports portrait AX toolbar frames in
            // landscape. The captured outside edge at (44,46) dismisses it.
            let leading = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 44, dy: 46))
            for _ in 0..<4 {
                if !picker.exists { return }
                leading.tap()
            }
            return
        }
        for _ in 0..<3 {
            if let cancel = app.buttons.matching(NSPredicate(format: "label == 'Cancel'")).allElementsBoundByIndex.first(where: { $0.isHittable }) {
                cancel.tap(); return
            }
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].buttons["BackButton"]
            if back.exists && back.isHittable { back.tap() } else { break }
        }
        // iOS 27's nested-folder toolbar has Back/More/Save. Dismiss the
        // native sheet from its top edge rather than tapping a hidden Cancel.
        let screen = app.coordinate(withNormalizedOffset: .zero)
        let top = screen.withOffset(CGVector(dx: app.frame.midX, dy: picker.frame.minY + 6))
        let bottom = screen.withOffset(CGVector(dx: app.frame.midX, dy: app.frame.maxY - 20))
        top.press(forDuration: 0.1, thenDragTo: bottom)
    }
    @MainActor private func launch(extra: [String] = [], landscape: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p4b-stage-crop-fixtures"] + extra
        app.launchSkippingIntroduction(); return app
    }
    @MainActor private func openExport(_ app: XCUIApplication) {
        app.buttons["videosTab"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap()
        if search.buttons["Clear text"].exists { search.buttons["Clear text"].tap() }
        search.typeText("Crop sample 0\n")
        // Either zero-degree fixture exercises delivery. Choose the first
        // visible result so a large landscape row is not hidden by its sibling.
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video_C40B'")).firstMatch
        reveal(row, app)
        row.tap()
        let edit = app.buttons["editVideo"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, app); edit.tap()
        let export = app.buttons["exportMP4"]
        XCTAssertTrue(export.waitForExistence(timeout: 10)); reveal(export, app); export.tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'MP4 ready'"), object: app.staticTexts["mp4ExportStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed)
    }
    @MainActor private func action(_ destination: Destination, _ app: XCUIApplication) -> XCUIElement {
        let element = app.buttons["deliverMP4_" + destination.rawValue]
        reveal(element, app); return element
    }
    @MainActor private func result(_ destination: Destination, contains text: String, _ app: XCUIApplication) {
        let element = app.staticTexts["deliveryResult_" + destination.rawValue]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS[c] %@", text), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed, app.debugDescription)
        reveal(element, app)
    }
    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        let screen = app.coordinate(withNormalizedOffset: .zero)
        let lower = screen.withOffset(CGVector(dx: app.frame.width * 0.65, dy: app.frame.height * 0.8))
        let upper = screen.withOffset(CGVector(dx: app.frame.width * 0.65, dy: app.frame.height * 0.32))
        for _ in 0..<12 where !element.exists || !element.isHittable { lower.press(forDuration: 0.05, thenDragTo: upper) }
        if !element.isHittable { for _ in 0..<12 where !element.isHittable { upper.press(forDuration: 0.05, thenDragTo: lower) } }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
