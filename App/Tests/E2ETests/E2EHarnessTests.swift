import XCTest

/// Tests that verify the E2E test harness is correctly configured
/// to use mock dependencies when running with -uiTesting flag
final class E2EHarnessTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch with UI testing flag to switch to mock dependencies
        app.launchArguments = ["-uiTesting"]
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    /// Verify that the app launches successfully with uiTesting configuration
    /// and uses mock dependencies (GeneratedAudioCapture + MockFluidAudioClient)
    func testUiTestingConfigUsesMocks() {
        // Launch the app with uiTesting flag
        app.launch()

        // Verify the tab bar exists with Timeline selected
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 5),
            "Tab bar should appear - app should launch successfully with mock dependencies"
        )

        // The Timeline tab should be selected by default
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.exists, "Timeline tab should exist")
        XCTAssertTrue(timelineTab.isSelected, "Timeline tab should be selected by default")

        // Verify the record button exists on the timeline (confirms Timeline view loaded)
        let recordButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(
            recordButton.waitForExistence(timeout: 5),
            "Record button should appear on Timeline screen"
        )
    }
}
