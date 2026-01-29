import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
import DesignSystem
@testable import PeopleFeature

@MainActor
struct PeopleCrudTests {

    // MARK: - testCreateRenameDeletePerson (Acceptance Criteria)

    @Test
    func testCreateRenameDeletePerson() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        var createdPerson: PersonRecord?
        var updatedPerson: PersonRecord?
        var deletedPersonId: PersonID?

        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.createPerson = { person in
                createdPerson = person
            }
            $0.databaseClient.updatePerson = { person in
                updatedPerson = person
            }
            $0.databaseClient.deletePerson = { id in
                deletedPersonId = id
            }
        }

        // 1. Create a new person
        await store.send(.addPersonTapped) {
            $0.isShowingAddPersonSheet = true
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
        }

        await store.send(.formNameChanged("Alice Smith")) {
            $0.formName = "Alice Smith"
        }

        await store.send(.formColorChanged("lavender")) {
            $0.formColorToken = "lavender"
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        let expectedPerson = PersonRecord(
            id: mockUUID.uuidString,
            name: "Alice Smith",
            colorToken: "lavender",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        await store.receive(\.personSaved) {
            $0.isSaving = false
            $0.isShowingAddPersonSheet = false
            $0.people = [expectedPerson]
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
        }

        #expect(createdPerson == expectedPerson)

        // 2. Rename the person
        await store.send(.editPersonTapped(expectedPerson)) {
            $0.editingPerson = expectedPerson
            $0.formName = "Alice Smith"
            $0.formColorToken = "lavender"
            $0.formImageData = nil
            $0.isShowingAddPersonSheet = true
        }

        await store.send(.formNameChanged("Alice Johnson")) {
            $0.formName = "Alice Johnson"
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        let renamedPerson = PersonRecord(
            id: mockUUID.uuidString,
            name: "Alice Johnson",
            colorToken: "lavender",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        await store.receive(\.personSaved) {
            $0.isSaving = false
            $0.isShowingAddPersonSheet = false
            $0.people = [renamedPerson]
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
        }

        #expect(updatedPerson == renamedPerson)

        // 3. Delete the person
        await store.send(.deletePersonTapped(PersonID(mockUUID.uuidString)))

        await store.receive(\.personDeleted) {
            $0.people = []
        }

        #expect(deletedPersonId == PersonID(mockUUID.uuidString))
    }

    // MARK: - testCreatePersonWithEmptyNameFails

    @Test
    func testCreatePersonWithEmptyNameFails() async {
        let store = TestStore(initialState: PeopleFeature.State(isShowingAddPersonSheet: true)) {
            PeopleFeature()
        }

        // Try to save with empty name
        await store.send(.savePerson) {
            $0.error = "Name cannot be empty"
        }
    }

    // MARK: - testCreatePersonWithWhitespaceOnlyNameFails

    @Test
    func testCreatePersonWithWhitespaceOnlyNameFails() async {
        let store = TestStore(initialState: PeopleFeature.State(
            isShowingAddPersonSheet: true,
            formName: "   "
        )) {
            PeopleFeature()
        }

        await store.send(.savePerson) {
            $0.error = "Name cannot be empty"
        }
    }

    // MARK: - testSavePersonDatabaseError

    @Test
    func testSavePersonDatabaseError() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database write failed" }
        }

        let store = TestStore(initialState: PeopleFeature.State(
            isShowingAddPersonSheet: true,
            formName: "Test Person"
        )) {
            PeopleFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.createPerson = { _ in
                throw TestError()
            }
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.error = "Database write failed"
        }
    }

    // MARK: - testDeletePersonDatabaseError

    @Test
    func testDeletePersonDatabaseError() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let existingPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Delete failed" }
        }

        let store = TestStore(initialState: PeopleFeature.State(people: [existingPerson])) {
            PeopleFeature()
        } withDependencies: {
            $0.databaseClient.deletePerson = { _ in
                throw TestError()
            }
        }

        await store.send(.deletePersonTapped(PersonID("person-1")))

        await store.receive(\.deleteFailed) {
            $0.error = "Delete failed"
        }

        // Person should still be in the list after failed delete
        #expect(store.state.people.count == 1)
    }

    // MARK: - testDismissSheetResetsForm

    @Test
    func testDismissSheetResetsForm() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let existingPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "lavender",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let store = TestStore(initialState: PeopleFeature.State(
            isShowingAddPersonSheet: true,
            editingPerson: existingPerson,
            formName: "Alice Modified",
            formColorToken: "deep",
            isSaving: false
        )) {
            PeopleFeature()
        }

        await store.send(.dismissSheet) {
            $0.isShowingAddPersonSheet = false
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.isSaving = false
        }
    }

    // MARK: - testAddPersonTappedWorksAfterDismissSheet

    @Test
    func testAddPersonTappedWorksAfterDismissSheet() async {
        // This test verifies that the Add Person button works after opening and closing the sheet once.
        // Regression test for: "Add Person button stops working after opening and closing modal once"
        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        }

        // First: Open the sheet
        await store.send(.addPersonTapped) {
            $0.isShowingAddPersonSheet = true
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.error = nil
        }

        // Close the sheet
        await store.send(.dismissSheet) {
            $0.isShowingAddPersonSheet = false
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.isSaving = false
            $0.error = nil
        }

        // Second: Open the sheet again - THIS MUST WORK
        await store.send(.addPersonTapped) {
            $0.isShowingAddPersonSheet = true
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.error = nil
        }

        // Verify the sheet can be opened
        #expect(store.state.isShowingAddPersonSheet == true)
    }

    // MARK: - testAddPersonTappedWorksAfterDismissSheetWithError

    @Test
    func testAddPersonTappedWorksAfterDismissSheetWithError() async {
        // This test verifies that the Add Person button works after an error occurred and the sheet was dismissed.
        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        }

        // Open the sheet
        await store.send(.addPersonTapped) {
            $0.isShowingAddPersonSheet = true
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.error = nil
        }

        // Try to save with empty name - this causes an error
        await store.send(.savePerson) {
            $0.error = "Name cannot be empty"
        }

        // Dismiss the sheet (simulating user tapping Cancel after seeing the error)
        await store.send(.dismissSheet) {
            $0.isShowingAddPersonSheet = false
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.isSaving = false
            $0.error = nil
        }

        // Open the sheet again - THIS MUST WORK and error must be cleared
        await store.send(.addPersonTapped) {
            $0.isShowingAddPersonSheet = true
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.error = nil
        }

        // Verify the sheet can be opened and error is cleared
        #expect(store.state.isShowingAddPersonSheet == true)
        #expect(store.state.error == nil)
    }

    // MARK: - testPeopleListSortedByName

    @Test
    func testPeopleListSortedByName() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        // Create people in non-alphabetical order
        var people = [
            PersonRecord(id: "1", name: "Zebra", colorToken: "sky", createdAt: mockDate, updatedAt: mockDate),
            PersonRecord(id: "2", name: "Alice", colorToken: "sky", createdAt: mockDate, updatedAt: mockDate),
            PersonRecord(id: "3", name: "Bob", colorToken: "sky", createdAt: mockDate, updatedAt: mockDate)
        ]

        let store = TestStore(initialState: PeopleFeature.State(
            people: people,
            isShowingAddPersonSheet: true,
            formName: "Charlie"
        )) {
            PeopleFeature()
        } withDependencies: {
            $0.uuid = .constant(UUID(uuidString: "00000000-0000-0000-0000-000000000004")!)
            $0.date = .constant(mockDate)
            $0.databaseClient.createPerson = { _ in }
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        let newPerson = PersonRecord(
            id: "00000000-0000-0000-0000-000000000004",
            name: "Charlie",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        await store.receive(\.personSaved) {
            $0.isSaving = false
            $0.isShowingAddPersonSheet = false
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            // Sorted alphabetically: Alice, Bob, Charlie, Zebra
            $0.people = [
                PersonRecord(id: "2", name: "Alice", colorToken: "sky", createdAt: mockDate, updatedAt: mockDate),
                PersonRecord(id: "3", name: "Bob", colorToken: "sky", createdAt: mockDate, updatedAt: mockDate),
                newPerson,
                PersonRecord(id: "1", name: "Zebra", colorToken: "sky", createdAt: mockDate, updatedAt: mockDate)
            ]
        }
    }

    // MARK: - testUpdateExistingPersonInList

    @Test
    func testUpdateExistingPersonInList() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let updatedDate = Date(timeIntervalSince1970: 2000000)
        let existingPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let store = TestStore(initialState: PeopleFeature.State(
            people: [existingPerson],
            isShowingAddPersonSheet: true,
            editingPerson: existingPerson,
            formName: "Alice Updated",
            formColorToken: "deep"
        )) {
            PeopleFeature()
        } withDependencies: {
            $0.date = .constant(updatedDate)
            $0.databaseClient.updatePerson = { _ in }
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        let updatedPerson = PersonRecord(
            id: "person-1",
            name: "Alice Updated",
            colorToken: "deep",
            createdAt: mockDate,
            updatedAt: updatedDate
        )

        await store.receive(\.personSaved) {
            $0.isSaving = false
            $0.isShowingAddPersonSheet = false
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.people = [updatedPerson]
        }
    }
}
