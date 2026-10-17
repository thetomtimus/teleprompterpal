import XCTest

final class PrototypeFlowTests: XCTestCase {
    @MainActor func testSampleTakeCanBeCroppedAndExportedAsMP4() {
        let app = XCUIApplication()
        app.launchArguments = ["--p2-test-root=\(UUID().uuidString)"]
        app.launch()
        let sample = app.buttons["sampleTake"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        let export = app.buttons["exportMP4"]
        XCTAssertTrue(export.waitForExistence(timeout: 30))
        app.segmentedControls["cropPicker"].buttons["1:1"].tap()
        app.sliders["trimStart"].adjust(toNormalizedSliderPosition: 0.2)
        export.tap()
        XCTAssertTrue(app.buttons["shareMP4"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["exportStatus"].label.contains("MP4 ready"))
        app.buttons["Done"].tap()
        let prompt = app.buttons["togglePrompt"]
        prompt.tap()
        XCTAssertTrue(prompt.label.contains("Pause"))
        prompt.tap()
        XCTAssertTrue(prompt.label.contains("Play"))
    }
}
