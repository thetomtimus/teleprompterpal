import XCTest

extension XCUIApplication {
    /// Existing phase regressions enter their isolated library directly. The
    /// separate P6B journeys exercise real first-use completion and replay.
    @MainActor func launchSkippingIntroduction() {
        if !launchArguments.contains("--p6b-skip-onboarding") { launchArguments.append("--p6b-skip-onboarding") }
        launch()
    }

    @MainActor func openRehearsal() {
        let actions = buttons["scriptActions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        buttons["openReader"].tap()
    }
}
