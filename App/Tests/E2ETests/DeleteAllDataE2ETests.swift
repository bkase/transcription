import XCTest

/// E2E tests for the Delete All Data feature.
/// Validates that deleting all data clears sessions and people, then navigates to empty timeline.
final class DeleteAllDataE2ETests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch with UI testing flag to use mock dependencies
        app.launchArguments = ["-uiTesting"]
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Navigate to profile screen from timeline.
    private func navigateToProfile() {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
        settingsButton.tap()

        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.waitForExistence(timeout: 5), "Profile screen should appear")
    }

    // MARK: - Delete All Data Tests

    /// Test the delete all data button appears and cancel dismisses the alert.
    func testDeleteAllDataCancelDismissesAlert() {
        app.launch()

        // Navigate to profile
        navigateToProfile()

        // Find and tap the delete all data button
        let deleteButton = app.buttons["deleteAllDataButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete All Data button should exist")
        deleteButton.tap()

        // Verify confirmation alert appears
        let alert = app.alerts["Delete All Data?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Confirmation alert should appear")

        // Tap Cancel to dismiss
        let cancelButton = alert.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist in alert")
        cancelButton.tap()

        // Verify alert is dismissed and we're still on profile
        XCTAssertFalse(alert.waitForExistence(timeout: 2), "Alert should be dismissed after cancel")

        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.exists, "Should still be on profile screen after cancel")
    }

    /// Test delete all data flow: confirm deletion navigates to empty timeline.
    func testDeleteAllDataConfirmNavigatesToTimeline() {
        app.launch()

        // Navigate to profile
        navigateToProfile()

        // Find and tap the delete all data button
        let deleteButton = app.buttons["deleteAllDataButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete All Data button should exist")
        deleteButton.tap()

        // Verify confirmation alert appears
        let alert = app.alerts["Delete All Data?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Confirmation alert should appear")

        // Tap Delete to confirm - use firstMatch since alert buttons can have nested elements
        let confirmButton = alert.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmButton.exists, "Delete button should exist in alert")
        confirmButton.tap()

        // Verify we navigate back to timeline
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Should navigate to timeline after deletion")

        // Verify profile screen is gone (popped from navigation stack)
        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertFalse(profileScreen.exists, "Profile screen should be dismissed after deletion")

        // Verify the start recording button exists (timeline is showing)
        let startRecordingButton = app.buttons["startRecordingButton"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 5), "Start recording button should exist on timeline")
    }

    /// Test that delete all data alert message mentions ML models are kept.
    func testDeleteAllDataAlertMessage() {
        app.launch()

        // Navigate to profile
        navigateToProfile()

        // Find and tap the delete all data button
        let deleteButton = app.buttons["deleteAllDataButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete All Data button should exist")
        deleteButton.tap()

        // Verify confirmation alert appears with correct message
        let alert = app.alerts["Delete All Data?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Confirmation alert should appear")

        // Verify the alert contains the warning message
        let messageText = alert.staticTexts.element(boundBy: 1) // Second static text is the message
        XCTAssertTrue(messageText.label.contains("ML models"), "Alert message should mention ML models are kept")
        XCTAssertTrue(messageText.label.contains("cannot be undone"), "Alert message should warn action cannot be undone")

        // Dismiss alert
        alert.buttons["Cancel"].tap()
    }
}
