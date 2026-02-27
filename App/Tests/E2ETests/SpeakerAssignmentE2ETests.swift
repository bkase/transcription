import XCTest

/// E2E tests for the speaker assignment feature.
/// Validates assigning a speaker during recording and seeing it persist
/// in the session detail after Stop & Save triggers offline diarization.
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

    /// Test that assigning a speaker during recording persists after Stop & Save.
    ///
    /// Flow:
    /// 1. Start recording
    /// 2. Expand speaker setup → select 2 speakers
    /// 3. Tap Speaker 1 row → sheet opens
    /// 4. Create a new person "Alice" → confirm
    /// 5. Verify "Alice" appears in speaker setup card
    /// 6. Tap "Stop & Save"
    /// 7. Wait for session detail → verify "Alice" appears in transcript
    func testAssignSpeakerDuringRecordingPersists() throws {
        // 1. Launch the app
        app.launch()

        // 2. Verify we're on the Timeline screen
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")

        // 3. Start recording
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startRecordingButton.tap()

        // 4. Wait for recording screen - look for the speaker setup toggle
        let speakerSetupToggle = app.buttons["speakerSetupToggle"]
        XCTAssertTrue(speakerSetupToggle.waitForExistence(timeout: 5), "Speaker setup toggle should appear on recording screen")

        // 5. Expand speaker setup
        speakerSetupToggle.tap()

        // 6. Select speaker count 2
        let speakerCount2 = app.buttons["speakerCount2"]
        XCTAssertTrue(speakerCount2.waitForExistence(timeout: 3), "Speaker count 2 pill should appear")
        speakerCount2.tap()

        // 7. Wait for speaker rows to appear then tap Speaker 1 row
        let speakerRow0 = app.buttons["speakerRow0"]
        XCTAssertTrue(speakerRow0.waitForExistence(timeout: 5), "Speaker row 0 should appear after selecting count")
        speakerRow0.tap()

        // 8. Wait for the speaker picker sheet to appear
        let addNewPersonOption = app.buttons["addNewPersonOption"]
        XCTAssertTrue(addNewPersonOption.waitForExistence(timeout: 5), "Add new person option should appear in speaker picker sheet")

        // 9. Tap "Add new person" to open the create form
        addNewPersonOption.tap()

        // 10. Find the name text field and type "Alice"
        // SwiftUI TextField with placeholder "Name" - try multiple selectors
        let nameTextField = app.textFields["Name"]
        if nameTextField.waitForExistence(timeout: 5) {
            nameTextField.tap()
            nameTextField.typeText("Alice")
        } else {
            // Fallback: tap the newPersonNameInput container to focus the field
            let nameInput = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'newPersonNameInput'")).firstMatch
            XCTAssertTrue(nameInput.waitForExistence(timeout: 3), "Name input container should appear")
            nameInput.tap()
            // After tapping the container, try finding any text field
            let anyTextField = app.textFields.firstMatch
            XCTAssertTrue(anyTextField.waitForExistence(timeout: 3), "Text field should be focusable")
            anyTextField.typeText("Alice")
        }

        // 11. Tap "Save" to create the person
        // Use exact match to avoid hitting "Stop & Save"
        let saveButton = app.buttons.matching(NSPredicate(format: "label ==[c] 'Save'")).firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should appear")
        saveButton.tap()

        // 12. Wait for Confirm button and tap it
        let confirmButton = app.buttons["confirmSelectionButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Confirm button should appear after person is created and selected")
        confirmButton.tap()

        // 13. Wait for sheet to dismiss - speaker setup card should be visible again
        XCTAssertTrue(speakerRow0.waitForExistence(timeout: 5), "Speaker row should be visible after sheet dismisses")

        // 14. Verify "Alice" now appears in the speaker setup card
        let aliceInSetup = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Alice'")).firstMatch
        XCTAssertTrue(aliceInSetup.waitForExistence(timeout: 5), "Alice should appear as speaker name in setup card")

        // 15. Tap "Stop & Save" to stop recording with speaker count
        let stopAndSaveButton = app.buttons["stopAndSaveButton"]
        XCTAssertTrue(stopAndSaveButton.waitForExistence(timeout: 3), "Stop & Save button should be enabled")
        stopAndSaveButton.tap()

        // 16. Wait for session detail view to appear
        let sessionTitle = app.staticTexts["sessionTitle"]
        XCTAssertTrue(sessionTitle.waitForExistence(timeout: 10), "Should navigate to session detail after Stop & Save")

        // 17. Wait for offline transcription to complete
        // The session detail view polls for processing state changes.
        // With mock dependencies, offline transcription is nearly instant.
        // Wait for transcript segments to appear with speaker information.
        let aliceInDetail = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'Alice'")
        ).firstMatch
        XCTAssertTrue(aliceInDetail.waitForExistence(timeout: 15), "Alice should appear as speaker label in session detail after offline transcription")
    }
}
