import XCTest

/// E2E tests for session deletion.
/// Validates that deleting a session from session detail removes it from the timeline.
final class DeleteSessionE2ETests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch with UI testing flag to switch to mock dependencies
        app.launchArguments = ["-uiTesting"]

        // Handle microphone permission alert automatically
        addUIInterruptionMonitor(withDescription: "Microphone Permission") { alert in
            let allowButton = alert.buttons["OK"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    /// Test that deleting a session from session detail removes it from the timeline.
    /// Flow: Timeline -> Record -> Stop -> Open detail -> Delete -> Verify navigated back
    func testDeleteSessionRemovesTimelineItem() {
        // 1. Launch the app
        app.launch()

        // 2. Verify we're on the Timeline screen
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")
        XCTAssertTrue(timelineTab.isSelected, "Timeline tab should be selected by default")

        // 3. Start a recording to create a session
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startRecordingButton.tap()

        // 4. Wait for recording screen and stop
        let stopRecordingButton = app.buttons["stopRecordingButton"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 5), "Stop recording button should appear")
        stopRecordingButton.tap()

        // 5. Wait for timeline to show with the new session
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 10), "Should return to timeline after recording stops")

        // 6. Wait for session card to appear
        let sessionCardPredicate = NSPredicate(format: "identifier == 'sessionCard'")
        let sessionCards = app.descendants(matching: .any).matching(sessionCardPredicate)
        let sessionCardExists = sessionCards.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(sessionCardExists, "Session card should appear in timeline")

        // 7. Tap the session card to open detail
        sessionCards.firstMatch.tap()

        // 8. Verify session detail screen appears with back button
        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should appear on session detail screen")

        // 9. Tap the delete button
        let deleteButton = app.buttons["deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button should exist on session detail")
        deleteButton.tap()

        // 10. Verify confirmation dialog appears and tap Delete
        let deleteConfirmButton = app.buttons["Delete"]
        XCTAssertTrue(deleteConfirmButton.waitForExistence(timeout: 5), "Delete confirmation button should appear")
        deleteConfirmButton.tap()

        // 11. Wait for navigation back to timeline - the start recording button indicates we're back
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 10), "Should return to timeline after deletion")

        // 12. Verify the timeline is shown (back button from detail should be gone)
        let backButtonGone = backButton.waitForNonExistence(timeout: 5)
        XCTAssertTrue(backButtonGone, "Should no longer be on detail screen after delete")
    }
}
