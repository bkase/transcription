import XCTest

/// E2E tests for error state flows.
/// Validates model download failure and offline transcription failure states.
final class ErrorStatesE2ETests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Model Download Failure Tests

    /// Test that model download failure shows error state on empty timeline.
    /// When models fail to download and there are no sessions, the empty state shows "Unable to connect".
    func testModelDownloadFailure_EmptyTimeline() {
        // Launch with model download failure scenario
        app.launchArguments = ["-uiTesting", "-modelDownloadFailure"]
        app.launch()

        // Verify timeline tab exists
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")

        // Verify empty state shows error variant
        let emptyStateTitlePredicate = NSPredicate(format: "identifier == 'emptyStateTitle'")
        let emptyStateTitle = app.descendants(matching: .staticText).matching(emptyStateTitlePredicate).firstMatch
        XCTAssertTrue(emptyStateTitle.waitForExistence(timeout: 5), "Empty state title should exist")
        XCTAssertEqual(emptyStateTitle.label, "Unable to connect", "Empty state should show 'Unable to connect' when models fail to download")

        // Verify empty state description mentions connection
        let emptyStateDescPredicate = NSPredicate(format: "identifier == 'emptyStateDescription'")
        let emptyStateDesc = app.descendants(matching: .staticText).matching(emptyStateDescPredicate).firstMatch
        XCTAssertTrue(emptyStateDesc.waitForExistence(timeout: 2), "Empty state description should exist")
        XCTAssertTrue(emptyStateDesc.label.contains("Check your connection"), "Description should mention connection")

        // Verify record button is disabled (models not ready)
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 2), "Start recording button should exist")
        XCTAssertFalse(startRecordingButton.isEnabled, "Record button should be disabled when models failed to download")

        // Verify status text shows error
        let statusPredicate = NSPredicate(format: "identifier == 'emptyStateStatus'")
        let statusText = app.descendants(matching: .staticText).matching(statusPredicate).firstMatch
        XCTAssertTrue(statusText.waitForExistence(timeout: 2), "Status text should exist in error state")
        XCTAssertEqual(statusText.label, "Something went wrong", "Status text should show error message")
    }

    // MARK: - Transcription Failure Tests (Partial State)

    /// Test that offline transcription failure after recording shows partial state in session detail.
    /// When live transcription produces segments but offline fails, the session shows "partial" banner.
    /// Flow: Record -> Stop -> Session with partial state -> See partial banner + transcript segments
    func testTranscriptionFailure_SessionShowsPartialState() {
        // Launch with transcription failure scenario
        // Note: The mock script produces live segments, so offline failure results in "partial" state, not "failed"
        app.launchArguments = ["-uiTesting", "-transcriptionFailure"]
        app.launch()

        // Verify timeline exists
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")

        // Start recording
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startRecordingButton.tap()

        // Wait for recording screen
        let stopRecordingButton = app.buttons["stopRecordingButton"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 5), "Stop recording button should appear")

        // Stop recording
        stopRecordingButton.tap()

        // Wait for session detail to appear (navigation after recording completes)
        let sessionTitle = app.staticTexts["sessionTitle"]
        XCTAssertTrue(sessionTitle.waitForExistence(timeout: 15), "Should navigate to session detail after recording stops")

        // Verify partial banner is shown (since live segments exist but offline transcription failed)
        let partialBannerPredicate = NSPredicate(format: "identifier == 'partialBanner'")
        let partialBanner = app.descendants(matching: .any).matching(partialBannerPredicate).firstMatch
        XCTAssertTrue(partialBanner.waitForExistence(timeout: 10), "Partial banner should appear when offline transcription fails but live segments exist")

        // Verify transcript segments are displayed (from live transcription)
        let transcriptSegmentPredicate = NSPredicate(format: "identifier == 'transcriptSegment'")
        let transcriptSegments = app.descendants(matching: .any).matching(transcriptSegmentPredicate)
        XCTAssertTrue(transcriptSegments.firstMatch.waitForExistence(timeout: 5), "Transcript segments should be shown from live transcription")
    }
}
