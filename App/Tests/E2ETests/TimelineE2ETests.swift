import XCTest

/// E2E tests for the record-to-timeline flow.
/// Validates that a recording session appears in the timeline after completion.
final class TimelineE2ETests: XCTestCase {
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

    /// Test that empty state shows "Ready to record" when models are ready.
    /// Since mock dependencies start with models ready, the ready state should show.
    func testEmptyStateShowsReadyToRecord() {
        // 1. Launch the app
        app.launch()

        // 2. Verify we're on the Timeline screen
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")

        // 3. Verify empty state elements
        let emptyStateTitlePredicate = NSPredicate(format: "identifier == 'emptyStateTitle'")
        let emptyStateTitle = app.descendants(matching: .staticText).matching(emptyStateTitlePredicate).firstMatch
        XCTAssertTrue(emptyStateTitle.waitForExistence(timeout: 5), "Empty state title should exist")
        XCTAssertEqual(emptyStateTitle.label, "Ready to record", "Empty state should show 'Ready to record' when models are ready")

        // 4. Verify empty state description
        let emptyStateDescPredicate = NSPredicate(format: "identifier == 'emptyStateDescription'")
        let emptyStateDesc = app.descendants(matching: .staticText).matching(emptyStateDescPredicate).firstMatch
        XCTAssertTrue(emptyStateDesc.waitForExistence(timeout: 2), "Empty state description should exist")
        XCTAssertTrue(emptyStateDesc.label.contains("first transcription"), "Description should mention first transcription")

        // 5. Verify record button is enabled (models ready)
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 2), "Start recording button should exist")
        XCTAssertTrue(startRecordingButton.isEnabled, "Record button should be enabled when models are ready")

        // 6. Verify no status text below FAB (only shown for downloading/error states)
        let statusPredicate = NSPredicate(format: "identifier == 'emptyStateStatus'")
        let statusText = app.descendants(matching: .staticText).matching(statusPredicate).firstMatch
        XCTAssertFalse(statusText.exists, "Status text should not exist in ready state")
    }

    /// Test that completing a recording creates a session that appears in the timeline.
    /// Flow: Timeline -> Tap Record -> Recording starts -> Stop recording -> Session appears in timeline
    func testRecordCreatesTimelineSession() {
        // 1. Launch the app
        app.launch()

        // 2. Verify we're on the Timeline screen
        // The Timeline tab should be selected by default
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")
        XCTAssertTrue(timelineTab.isSelected, "Timeline tab should be selected by default")

        // 3. Verify timeline is empty initially (no session cards)
        let sessionCardsPredicate = NSPredicate(format: "identifier == 'sessionCard'")
        let sessionCardsBefore = app.descendants(matching: .any).matching(sessionCardsPredicate)
        XCTAssertEqual(sessionCardsBefore.count, 0, "Timeline should be empty initially")

        // 4. Tap the record button to start recording
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist on timeline")
        startRecordingButton.tap()

        // 5. Verify recording screen appears with the stop button
        let stopRecordingButton = app.buttons["stopRecordingButton"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 5), "Stop recording button should appear on recording screen")

        // 6. Wait for mock transcription to produce segments (the mock has a scripted conversation)
        // The mock audio capture is 2 seconds, so we wait a bit for the recording to process
        // No sleep - use XCUITest's built-in waiting

        // 7. Stop the recording
        stopRecordingButton.tap()

        // 8. Wait for recording to finish and timeline to reappear
        // The recording should dismiss and show timeline with the new session
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 10), "Should return to timeline after recording stops")

        // 9. Verify the session card appears in the timeline
        // Use a predicate query to find any session card
        let sessionCardsAfter = app.descendants(matching: .any).matching(sessionCardsPredicate)
        let sessionCardExists = sessionCardsAfter.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(sessionCardExists, "Session card should appear in timeline after recording completes")
        XCTAssertGreaterThan(sessionCardsAfter.count, 0, "At least one session card should be visible")
    }
}
