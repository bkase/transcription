import XCTest

/// E2E tests for left alignment in session detail view.
/// Validates that back button, title, and transcript elements align flush left.
final class LeftAlignmentE2ETests: XCTestCase {
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

    /// Test that elements in session detail view are left-aligned.
    /// Verifies back button, title, and transcript segments share the same left edge.
    func testSessionDetailLeftAlignment() {
        // 1. Launch the app
        app.launch()

        // 2. Start a recording to create a session
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startRecordingButton.tap()

        // 3. Wait for recording screen and stop
        let stopRecordingButton = app.buttons["stopRecordingButton"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 5), "Stop recording button should appear")
        stopRecordingButton.tap()

        // 4. Wait for session detail screen to appear
        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "Back button should appear on session detail screen")

        // 5. Wait for session title to appear
        let sessionTitle = app.staticTexts["sessionTitle"]
        XCTAssertTrue(sessionTitle.waitForExistence(timeout: 5), "Session title should appear")

        // 6. Wait for transcript segment to appear
        let transcriptSegmentPredicate = NSPredicate(format: "identifier == 'transcriptSegment'")
        let transcriptSegments = app.descendants(matching: .any).matching(transcriptSegmentPredicate)
        let firstSegment = transcriptSegments.firstMatch
        XCTAssertTrue(firstSegment.waitForExistence(timeout: 5), "Transcript segment should appear")

        // 7. Get the left edge (minX) of each element
        let backButtonMinX = backButton.frame.minX
        let sessionTitleMinX = sessionTitle.frame.minX
        let transcriptMinX = firstSegment.frame.minX

        // 8. Verify alignment - all elements should have the same left edge
        // Allow a 2-point tolerance for rounding differences
        let tolerance: CGFloat = 2.0

        XCTAssertEqual(
            backButtonMinX, sessionTitleMinX,
            accuracy: tolerance,
            "Back button (\(backButtonMinX)) and title (\(sessionTitleMinX)) should be left-aligned"
        )
        XCTAssertEqual(
            sessionTitleMinX, transcriptMinX,
            accuracy: tolerance,
            "Title (\(sessionTitleMinX)) and transcript (\(transcriptMinX)) should be left-aligned"
        )
    }
}
