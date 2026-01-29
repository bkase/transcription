import XCTest

/// E2E tests for editing yourself from the People directory.
/// Validates that tapping on a person with the same name as the current user
/// navigates to Profile instead of PersonTimeline.
final class PeopleSelfEditE2ETests: XCTestCase {
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
    private func findBackButton() -> XCUIElement {
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

    /// Navigate to people directory from timeline.
    private func navigateToPeople() {
        let peopleButton = app.buttons["peopleButton"]
        XCTAssertTrue(peopleButton.waitForExistence(timeout: 5), "People button should exist")
        peopleButton.tap()

        let addPersonButton = app.buttons["addPersonButton"]
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 5), "Add person button should exist (we're in people view)")
    }

    // MARK: - Tests

    /// Test that tapping on yourself in People directory navigates to Profile.
    /// Flow:
    /// 1. Set your name in Profile
    /// 2. Navigate to People directory
    /// 3. Add a person with the same name as your profile
    /// 4. Tap on that person
    /// 5. Verify Profile screen appears (not PersonTimeline)
    func testTapOnSelfInPeopleNavigatesToProfile() {
        let userName = "My Test Name"

        app.launch()

        // 1. First set the user's profile name
        navigateToProfile()

        let nameRow = app.buttons["profileNameRow"]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 5), "Name row should exist")
        nameRow.tap()

        let nameTextField = app.textFields["profileNameTextField"]
        XCTAssertTrue(nameTextField.waitForExistence(timeout: 5), "Name text field should appear")
        nameTextField.tap()
        nameTextField.typeText(userName)

        let saveButton = app.buttons["profileNameSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist")
        saveButton.tap()

        // Verify edit mode exits
        XCTAssertFalse(nameTextField.waitForExistence(timeout: 2), "Text field should disappear after save")

        // Navigate back to timeline
        let backButton = findBackButton()
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        backButton.tap()

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Should be back on timeline")

        // 2. Navigate to People directory
        navigateToPeople()

        // 3. Add a person with the same name as the profile
        let addPersonButton = app.buttons["addPersonButton"]
        addPersonButton.tap()

        let personNameField = app.textFields["personNameField"]
        XCTAssertTrue(personNameField.waitForExistence(timeout: 5), "Person name field should exist")
        personNameField.tap()
        personNameField.typeText(userName)

        let savePersonButton = app.buttons["savePersonButton"]
        XCTAssertTrue(savePersonButton.waitForExistence(timeout: 5), "Save button should exist")
        savePersonButton.tap()

        // 4. Wait for the person card to appear and tap it
        // The card should be marked as "currentUserPersonCard" because name matches profile
        let currentUserCard = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'currentUserPersonCard'")).firstMatch
        XCTAssertTrue(currentUserCard.waitForExistence(timeout: 5), "Current user person card should appear")

        // Verify it shows "(You)" suffix
        let youLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '(You)'")).firstMatch
        XCTAssertTrue(youLabel.waitForExistence(timeout: 5), "Card should show '(You)' suffix")

        // Tap on the card
        currentUserCard.tap()

        // 5. Verify Profile screen appears (not PersonTimeline)
        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.waitForExistence(timeout: 5), "Profile screen should appear when tapping on self")

        // PersonTimeline should NOT appear
        let personTimelineName = app.staticTexts["personTimelineName"]
        XCTAssertFalse(personTimelineName.exists, "PersonTimeline should NOT appear when tapping on self")
    }

    /// Test that after tapping on self -> Profile, navigating back returns to People (not deeper).
    /// This is a simpler regression test for the navigation stack behavior.
    func testNavigateBackFromProfileReturnsToPeople() {
        let userName = "Test User"

        app.launch()

        // 1. Set the user's profile name
        navigateToProfile()

        let nameRow = app.buttons["profileNameRow"]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 5), "Name row should exist")
        nameRow.tap()

        let nameTextField = app.textFields["profileNameTextField"]
        XCTAssertTrue(nameTextField.waitForExistence(timeout: 5), "Name text field should appear")
        nameTextField.tap()
        nameTextField.typeText(userName)

        let saveButton = app.buttons["profileNameSaveButton"]
        saveButton.tap()

        // Navigate back to timeline
        let backButton = findBackButton()
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        backButton.tap()

        // 2. Navigate to People and add person with same name
        navigateToPeople()

        let addPersonButton = app.buttons["addPersonButton"]
        addPersonButton.tap()

        let personNameField = app.textFields["personNameField"]
        XCTAssertTrue(personNameField.waitForExistence(timeout: 5), "Person name field should exist")
        personNameField.tap()
        personNameField.typeText(userName)

        let savePersonButton = app.buttons["savePersonButton"]
        savePersonButton.tap()

        // 3. Tap on the current user card to navigate to Profile
        let currentUserCard = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'currentUserPersonCard'")).firstMatch
        XCTAssertTrue(currentUserCard.waitForExistence(timeout: 5), "Current user person card should appear")
        currentUserCard.tap()

        // 4. Verify Profile screen appears
        let profileScreen = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'profileScreen'")).firstMatch
        XCTAssertTrue(profileScreen.waitForExistence(timeout: 5), "Profile screen should appear")

        // 5. Navigate back from Profile
        let profileBackButton = findBackButton()
        XCTAssertTrue(profileBackButton.waitForExistence(timeout: 5), "Back button should exist on Profile")
        profileBackButton.tap()

        // 6. Verify we're back in People view (not timeline)
        let addPersonButtonAgain = app.buttons["addPersonButton"]
        XCTAssertTrue(addPersonButtonAgain.waitForExistence(timeout: 5), "Should be back in People view, not timeline")

        // The current user card should still be visible
        let currentUserCardAgain = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'currentUserPersonCard'")).firstMatch
        XCTAssertTrue(currentUserCardAgain.waitForExistence(timeout: 5), "Current user card should still be visible in People view")
    }
}
