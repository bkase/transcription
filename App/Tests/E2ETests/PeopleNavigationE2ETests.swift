import XCTest

/// E2E tests for the People directory navigation feature.
/// Validates that tapping a person navigates to their filtered timeline.
final class PeopleNavigationE2ETests: XCTestCase {
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

    /// Test that tapping a person in People directory navigates to PersonTimelineView.
    /// Flow: Timeline -> People tab -> Add person -> People list -> Tap person -> PersonTimelineView
    func testTapPersonNavigatesToPersonTimeline() {
        // 1. Launch the app
        app.launch()

        // 2. Navigate to People tab
        let peopleTab = app.tabBars.buttons["People"]
        XCTAssertTrue(peopleTab.waitForExistence(timeout: 5), "People tab should exist")
        peopleTab.tap()

        // 3. Add a new person so we have someone to tap on
        let addPersonButton = app.buttons["addPersonButton"]
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 5), "Add person button should exist")
        addPersonButton.tap()

        // 4. Fill in the person's name
        let nameField = app.textFields["personNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Person name field should exist")
        nameField.tap()
        nameField.typeText("Test Person")

        // 5. Save the person
        let saveButton = app.buttons["savePersonButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist")
        saveButton.tap()

        // 6. Wait for sheet to dismiss and person card to appear
        let personCardPredicate = NSPredicate(format: "identifier == 'personCard'")
        let personCards = app.descendants(matching: .any).matching(personCardPredicate)
        XCTAssertTrue(personCards.firstMatch.waitForExistence(timeout: 5), "Person card should appear after saving")

        // 7. Tap the person card
        personCards.firstMatch.tap()

        // 8. Verify PersonTimelineView appears with the person's name
        let personNameLabel = app.staticTexts["personTimelineName"]
        XCTAssertTrue(personNameLabel.waitForExistence(timeout: 5), "Person timeline name should appear")
        XCTAssertEqual(personNameLabel.label, "Test Person", "Person name should match the created person")

        // 9. Verify back button exists
        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 2), "Back button should exist on person timeline")

        // 10. Tap back to return to People directory
        backButton.tap()

        // 11. Verify we're back at People directory
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 5), "Add person button should be visible after navigating back")
    }

    /// Test that navigating from PersonTimelineView to session detail works correctly.
    /// This requires having a session associated with the person.
    /// Flow: Create person -> Record session -> Assign speaker -> Navigate via People tab
    func testPersonTimelineShowsFilteredSessions() throws {
        // Skip: This test requires more complex setup
        // TODO: Implement when we have better test fixtures
        throw XCTSkip("Requires speaker assignment during recording which is complex to automate")
    }
}
