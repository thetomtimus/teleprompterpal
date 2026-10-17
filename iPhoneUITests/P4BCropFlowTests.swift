import UIKit
import XCTest

final class P4BCropFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testPresetFramingAndRenderedPlayback() throws {
        let app = launch(); openEditor(app, index: 0)
        assertPixels(app, orientation: 0)
        let presets: [(String, Int, Int)] = [
            ("portrait", 134, 240), ("landscape", 320, 180), ("square", 240, 240), ("fourByFive", 192, 240),
        ]
        for (preset, width, height) in presets {
            openCrop(app); app.buttons["cropPreset_" + preset].tap()
            XCTAssertEqual(app.staticTexts["cropDimensions"].label, "\(width) × \(height) pixels")
            if preset == "portrait" {
                let horizontal = app.sliders["cropHorizontal"]
                reveal(horizontal, app: app); horizontal.adjust(toNormalizedSliderPosition: 0.95)
            }
            if preset == "fourByFive" { capture("P4B Crop Portrait") }
            app.buttons["applyCrop"].tap()
            XCTAssertTrue(app.buttons["editCrop"].waitForExistence(timeout: 5))
            let viewport = app.otherElements["editorVideoViewport"]
            XCTAssertTrue(viewport.waitForExistence(timeout: 5))
            XCTAssertEqual(viewport.frame.width / viewport.frame.height, Double(width) / Double(height), accuracy: 0.02)
            assertPixels(app, orientation: 0, rightOnly: preset == "portrait")
        }
        app.buttons["playTrimSelection"].tap()
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "0:00.00"),
                                                 object: app.staticTexts["editorPlayheadTime"])
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 2), .completed)
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Play selection"),
                                                object: app.buttons["playTrimSelection"])
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 6), .completed)
        capture("P4B Cropped Playback")
    }

    @MainActor func testCustomGesturesCancelSaveAndRelaunch() throws {
        let app = launch(); openEditor(app, index: 1)
        openCrop(app); app.buttons["cropPreset_square"].tap(); app.buttons["cancelCrop"].tap()
        XCTAssertTrue(app.buttons["editCrop"].label.contains("Original"))
        openCrop(app); app.buttons["cropPreset_custom"].tap()
        let source = app.otherElements["cropSourceViewport"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        let rect = source.frame
        drag(app, identifier: "cropCorner_topLeft", to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.2))
        drag(app, identifier: "cropCorner_bottomRight", to: CGPoint(x: rect.minX + rect.width * 0.8, y: rect.minY + rect.height * 0.8))
        let frame = app.otherElements["cropMoveFrame"].frame
        drag(app, identifier: "cropMoveFrame", to: CGPoint(x: frame.midX + rect.width * 0.1, y: frame.midY + rect.height * 0.1))
        let moved = app.otherElements["cropMoveFrame"].frame
        XCTAssertEqual((moved.minX - rect.minX) / rect.width, 0.3, accuracy: 0.025)
        XCTAssertEqual((moved.minY - rect.minY) / rect.height, 0.3, accuracy: 0.025)
        let dimensions = app.staticTexts["cropDimensions"].label
        let values = dimensions.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0], 144, accuracy: 4); XCTAssertEqual(values[1], 192, accuracy: 4)
        capture("P4B Custom Crop")
        app.buttons["applyCrop"].tap()
        XCTAssertTrue(app.buttons["editCrop"].waitForExistence(timeout: 5))
        assertPixels(app, orientation: 1)
        app.buttons["saveVideoEdit"].tap()
        XCTAssertTrue(app.buttons["editVideo"].waitForExistence(timeout: 5))
        app.terminate(); app.launchSkippingIntroduction(); openEditor(app, index: 1)
        XCTAssertTrue(app.buttons["editCrop"].label.contains("Custom"))
        openCrop(app)
        XCTAssertTrue(app.buttons["cropPreset_custom"].isSelected)
        XCTAssertEqual(app.staticTexts["cropDimensions"].label, dimensions)
        capture("P4B Custom Restored")
        app.buttons["cancelCrop"].tap()
        app.buttons["resetVideoEdit"].tap()
        XCTAssertTrue(app.buttons["editCrop"].label.contains("Original"))
        app.buttons["cancelVideoEdit"].tap()
        app.buttons["editVideo"].tap()
        XCTAssertTrue(app.buttons["editCrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["editCrop"].label.contains("Custom"))
    }

    @MainActor func testRotationMirrorPixelsAndLandscapeCrop() throws {
        let app = launch()
        for index in 0..<8 {
            if index == 3 {
                // The iOS 27 automation server can retain an unmatched animation
                // notification when rotating an open crop task. Start this
                // viewport before presentation; assert its real rendered pixels.
                app.terminate(); XCUIDevice.shared.orientation = .landscapeLeft; app.launchSkippingIntroduction()
            }
            openEditor(app, index: index)
            assertPixels(app, orientation: index % 4, mirrored: index >= 4)
            if index == 3 {
                openCrop(app); app.buttons["cropPreset_fourByFive"].tap()
                XCTAssertTrue(app.buttons["applyCrop"].waitForExistence(timeout: 5))
                capture("P4B Crop Landscape")
                app.buttons["applyCrop"].tap()
                assertPixels(app, orientation: index % 4)
                capture("P4B Preview Landscape")
                app.terminate(); XCUIDevice.shared.orientation = .portrait; app.launchSkippingIntroduction()
                continue
            }
            app.buttons["cancelVideoEdit"].tap()
            app.buttons["closeTake"].tap()
        }
    }

    @MainActor func testDarkAccessibilityCropControls() throws {
        let app = launch(extra: ["--p4a-dark-appearance", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openEditor(app, index: 0); openCrop(app)
        capture("P4B Crop Dark Large")
        let custom = app.buttons["cropPreset_custom"]
        reveal(custom, app: app); custom.tap()
        let width = app.sliders["cropWidth"]
        revealSlider(width, app: app)
        width.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: width.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
        XCTAssertTrue(app.sliders["cropHorizontal"].isEnabled)
        XCTAssertEqual(percent(width), 60, accuracy: 5)
        let height = app.sliders["cropHeight"]
        revealSlider(height, app: app); height.adjust(toNormalizedSliderPosition: 0.7)
        XCTAssertEqual(percent(height), 70, accuracy: 5)
        print("P4B crop size controls: width=\(width.value ?? "missing"), height=\(height.value ?? "missing"), \(app.staticTexts["cropDimensions"].label)")
        capture("P4B Crop Dark Large Controls")
        XCTAssertTrue(app.buttons["applyCrop"].isHittable)
        XCTAssertTrue(app.buttons["cancelCrop"].isHittable)
        app.buttons["applyCrop"].tap()
        XCTAssertTrue(app.buttons["editCrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["editCrop"].label.contains("Custom"))
    }

    @MainActor private func launch(extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p4b-stage-crop-fixtures"] + extra
        app.launchSkippingIntroduction(); return app
    }

    @MainActor private func openEditor(_ app: XCUIApplication, index: Int) {
        app.buttons["videosTab"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap()
        let clear = search.buttons["Clear text"]
        if clear.exists { clear.tap() }
        let query = "Crop sample \(index % 4 * 90)"
        search.typeText(query)
        XCTAssertEqual(search.value as? String, query)
        search.typeText("\n")
        let row = app.buttons[String(format: "video_C40B0000-0000-4000-8000-%012d", index + 1)]
        for _ in 0..<6 where !row.exists { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10)); reveal(row, app: app); row.tap()
        XCTAssertTrue(app.buttons["editVideo"].waitForExistence(timeout: 5)); app.buttons["editVideo"].tap()
        XCTAssertTrue(app.buttons["editCrop"].waitForExistence(timeout: 10))
    }

    @MainActor private func openCrop(_ app: XCUIApplication) {
        let button = app.buttons["editCrop"]; reveal(button, app: app); button.tap()
        XCTAssertTrue(app.buttons["applyCrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cropPreset_original"].waitForExistence(timeout: 5))
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func revealSlider(_ slider: XCUIElement, app: XCUIApplication) {
        let top = app.navigationBars.firstMatch.frame.maxY + 20
        let bottom = app.frame.maxY - 65
        for _ in 0..<10 {
            if slider.exists, slider.isHittable, slider.frame.minY >= top, slider.frame.maxY <= bottom { break }
            if slider.exists, slider.frame.midY < top { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(slider.isHittable)
        XCTAssertGreaterThanOrEqual(slider.frame.minY, top)
        XCTAssertLessThanOrEqual(slider.frame.maxY, bottom)
    }

    @MainActor private func percent(_ slider: XCUIElement) -> Double {
        let value = slider.value as? String ?? ""
        guard let number = Double(value.filter { $0.isNumber || $0 == "." }) else { return -1 }
        // Native snapshots can expose the raw 0...1 value or a formatted percent.
        return value.contains("%") || number > 1 ? number : number * 100
    }

    @MainActor private func drag(_ app: XCUIApplication, identifier: String, to point: CGPoint) {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(element.frame.width, 44)
        XCTAssertGreaterThanOrEqual(element.frame.height, 44)
        let target = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y))
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: target)
    }

    @MainActor private func assertPixels(_ app: XCUIApplication, orientation: Int, mirrored: Bool = false, rightOnly: Bool = false) {
        let viewport = app.otherElements["editorVideoViewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        let rect = viewport.frame
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: app.frame.size, format: format).image { _ in
            XCUIScreen.main.screenshot().image.draw(in: CGRect(origin: .zero, size: app.frame.size))
        }.cgImage!
        for point in [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.8, y: 0.8)] {
            var u = rightOnly ? 0.7 : point.x
            let v = point.y
            if mirrored { u = 1 - u }
            let x: Double, y: Double
            switch orientation {
            case 1: x = v; y = 1 - u
            case 2: x = 1 - u; y = 1 - v
            case 3: x = 1 - v; y = u
            default: x = u; y = v
            }
            let expected = x < 0.5 ? (y < 0.5 ? [235, 30, 30] : [30, 30, 235])
                : (y < 0.5 ? [30, 220, 30] : [235, 220, 30])
            let actual = pixel(image, at: CGPoint(x: rect.minX + rect.width * point.x, y: rect.minY + rect.height * point.y))
            for channel in 0..<3 {
                XCTAssertEqual(actual[channel], expected[channel], accuracy: 45,
                    "orientation \(orientation) mirror \(mirrored) point \(point) actual \(actual), frame \(rect), screen \(app.frame)")
            }
        }
    }

    private func pixel(_ image: CGImage, at point: CGPoint) -> [Int] {
        let cropped = image.cropping(to: CGRect(x: floor(point.x), y: floor(point.y), width: 1, height: 1))!
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes.map(Int.init)
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
