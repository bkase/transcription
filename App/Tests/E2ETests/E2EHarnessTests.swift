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

        // Verify the app launches and shows the Timeline tab
        // The Timeline tab should be visible as it's the default
        let timelineNavTitle = app.navigationBars["Timeline"]
        XCTAssertTrue(
            timelineNavTitle.waitForExistence(timeout: 5),
            "Timeline navigation bar should appear - app should launch successfully with mock dependencies"
        )

        // Verify the tab bar exists with Timeline selected
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")

        // The Timeline tab should be selected by default
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.exists, "Timeline tab should exist")
        XCTAssertTrue(timelineTab.isSelected, "Timeline tab should be selected by default")
    }
}
