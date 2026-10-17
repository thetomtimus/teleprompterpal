import UIKit
import XCTest

final class P4CExportFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testEditedMP4ReadyPlaybackAndRelaunch() {
        let app = launch(probe: false); openEditor(app)
        app.buttons["editCrop"].tap()
        app.buttons["cropPreset_portrait"].tap()
        let horizontal = app.sliders["cropHorizontal"]
        reveal(horizontal, app: app); horizontal.adjust(toNormalizedSliderPosition: 0.95)
        app.buttons["applyCrop"].tap()
        beginExport(app)
        ready(app)
        XCTAssertTrue(app.staticTexts["mp4ExportDetails"].label.contains("134 × 240"))
        assertRightHandPixels(app)
        capture("P4C MP4 Ready Portrait")
        app.buttons["playExportedMP4"].tap()
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Pause MP4"),
                                                object: app.buttons["playExportedMP4"])
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 2), .completed)
        app.terminate(); app.launchSkippingIntroduction(); openEditor(app); beginExport(app); ready(app)
        assertRightHandPixels(app)
        capture("P4C MP4 Restored")
    }

    @MainActor func testProgressCancelRetryAndLandscapeReady() {
        let app = launch(landscape: true); openEditor(app); beginExport(app)
        XCTAssertTrue(app.buttons["cancelMP4Export"].waitForExistence(timeout: 5))
        capture("P4C Export Progress Landscape")
        app.buttons["cancelMP4Export"].tap()
        status(app, "Export cancelled")
        capture("P4C Export Cancelled")
        app.buttons["retryMP4Export"].tap(); ready(app)
        capture("P4C MP4 Ready Landscape")
        app.buttons["backFromMP4"].tap()
        XCTAssertTrue(app.buttons["exportMP4"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["deleteOriginal"].exists)
        app.buttons["cancelVideoEdit"].tap()
        XCTAssertTrue(app.buttons["deleteOriginal"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testTerminationAndBackgroundRequireDeliberateRetry() {
        let app = launch(); openEditor(app); beginExport(app)
        XCTAssertTrue(app.buttons["cancelMP4Export"].waitForExistence(timeout: 5))
        app.terminate(); app.launchSkippingIntroduction(); openEditor(app); beginExport(app)
        status(app, "Export interrupted")
        capture("P4C Relaunch Interrupted")
        XCTAssertTrue(app.buttons["retryMP4Export"].isHittable)
        app.buttons["retryMP4Export"].tap()
        XCTAssertTrue(app.buttons["cancelMP4Export"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        status(app, "Export interrupted")
        capture("P4C Background Interrupted")
        app.buttons["retryMP4Export"].tap(); ready(app)
    }

    @MainActor func testLowSpaceRetryDarkAccessibility() {
        let app = launch(extra: ["--p4c-scenario=low-space", "--p4a-dark-appearance",
                                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openEditor(app); beginExport(app)
        status(app, "Export could not finish")
        XCTAssertTrue(app.staticTexts["mp4ExportMessage"].label.localizedCaseInsensitiveContains("space"))
        capture("P4C Low Space Dark Large")
        let retry = app.buttons["retryMP4Export"]
        reveal(retry, app: app); retry.tap(); ready(app)
        capture("P4C MP4 Ready Dark Large")
        let play = app.buttons["playExportedMP4"]
        reveal(play, app: app)
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        XCTAssertTrue(app.buttons["backFromMP4"].isHittable)
        capture("P4C Ready Dark Large Controls")
    }

    @MainActor private func launch(probe: Bool = true, landscape: Bool = false, extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p4b-stage-crop-fixtures"]
            + (probe ? ["--p4c-export-probe"] : []) + extra
        app.launchSkippingIntroduction(); return app
    }

    @MainActor private func openEditor(_ app: XCUIApplication) {
        app.buttons["videosTab"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap()
        let clear = search.buttons["Clear text"]; if clear.exists { clear.tap() }
        search.typeText("Crop sample 0\n")
        let row = app.buttons["video_C40B0000-0000-4000-8000-000000000001"]
        for _ in 0..<8 where !row.exists || !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        let edit = app.buttons["editVideo"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, app: app); edit.tap()
        XCTAssertTrue(app.buttons["exportMP4"].waitForExistence(timeout: 10))
    }

    @MainActor private func beginExport(_ app: XCUIApplication) {
        let export = app.buttons["exportMP4"]; reveal(export, app: app); export.tap()
        XCTAssertTrue(app.buttons["backFromMP4"].waitForExistence(timeout: 10))
    }

    @MainActor private func ready(_ app: XCUIApplication) {
        status(app, "MP4 ready", timeout: 25)
        XCTAssertTrue(app.buttons["playExportedMP4"].exists)
    }

    @MainActor private func status(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 10) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label),
                                                   object: app.staticTexts["mp4ExportStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<10 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func assertRightHandPixels(_ app: XCUIApplication) {
        let viewport = app.otherElements["exportVideoViewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        let rect = viewport.frame
        XCTAssertEqual(rect.width / rect.height, 134.0 / 240, accuracy: 0.02)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: app.frame.size, format: format).image { _ in
            XCUIScreen.main.screenshot().image.draw(in: CGRect(origin: .zero, size: app.frame.size))
        }.cgImage!
        for (fraction, expected) in [(0.2, [30, 220, 30]), (0.8, [235, 220, 30])] {
            let crop = image.cropping(to: CGRect(x: floor(rect.midX), y: floor(rect.minY + rect.height * fraction), width: 1, height: 1))!
            var bytes = [UInt8](repeating: 0, count: 4)
            bytes.withUnsafeMutableBytes { buffer in
                let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                    bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            for channel in 0..<3 { XCTAssertEqual(Int(bytes[channel]), expected[channel], accuracy: 45) }
        }
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
