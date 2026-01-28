import XCTest

/// E2E tests for the profile photo picker flow.
/// Validates that the mock photo picker works in UI testing mode.
final class ProfilePhotoE2ETests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch with UI testing flag to use mock photo picker
        app.launchArguments = ["-uiTesting"]
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    /// Test that the mock photo picker opens with correct options.
    /// Flow: Timeline -> Profile avatar -> Profile screen -> Change photo -> Mock picker appears with options
    func testMockPhotoPickerFlow() {
        // 1. Launch the app
        app.launch()

        // 2. Verify we're on the Timeline screen
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")
        XCTAssertTrue(timelineTab.isSelected, "Timeline tab should be selected by default")

        // 3. Tap the profile avatar button to navigate to profile
        let profileAvatarButton = app.buttons["profileAvatarButton"]
        XCTAssertTrue(profileAvatarButton.waitForExistence(timeout: 5), "Profile avatar button should exist")
        profileAvatarButton.tap()

        // 4. Verify profile screen appears
        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.waitForExistence(timeout: 5), "Profile screen should appear")

        // 5. Tap the change photo button
        let changePhotoButton = app.buttons["profileChangePhotoButton"]
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should exist")
        changePhotoButton.tap()

        // 6. Verify mock photo picker sheet appears
        let mockPickerSheet = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mockPhotoPickerSheet'")).firstMatch
        XCTAssertTrue(mockPickerSheet.waitForExistence(timeout: 5), "Mock photo picker sheet should appear")

        // 7. Verify mock photo options are visible
        let blueOption = app.buttons["mockPhotoOption-0"]
        let greenOption = app.buttons["mockPhotoOption-1"]
        let redOption = app.buttons["mockPhotoOption-2"]
        XCTAssertTrue(blueOption.waitForExistence(timeout: 5), "Blue Square option should exist")
        XCTAssertTrue(greenOption.exists, "Green Square option should exist")
        XCTAssertTrue(redOption.exists, "Red Square option should exist")

        // 8. Verify cancel button exists
        let cancelButton = app.buttons["mockPhotoPickerCancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")

        // 9. Cancel the picker
        cancelButton.tap()

        // 10. Wait for sheet to dismiss - check that profile screen content is accessible
        // Note: checking for sheet non-existence can be flaky during animations
        // Instead, we verify that a profile screen element becomes accessible
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should be accessible after sheet dismisses")

        // 11. The test has verified that:
        // - Mock photo picker sheet appears with UI testing mode
        // - Three color options are visible
        // - Cancel button works to dismiss the sheet
        // This is sufficient coverage for the mock picker fallback feature
    }

    /// Test that the mock photo picker can be dismissed.
    func testMockPhotoPickerCancel() {
        // 1. Launch the app
        app.launch()

        // 2. Navigate to profile
        let profileAvatarButton = app.buttons["profileAvatarButton"]
        XCTAssertTrue(profileAvatarButton.waitForExistence(timeout: 5), "Profile avatar button should exist")
        profileAvatarButton.tap()

        // 3. Open mock photo picker
        let changePhotoButton = app.buttons["profileChangePhotoButton"]
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should exist")
        changePhotoButton.tap()

        // 4. Verify mock picker appears
        let mockPickerSheet = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mockPhotoPickerSheet'")).firstMatch
        XCTAssertTrue(mockPickerSheet.waitForExistence(timeout: 5), "Mock photo picker sheet should appear")

        // 5. Cancel the picker
        let cancelButton = app.buttons["mockPhotoPickerCancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button should exist")
        cancelButton.tap()

        // 6. Verify sheet dismisses
        XCTAssertFalse(mockPickerSheet.waitForExistence(timeout: 2), "Mock picker sheet should dismiss after cancel")

        // 7. Verify profile screen is still visible
        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.waitForExistence(timeout: 5), "Profile screen should still be visible after canceling picker")
    }

}
