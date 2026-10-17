import XCTest

final class P6CHardeningFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    // This is real Simulator VoiceOver speech, separate from the AX tree checks.
    @MainActor func testVoiceOverLibraryReaderAndCropControls() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("VoiceOver service requires the iOS 27 test runtime") }
        let voiceOver = XCUIDevice.shared.voiceOverService
        // XCTest's stop-on-failure exception does not unwind Swift defer.
        // Register cleanup with XCTest as well so later journeys retain normal taps.
        addTeardownBlock { @MainActor in try voiceOver.disable() }
        defer { try? voiceOver.disable() }
        try voiceOver.enable()
        let app = launch()
        XCTAssertTrue(app.buttons["trySampleScript"].waitForExistence(timeout: 10))
        try speech("Scripts", service: voiceOver, containing: ["Record", "Videos"])
        activate(app.buttons["trySampleScript"])
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        try speech("Script editor", service: voiceOver, containing: ["Script text", "Record"])
        activate(app.buttons["scriptActions"]); activate(app.buttons["openReader"])
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        try speech("Rehearsal", service: voiceOver, containing: ["Play text", "Prompt pace"])
        activate(app.buttons["closeReader"])
        activate(app.navigationBars.buttons.element(boundBy: 0))
        activate(app.buttons["appSettings"])
        activate(app.buttons["defaultReaderSettings"])
        XCTAssertTrue(app.sliders["Font size"].waitForExistence(timeout: 5))
        try speech("Reader settings", service: voiceOver, containing: ["Font size", "Reader pace", "points per second"])
        activate(app.buttons["Done"])
        activate(app.navigationBars.buttons.element(boundBy: 0))
        openEditor(app, voiceOver: true)
        try speech("Trim editor", service: voiceOver, containing: ["Trim start", "Trim end"])
        activate(app.buttons["editCrop"])
        XCTAssertTrue(app.buttons["cropPreset_custom"].waitForExistence(timeout: 5))
        activate(app.buttons["cropPreset_custom"])
        try speech("Custom crop", service: voiceOver, containing: ["crop corner", "Crop position", "percent"])
    }

    @MainActor func testNativeAccessibilityAudit() throws {
        // Xcode's all-types audit can enable VoiceOver while inspecting a screen.
        let restoreVoiceOver: () -> Void
        if #available(iOS 27.0, *) {
            let service = XCUIDevice.shared.voiceOverService
            let wasEnabled = service.isEnabled
            restoreVoiceOver = { if !wasEnabled { try? service.disable() } }
            addTeardownBlock { @MainActor in if !wasEnabled { try service.disable() } }
        } else { restoreVoiceOver = {} }
        defer { restoreVoiceOver() }
        let app = launch()
        XCTAssertTrue(app.buttons["trySampleScript"].waitForExistence(timeout: 10))
        try audit("Scripts", app)
        app.buttons["trySampleScript"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        try audit("Script editor", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["appSettings"].tap()
        app.buttons["defaultReaderSettings"].tap()
        XCTAssertTrue(app.sliders["Font size"].waitForExistence(timeout: 5))
        try audit("Reader settings", app)
        app.buttons["Done"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openEditor(app)
        try audit("Trim editor", app)
        app.buttons["editCrop"].tap()
        XCTAssertTrue(app.buttons["cropPreset_custom"].waitForExistence(timeout: 5))
        app.buttons["cropPreset_custom"].tap()
        try audit("Custom crop", app)
        app.buttons["applyCrop"].tap()
        let export = app.buttons["exportMP4"]; reveal(export, app); export.tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'MP4 ready'"), object: app.staticTexts["mp4ExportStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        try audit("MP4 delivery", app)
    }

    @available(iOS 27.0, *)
    @MainActor private func speech(_ name: String, service: XCUIVoiceOverService, containing expected: [String]) throws {
        var utterances: [String] = [try service.currentSpeech().utterance]
        func hasExpected() -> Bool {
            expected.allSatisfy { term in utterances.contains { $0.localizedCaseInsensitiveContains(term) } }
        }
        // Focus can start at a previously selected control midway through a
        // screen. Check both directions; VoiceOver does not wrap at the ends.
        var repeats = 0
        for _ in 0..<32 {
            let value = try service.moveForward().utterance
            repeats = utterances.last == value ? repeats + 1 : 0
            utterances.append(value)
            // During modal transitions the service may briefly return its old
            // focus. Require four repeats before treating this as a boundary.
            if hasExpected() || repeats >= 4 { break }
        }
        if !hasExpected() {
            repeats = 0
            for _ in 0..<32 {
                let value = try service.moveBackward().utterance
                repeats = utterances.last == value ? repeats + 1 : 0
                utterances.append(value)
                if hasExpected() || repeats >= 4 { break }
            }
        }
        let text = utterances.joined(separator: "\n")
        let attachment = XCTAttachment(string: text)
        attachment.name = "P6C VoiceOver \(name)"; attachment.lifetime = .keepAlways; add(attachment)
        for term in expected { XCTAssertTrue(text.localizedCaseInsensitiveContains(term), "\(name): missing \(term)\n\(text)") }
    }

    @MainActor private func audit(_ name: String, _ app: XCUIApplication) throws {
        var findings: [[String: String]] = []
        let structuralTypes: XCUIAccessibilityAuditType = [.hitRegion, .elementDetection, .sufficientElementDescription, .trait]
        var structuralFindings: [String] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            findings.append(["type": String(issue.auditType.rawValue), "summary": issue.compactDescription,
                             "detail": issue.detailedDescription, "element": issue.element?.debugDescription ?? "none"])
            if !issue.auditType.intersection(structuralTypes).isEmpty {
                structuralFindings.append(issue.compactDescription + ": " + (issue.element?.label ?? "unknown"))
            }
            return true // Retain every finding; contrast/type/clipping require visual triage.
        }
        let data = try JSONSerialization.data(withJSONObject: findings, options: [.prettyPrinted, .sortedKeys])
        let report = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        report.name = "P6C Audit \(name)"; report.lifetime = .keepAlways; add(report)
        XCTAssertTrue(structuralFindings.isEmpty, "\(name): \(structuralFindings)")
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "P6C \(name)"; image.lifetime = .keepAlways; add(image)
    }

    @MainActor private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())", "--p4b-stage-crop-fixtures"]
        app.launchSkippingIntroduction(); return app
    }
    @MainActor private func openEditor(_ app: XCUIApplication, voiceOver: Bool = false) {
        if voiceOver { activate(app.buttons["videosTab"]) } else { app.buttons["videosTab"].tap() }
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10)); if voiceOver { activate(search) } else { search.tap() }; search.typeText("Crop sample 0\n")
        let row = app.buttons["video_C40B0000-0000-4000-8000-000000000001"]
        reveal(row, app); if voiceOver { activate(row) } else { row.tap() }
        let edit = app.buttons["editVideo"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); reveal(edit, app); if voiceOver { activate(edit) } else { edit.tap() }
        XCTAssertTrue(app.buttons["exportMP4"].waitForExistence(timeout: 10))
    }
    @MainActor private func activate(_ element: XCUIElement) {
        // A single tap explores; a subsequent double tap activates VoiceOver focus.
        element.tap()
        element.doubleTap()
    }
    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<10 where !element.isHittable {
            (app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? app).swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
}
