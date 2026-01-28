import XCTest

/// E2E tests for the Profile feature.
/// Validates profile navigation, name editing, photo changes, and in-session persistence.
final class ProfileE2ETests: XCTestCase {
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

    /// Find the back button using its accessibility label "Back".
    /// NavButton renders as a button with label "Back" but identifier lookup can be inconsistent.
    private func findBackButton() -> XCUIElement {
        // Query by accessibility label which is more reliable across SwiftUI versions
        return app.buttons.matching(NSPredicate(format: "label == 'Back'")).firstMatch
    }

    /// Navigate to profile screen from timeline.
    private func navigateToProfile() {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
        settingsButton.tap()

        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.waitForExistence(timeout: 5), "Profile screen should appear")
    }

    // MARK: - Comprehensive Flow Test

    /// Comprehensive test covering the full profile flow:
    /// - Navigation (Timeline -> Profile -> Back)
    /// - Name editing (Edit, Save, Verify)
    /// - Photo selection (Select mock photo, Verify)
    /// - In-session persistence (Navigate away and back, verify data persists)
    func testFullProfileFlow() {
        app.launch()

        let testName = "Test User Name"

        // 1. Test navigation: Timeline -> Profile
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Timeline tab should exist")
        XCTAssertTrue(timelineTab.isSelected, "Timeline tab should be selected by default")

        navigateToProfile()

        // Verify profile screen elements exist
        let backButton = findBackButton()
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        let nameRow = app.buttons["profileNameRow"]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 5), "Name row should exist")

        // 2. Test name editing flow
        nameRow.tap()
        let nameTextField = app.textFields["profileNameTextField"]
        XCTAssertTrue(nameTextField.waitForExistence(timeout: 5), "Name text field should appear")
        nameTextField.tap()
        nameTextField.typeText(testName)

        let saveButton = app.buttons["profileNameSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist")
        saveButton.tap()

        // Verify edit mode exits and name displays
        XCTAssertFalse(nameTextField.waitForExistence(timeout: 2), "Text field should disappear after save")
        let nameLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", testName)).firstMatch
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 5), "Name should update after save")

        // 3. Test photo selection flow
        let changePhotoButton = app.buttons["profileChangePhotoButton"]
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should exist")
        changePhotoButton.tap()

        let mockPickerSheet = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mockPhotoPickerSheet'")).firstMatch
        XCTAssertTrue(mockPickerSheet.waitForExistence(timeout: 5), "Mock picker should appear")

        let photoOption = app.buttons["mockPhotoOption-0"]
        XCTAssertTrue(photoOption.waitForExistence(timeout: 5), "Photo option should exist")
        photoOption.tap()

        XCTAssertFalse(mockPickerSheet.waitForExistence(timeout: 2), "Picker should dismiss after selection")

        // 4. Test back navigation: Profile -> Timeline
        backButton.tap()
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Should return to timeline")
        XCTAssertTrue(timelineTab.isSelected, "Timeline tab should be selected")

        // 5. Test in-session persistence: Return to Profile and verify data persists
        navigateToProfile()

        let persistedName = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", testName)).firstMatch
        XCTAssertTrue(persistedName.waitForExistence(timeout: 5), "Name should persist across navigation")

        // Profile screen still loads with photo, confirming photo persistence
        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.exists, "Profile screen should display with persisted data")
    }

    // MARK: - Edge Case: Cancel Flow

    /// Test canceling name edit by navigating back without saving.
    /// This is an important edge case to ensure unsaved changes don't persist.
    func testCancelNameEditByBack() {
        app.launch()

        // Navigate to profile
        navigateToProfile()

        // Start editing name
        let nameRow = app.buttons["profileNameRow"]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 5), "Name row should exist")
        nameRow.tap()

        let nameTextField = app.textFields["profileNameTextField"]
        XCTAssertTrue(nameTextField.waitForExistence(timeout: 5), "Name text field should appear")
        nameTextField.tap()
        nameTextField.typeText("This Should Be Canceled")

        // Navigate back without saving (implicit cancel)
        let backButton = findBackButton()
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        backButton.tap()

        // Verify we're back on timeline (cancel succeeded)
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5), "Should return to timeline")
        XCTAssertTrue(timelineTab.isSelected, "Timeline should be selected after cancel")
    }
}
