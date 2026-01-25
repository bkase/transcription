import XCTest

/// E2E tests for the session detail feature.
/// Validates session detail navigation and content display.
final class SessionDetailE2ETests: XCTestCase {
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

    /// Test that opening a session from the timeline shows the session detail with transcript.
    /// Flow: Timeline -> Record -> Stop -> Tap session card -> Verify transcript and back button
    func testOpenSessionDetail() {
        // 1. Launch the app
        app.launch()

        // 2. Verify we're on the Timeline screen
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")

        // 3. Start a recording to create a session
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startRecordingButton.tap()

        // 4. Wait for recording screen and stop
        let stopRecordingButton = app.buttons["stopRecordingButton"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 5), "Stop recording button should appear")
        stopRecordingButton.tap()

        // 5. Wait for timeline to show with the new session
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 10), "Should return to timeline")

        // 6. Find and tap the session card
        let sessionCardPredicate = NSPredicate(format: "identifier == 'sessionCard'")
        let sessionCards = app.descendants(matching: .any).matching(sessionCardPredicate)
        let sessionCardExists = sessionCards.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(sessionCardExists, "Session card should appear in timeline")
        sessionCards.firstMatch.tap()

        // 7. Verify session detail screen appears with back button
        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should appear on session detail screen")

        // 8. Verify transcript segments are displayed
        // The mock FluidAudio script produces segments during recording
        let transcriptSegmentPredicate = NSPredicate(format: "identifier == 'transcriptSegment'")
        let transcriptSegments = app.descendants(matching: .any).matching(transcriptSegmentPredicate)
        let segmentExists = transcriptSegments.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(segmentExists, "Transcript segments should appear on session detail screen")

        // 9. Verify segment content contains expected text from mock script
        let helloTextPredicate = NSPredicate(format: "label CONTAINS 'Hello'")
        let helloText = app.staticTexts.matching(helloTextPredicate).firstMatch
        XCTAssertTrue(helloText.exists, "Segment text 'Hello' should be visible")

        // 10. Navigate back to timeline
        backButton.tap()
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Should return to timeline after tapping back")
    }
}
