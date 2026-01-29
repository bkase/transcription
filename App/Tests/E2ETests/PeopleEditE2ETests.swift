import XCTest

/// E2E tests for editing a person via context menu.
/// Validates that long-pressing on a person card and selecting Edit opens the edit form.
final class PeopleEditE2ETests: XCTestCase {
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

    /// Test that tapping Edit in context menu opens the edit form with data pre-filled.
    /// Flow: Timeline -> People -> Add person -> Long press -> Edit -> Verify form shows person data
    func testEditPersonViaContextMenu() {
        // 1. Launch the app
        app.launch()

        // 2. Navigate to People directory via people icon in header
        let peopleButton = app.buttons["peopleButton"]
        XCTAssertTrue(peopleButton.waitForExistence(timeout: 5), "People button should exist in timeline header")
        peopleButton.tap()

        // 3. Add a new person so we have someone to edit
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

        // 7. Long press on the person card to open context menu
        personCards.firstMatch.press(forDuration: 1.0)

        // 8. Verify context menu appears with Edit button
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit button should appear in context menu")

        // 9. Tap Edit
        editButton.tap()

        // 10. Verify edit form appears
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field should appear in edit form")

        // 11. Verify the name is pre-filled with the person's data
        // The text field should contain "Test Person"
        let fieldValue = nameField.value as? String
        XCTAssertEqual(fieldValue, "Test Person", "Name field should be pre-filled with person's name")

        // 12. Verify the navigation title shows "Edit Person"
        let navTitle = app.staticTexts["Edit Person"]
        XCTAssertTrue(navTitle.exists, "Navigation title should show 'Edit Person'")
    }

    /// Test that the Delete action in context menu still works (regression test).
    func testDeletePersonViaContextMenu() {
        // 1. Launch the app
        app.launch()

        // 2. Navigate to People directory
        let peopleButton = app.buttons["peopleButton"]
        XCTAssertTrue(peopleButton.waitForExistence(timeout: 5), "People button should exist")
        peopleButton.tap()

        // 3. Add a new person
        let addPersonButton = app.buttons["addPersonButton"]
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 5), "Add person button should exist")
        addPersonButton.tap()

        // 4. Fill in name and save
        let nameField = app.textFields["personNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Person name field should exist")
        nameField.tap()
        nameField.typeText("Delete Me")

        let saveButton = app.buttons["savePersonButton"]
        saveButton.tap()

        // 5. Wait for person card
        let personCardPredicate = NSPredicate(format: "identifier == 'personCard'")
        let personCards = app.descendants(matching: .any).matching(personCardPredicate)
        XCTAssertTrue(personCards.firstMatch.waitForExistence(timeout: 5), "Person card should appear")

        // 6. Long press to open context menu
        personCards.firstMatch.press(forDuration: 1.0)

        // 7. Tap Delete
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button should appear in context menu")
        deleteButton.tap()

        // 8. Verify person is deleted (no more person cards)
        let personCardGone = personCards.firstMatch.waitForNonExistence(timeout: 5)
        XCTAssertTrue(personCardGone, "Person card should be deleted")

        // 9. Verify empty state or no cards
        let emptyText = app.staticTexts["No people yet"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5), "Empty state should appear after deleting the only person")
    }
}
