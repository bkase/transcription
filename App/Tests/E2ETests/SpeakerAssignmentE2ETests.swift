import XCTest

/// E2E tests for the speaker assignment feature.
/// Validates assigning a speaker and seeing it persist.
final class SpeakerAssignmentE2ETests: XCTestCase {
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

    /// Test that assigning a speaker persists when viewing the session.
    /// Flow: Timeline -> Record -> Stop -> Open session -> Tap speaker label -> Assign person -> Verify label changed
    func testAssignSpeakerPersists() {
        // 1. Launch the app
        app.launch()

        // 2. Verify we're on the Timeline screen
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")

        // 3. Start a recording to create a session with transcript segments
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startRecordingButton.tap()

        // 4. Wait for recording screen and some segments to appear
        let stopRecordingButton = app.buttons["stopRecordingButton"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 5), "Stop recording button should appear")

        // Wait for at least one transcript segment to appear
        let transcriptSegmentPredicate = NSPredicate(format: "identifier == 'transcriptSegment'")
        let transcriptSegments = app.descendants(matching: .any).matching(transcriptSegmentPredicate)
        XCTAssertTrue(transcriptSegments.firstMatch.waitForExistence(timeout: 10), "Transcript segment should appear during recording")

        // 5. Stop the recording
        stopRecordingButton.tap()

        // 6. Wait for timeline to show with the new session
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 10), "Should return to timeline")

        // 7. Find and tap the session card
        let sessionCardPredicate = NSPredicate(format: "identifier == 'sessionCard'")
        let sessionCards = app.descendants(matching: .any).matching(sessionCardPredicate)
        let sessionCardExists = sessionCards.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(sessionCardExists, "Session card should appear in timeline")
        sessionCards.firstMatch.tap()

        // 8. Verify session detail screen appears
        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should appear on session detail screen")

        // Wait for transcript segments to load in session detail
        let sessionDetailSegmentPredicate = NSPredicate(format: "identifier == 'transcriptSegment'")
        let sessionDetailSegments = app.descendants(matching: .any).matching(sessionDetailSegmentPredicate)
        XCTAssertTrue(sessionDetailSegments.firstMatch.waitForExistence(timeout: 10), "Transcript segments should appear in session detail")

        // 9. Tap the transcript segment to open the speaker picker
        // Since the speaker label button is nested inside the TranscriptSegment,
        // XCUITest detects the entire segment as a button. Tap near the top-left
        // where the speaker label is located.
        sessionDetailSegments.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()

        // 10. Verify speaker picker modal appears
        let addNewPersonOption = app.buttons["addNewPersonOption"]
        XCTAssertTrue(addNewPersonOption.waitForExistence(timeout: 5), "Add new person option should appear in speaker picker")

        // 11. Tap "Add new person" to create a new person
        addNewPersonOption.tap()

        // 12. Enter a name for the new person
        let nameInput = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'newPersonNameInput'")).firstMatch
        XCTAssertTrue(nameInput.waitForExistence(timeout: 5), "Name input should appear")

        // Find the text field inside the name input and type
        let textField = nameInput.textFields.firstMatch
        if textField.exists {
            textField.tap()
            textField.typeText("Alice")
        } else {
            // Try finding any text field in the modal
            let anyTextField = app.textFields.firstMatch
            if anyTextField.waitForExistence(timeout: 2) {
                anyTextField.tap()
                anyTextField.typeText("Alice")
            }
        }

        // 13. Save the new person
        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Save'")).firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should appear")
        saveButton.tap()

        // 14. Wait for person to be created and shown in picker list
        // After saving, the new person is selected and we can confirm
        let confirmButton = app.buttons["confirmSelectionButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Confirm button should appear after selecting a person")
        confirmButton.tap()

        // 15. Wait for modal to dismiss
        // First wait for the modal to dismiss (back button should be visible again without obstruction)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Modal should dismiss")

        // 16. Navigate back to timeline and re-open the session to verify persistence
        // This forces a full reload of the session data
        backButton.tap()
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Should return to timeline")

        // Tap the session again
        XCTAssertTrue(sessionCards.firstMatch.waitForExistence(timeout: 5), "Session card should still exist")
        sessionCards.firstMatch.tap()

        // 17. Verify the speaker assignment persisted
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should appear again")

        // Wait for segments to load
        XCTAssertTrue(sessionDetailSegments.firstMatch.waitForExistence(timeout: 10), "Segments should load")

        // Now check that "ALICE" appears (speaker label should show the assigned name)
        // Since the speaker label is inside a Button, we need to search all descendants
        let aliceTextPredicate = NSPredicate(format: "label CONTAINS[c] 'ALICE'")
        let aliceElements = app.descendants(matching: .any).matching(aliceTextPredicate)
        XCTAssertTrue(aliceElements.firstMatch.waitForExistence(timeout: 5), "Speaker label should show 'ALICE' after re-opening session")
    }
}
