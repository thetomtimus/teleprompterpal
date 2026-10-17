import XCTest

final class P6BReferenceFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testFiveStepOnboardingCompletionRelaunchAndReplay() {
        let app = launch()
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 15))
        capture("P6B Onboarding Welcome")
        for name in ["Confidence", "Prompt", "Quality"] {
            app.buttons["onboardingContinue"].tap()
            XCTAssertTrue(app.staticTexts["onboardingHeadline"].waitForExistence(timeout: 5))
            capture("P6B Onboarding \(name)")
        }
        app.buttons["onboardingContinue"].tap()
        XCTAssertTrue(app.staticTexts["I’m ready to"].waitForExistence(timeout: 5))
        let commit = app.buttons["onboardingContinue"]
        XCTAssertTrue(commit.exists)
        XCTAssertTrue(commit.isHittable)
        XCTAssertFalse(commit.isEnabled)
        XCTAssertTrue(app.staticTexts["Check all three boxes, then tap Commit."].exists)
        XCTAssertEqual(app.staticTexts["onboardingGoalCount"].label, "0 of 3 checked")
        capture("P6B Onboarding Commit Unchecked")
        chooseGoals(app)
        XCTAssertTrue(commit.isEnabled)
        XCTAssertEqual(app.staticTexts["onboardingGoalCount"].label, "3 of 3 checked")
        XCTAssertFalse(app.staticTexts["onboardingCommitted"].exists)
        let lastGoal = app.buttons["Keep showing up for my ideas"]
        lastGoal.tap()
        XCTAssertFalse(commit.isEnabled)
        XCTAssertEqual(app.staticTexts["onboardingGoalCount"].label, "2 of 3 checked")
        lastGoal.tap()
        XCTAssertTrue(commit.isEnabled)
        capture("P6B Onboarding Commit Checked")
        commit.tap()
        let burst = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        burst.name = "P6B Commit Burst"; burst.lifetime = .keepAlways; add(burst)
        XCTAssertTrue(app.buttons["recordFromLibrary"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).count, 1)
        capture("P6B Scripts")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["recordFromLibrary"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboardingContinue"].exists)
        app.buttons["appSettings"].tap()
        XCTAssertTrue(app.buttons["replayOnboarding"].waitForExistence(timeout: 5))
        app.buttons["replayOnboarding"].tap()
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 5))
        app.buttons["onboardingSkip"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).count, 1)
    }

    @MainActor func testEditorDirectCameraToolsLandscapeAndSavedPreferences() {
        let app = launch(skip: true, illustration: true)
        XCTAssertTrue(app.buttons["trySampleScript"].waitForExistence(timeout: 10))
        app.buttons["trySampleScript"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        let original = app.textViews["scriptText"].value as? String
        capture("P6B Script Editor")
        app.buttons["recordFromEditor"].tap()
        XCTAssertTrue(app.buttons["promptSize"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["simulatorPreviewLabel"].exists)
        XCTAssertFalse(app.buttons["recordTake"].isEnabled)
        XCTAssertEqual(app.buttons["togglePrompt"].label, "Play text")
        app.buttons["promptSize"].tap()
        XCTAssertTrue(app.sliders["Prompt font"].waitForExistence(timeout: 5))
        app.sliders["Prompt font"].adjust(toNormalizedSliderPosition: 0.35)
        let savedFont = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' pt'")).firstMatch.label
        capture("P6B Size Controls"); app.buttons["Done"].tap()
        app.buttons["promptSpeed"].tap()
        XCTAssertTrue(app.sliders["Prompt pace"].waitForExistence(timeout: 5))
        app.sliders["Prompt pace"].adjust(toNormalizedSliderPosition: 0.1)
        capture("P6B Speed Controls"); app.buttons["Done"].tap()
        app.buttons["readerSettings"].tap()
        let opacity = app.sliders["Prompt background opacity"]
        reveal(opacity, in: app)
        XCTAssertTrue(opacity.exists)
        opacity.adjust(toNormalizedSliderPosition: 0)
        let alignment = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Alignment'")).firstMatch
        for _ in 0..<4 where !alignment.isHittable { app.scrollViews.firstMatch.swipeDown() }
        alignment.tap(); app.buttons["Center"].tap()
        capture("P6B Background Controls"); app.buttons["Done"].tap()
        capture("P6B Camera Portrait")
        app.buttons["cameraOptions"].tap()
        XCTAssertTrue(app.staticTexts["1080p · 30 fps · SDR"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No time limit · about 2 GB free to start"].exists)
        capture("P6B Camera Settings"); app.buttons["Done"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("P6B Camera Landscape")
        XCTAssertTrue(app.buttons["promptSize"].isHittable)
        XCTAssertTrue(app.buttons["recordTake"].exists)
        app.buttons["closeReader"].tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["scriptText"].value as? String, original)
        capture("P6B Editor Landscape")
        XCUIDevice.shared.orientation = .portrait
        app.openRehearsal()
        XCTAssertTrue(app.buttons["togglePrompt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recordTake"].exists)
        app.buttons["closeReader"].tap()
        app.terminate(); app.launch()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        app.buttons["recordFromEditor"].tap()
        XCTAssertTrue(app.buttons["promptSize"].waitForExistence(timeout: 10)); app.buttons["promptSize"].tap()
        XCTAssertTrue(app.staticTexts[savedFont].waitForExistence(timeout: 5))
    }

    @MainActor func testAccessibilityOnboardingAndLibrary() {
        let app = launch(accessible: true)
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 15))
        capture("P6B Welcome Accessibility")
        for _ in 0..<4 { app.buttons["onboardingContinue"].tap() }
        XCTAssertTrue(app.buttons["onboardingContinue"].exists)
        XCTAssertFalse(app.buttons["onboardingContinue"].isEnabled)
        capture("P6B Commitment Unchecked Accessibility")
        chooseGoals(app)
        XCTAssertTrue(app.buttons["onboardingContinue"].isEnabled)
        capture("P6B Commitment Accessibility")
        app.buttons["onboardingContinue"].tap()
        XCTAssertTrue(app.buttons["recordFromLibrary"].waitForExistence(timeout: 5))
        capture("P6B Scripts Accessibility")
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'script_'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(app.textViews["scriptText"].waitForExistence(timeout: 5))
        capture("P6B Editor Accessibility")
        app.buttons["recordFromEditor"].tap()
        XCTAssertTrue(app.buttons["promptSize"].waitForExistence(timeout: 10))
        capture("P6B Camera Accessibility")
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.exists || !element.isHittable { app.scrollViews.firstMatch.swipeUp() }
    }

    @MainActor private func chooseGoals(_ app: XCUIApplication) {
        for title in ["Feel confident when I press record", "Create a take I’m proud to share", "Keep showing up for my ideas"] {
            let goal = app.buttons[title]
            XCTAssertTrue(goal.waitForExistence(timeout: 5))
            for _ in 0..<6 where !goal.isHittable || goal.frame.maxY > app.buttons["onboardingContinue"].frame.minY - 38 {
                app.scrollViews.firstMatch.swipeUp()
            }
            goal.tap()
        }
    }

    @MainActor private func launch(skip: Bool = false, illustration: Bool = false, accessible: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID())"]
        if skip { app.launchArguments.append("--p6b-skip-onboarding") }
        if illustration || accessible { app.launchArguments.append("--p6b-camera-preview-fixture") }
        if accessible { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); return app
    }
    @MainActor private func capture(_ name: String) {
        let settled = expectation(description: "Transition settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 4), .completed)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
