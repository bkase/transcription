import XCTest

/// E2E tests for the person photo picker flow in the People directory.
/// Validates that users can add and remove photos when creating/editing people.
final class PeoplePhotoE2ETests: XCTestCase {
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

    /// Test that the mock photo picker opens when tapping avatar in add person form.
    /// Flow: Timeline -> People -> Add Person -> Tap avatar -> Mock picker appears
    func testAddPersonPhotoPickerOpens() {
        // 1. Launch the app
        app.launch()

        // 2. Navigate to People directory
        let peopleButton = app.buttons["peopleButton"]
        XCTAssertTrue(peopleButton.waitForExistence(timeout: 5), "People button should exist in timeline header")
        peopleButton.tap()

        // 3. Tap Add Person button
        let addPersonButton = app.buttons["addPersonButton"]
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 5), "Add person button should exist")
        addPersonButton.tap()

        // 4. Tap the change photo button (avatar area)
        let changePhotoButton = app.buttons["personChangePhotoButton"]
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should exist in person form")
        changePhotoButton.tap()

        // 5. Verify mock photo picker sheet appears
        let mockPickerSheet = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'personMockPhotoPickerSheet'")).firstMatch
        XCTAssertTrue(mockPickerSheet.waitForExistence(timeout: 5), "Mock photo picker sheet should appear")

        // 6. Verify mock photo options are visible
        let blueOption = app.buttons["personMockPhotoOption-0"]
        let greenOption = app.buttons["personMockPhotoOption-1"]
        let redOption = app.buttons["personMockPhotoOption-2"]
        XCTAssertTrue(blueOption.waitForExistence(timeout: 5), "Blue Square option should exist")
        XCTAssertTrue(greenOption.exists, "Green Square option should exist")
        XCTAssertTrue(redOption.exists, "Red Square option should exist")

        // 7. Cancel the picker
        let cancelButton = app.buttons["personMockPhotoPickerCancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        cancelButton.tap()

        // 8. Verify we're back at the form
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should be accessible after sheet dismisses")
    }

    /// Test full flow: add a person with a photo and save.
    /// Flow: Timeline -> People -> Add Person -> Select photo -> Enter name -> Save -> Verify in list
    func testAddPersonWithPhotoFlow() {
        // 1. Launch the app
        app.launch()

        // 2. Navigate to People directory
        let peopleButton = app.buttons["peopleButton"]
        XCTAssertTrue(peopleButton.waitForExistence(timeout: 5), "People button should exist")
        peopleButton.tap()

        // 3. Tap Add Person button
        let addPersonButton = app.buttons["addPersonButton"]
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 5), "Add person button should exist")
        addPersonButton.tap()

        // 4. Tap avatar to open photo picker
        let changePhotoButton = app.buttons["personChangePhotoButton"]
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should exist")
        changePhotoButton.tap()

        // 5. Select a photo option
        let photoOption = app.buttons["personMockPhotoOption-0"]
        XCTAssertTrue(photoOption.waitForExistence(timeout: 5), "Photo option should exist")
        photoOption.tap()

        // 6. Wait for picker to dismiss and verify we're back at form
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Should be back at form after selecting photo")

        // 7. Verify "Remove photo" button appears (indicating photo was set)
        let removePhotoButton = app.buttons["removePhotoButton"]
        XCTAssertTrue(removePhotoButton.waitForExistence(timeout: 5), "Remove photo button should appear after selecting photo")

        // 8. Enter a name
        let nameField = app.textFields["personNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Person name field should exist")
        nameField.tap()
        nameField.typeText("Photo Person")

        // 9. Save the person
        let saveButton = app.buttons["savePersonButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist")
        saveButton.tap()

        // 10. Verify person appears in the list
        let personCardPredicate = NSPredicate(format: "identifier CONTAINS 'personCard'")
        let personCards = app.descendants(matching: .any).matching(personCardPredicate)
        XCTAssertTrue(personCards.firstMatch.waitForExistence(timeout: 5), "Person card should appear after saving")
    }

    /// Test removing a photo when editing an existing person.
    /// Flow: Add person with photo -> Edit -> Remove photo -> Save -> Verify removed
    func testRemovePhotoFromPerson() {
        // 1. Launch the app
        app.launch()

        // 2. Navigate to People directory
        let peopleButton = app.buttons["peopleButton"]
        XCTAssertTrue(peopleButton.waitForExistence(timeout: 5), "People button should exist")
        peopleButton.tap()

        // 3. Add a person with a photo first
        let addPersonButton = app.buttons["addPersonButton"]
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 5), "Add person button should exist")
        addPersonButton.tap()

        // 4. Select a photo
        let changePhotoButton = app.buttons["personChangePhotoButton"]
        XCTAssertTrue(changePhotoButton.waitForExistence(timeout: 5), "Change photo button should exist")
        changePhotoButton.tap()

        let photoOption = app.buttons["personMockPhotoOption-1"]
        XCTAssertTrue(photoOption.waitForExistence(timeout: 5), "Photo option should exist")
        photoOption.tap()

        // 5. Enter name and save
        let nameField = app.textFields["personNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field should exist")
        nameField.tap()
        nameField.typeText("Remove Photo Test")

        let saveButton = app.buttons["savePersonButton"]
        saveButton.tap()

        // 6. Wait for person card to appear
        let personCardPredicate = NSPredicate(format: "identifier CONTAINS 'personCard'")
        let personCards = app.descendants(matching: .any).matching(personCardPredicate)
        XCTAssertTrue(personCards.firstMatch.waitForExistence(timeout: 5), "Person card should appear")

        // 7. Long press to open context menu and tap Edit
        personCards.firstMatch.press(forDuration: 1.0)

        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit button should appear in context menu")
        editButton.tap()

        // 8. Verify edit form appears with remove photo button (since person has photo)
        let removePhotoButton = app.buttons["removePhotoButton"]
        XCTAssertTrue(removePhotoButton.waitForExistence(timeout: 5), "Remove photo button should exist when editing person with photo")

        // 9. Tap remove photo
        removePhotoButton.tap()

        // 10. Verify remove photo button is gone (replaced with "Tap to add photo" text)
        XCTAssertFalse(removePhotoButton.waitForExistence(timeout: 2), "Remove photo button should disappear after removing photo")

        // 11. Save the changes
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist")
        saveButton.tap()

        // 12. Verify person card still exists (photo was removed but person persists)
        XCTAssertTrue(personCards.firstMatch.waitForExistence(timeout: 5), "Person card should still exist after removing photo")
    }
}
