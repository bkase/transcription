import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import SpeakerPickerFeature

// MARK: - Test Data (nonisolated)

private let mockDate = Date(timeIntervalSince1970: 1000000)

private let mockPeople = [
    PersonRecord(
        id: "person-1",
        name: "Alice Smith",
        colorToken: "sky",
        createdAt: mockDate,
        updatedAt: mockDate
    ),
    PersonRecord(
        id: "person-2",
        name: "Bob Jones",
        colorToken: "lavender",
        createdAt: mockDate,
        updatedAt: mockDate
    )
]

private let mockSpeakerTrack = SpeakerTrackRecord(
    id: "track-1",
    sessionId: "session-1",
    machineSpeakerId: "speaker_0",
    displayOrder: 1,
    personId: nil
)

@MainActor
struct SpeakerPickerFeatureTests {

    // MARK: - testLoadPeople

    @Test
    func testLoadPeople() async {
        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.databaseClient.fetchPeople = { mockPeople }
        }

        await store.send(.onAppear)

        await store.receive(\.loadPeople) {
            $0.isLoading = true
        }

        await store.receive(\.peopleLoaded) {
            $0.isLoading = false
            $0.people = mockPeople
        }
    }

    // MARK: - testPeopleLoadError

    @Test
    func testPeopleLoadError() async {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database connection failed" }
        }

        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.databaseClient.fetchPeople = {
                throw TestError()
            }
        }

        await store.send(.loadPeople) {
            $0.isLoading = true
        }

        await store.receive(\.peopleFailed) {
            $0.isLoading = false
            $0.error = "Database connection failed"
        }
    }

    // MARK: - testSelectPerson

    @Test
    func testSelectPerson() async {
        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople
            )
        ) {
            SpeakerPickerFeature()
        }

        // Select a person
        await store.send(.personSelected(PersonID("person-2"))) {
            $0.selectedPersonId = PersonID("person-2")
        }
    }

    // MARK: - testConfirmSelection

    @Test
    func testConfirmSelection() async {
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople,
                selectedPersonId: PersonID("person-1")
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSpeakerTracks = { _ in
                [mockSpeakerTrack]
            }
            $0.databaseClient.updateSpeakerTrack = { _ in }
        }

        await store.send(.confirmSelection)

        await store.receive(\.selectionConfirmed)
    }

    // MARK: - testConfirmSelectionWithMissingSpeakerTrack

    @Test
    func testConfirmSelectionWithMissingSpeakerTrack() async {
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!

        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-missing",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople,
                selectedPersonId: PersonID("person-1")
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSpeakerTracks = { _ in
                [mockSpeakerTrack] // Doesn't contain "track-missing"
            }
        }

        await store.send(.confirmSelection)

        await store.receive(\.selectionFailed) {
            $0.error = "Speaker track not found"
        }
    }

    // MARK: - testAddNewPersonFlow

    @Test
    func testAddNewPersonFlow() async {
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.createPerson = { _ in }
        }

        // Tap to add new person
        await store.send(.addNewPersonTapped) {
            $0.isShowingNewPersonForm = true
            $0.newPersonName = ""
            // Color should be set based on existing people count (2 people = index 2 = deep)
            $0.newPersonColorToken = "deep"
        }

        // Enter name
        await store.send(.newPersonNameChanged("Charlie Brown")) {
            $0.newPersonName = "Charlie Brown"
        }

        // Change color
        await store.send(.newPersonColorChanged("dusk")) {
            $0.newPersonColorToken = "dusk"
        }

        // Save new person
        await store.send(.saveNewPerson) {
            $0.isSaving = true
        }

        let newPerson = PersonRecord(
            id: mockUUID.uuidString,
            name: "Charlie Brown",
            colorToken: "dusk",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        await store.receive(\.newPersonSaved) {
            $0.isSaving = false
            $0.isShowingNewPersonForm = false
            $0.newPersonName = ""
            $0.newPersonColorToken = "sky"
            // New person added and selected
            $0.people = [mockPeople[0], mockPeople[1], newPerson].sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            $0.selectedPersonId = PersonID(mockUUID.uuidString)
        }
    }

    // MARK: - testSaveNewPersonWithEmptyName

    @Test
    func testSaveNewPersonWithEmptyName() async {
        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople,
                isShowingNewPersonForm: true,
                newPersonName: "   "  // Just whitespace
            )
        ) {
            SpeakerPickerFeature()
        }

        await store.send(.saveNewPerson) {
            $0.error = "Name cannot be empty"
        }
    }

    // MARK: - testCancelNewPerson

    @Test
    func testCancelNewPerson() async {
        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                isShowingNewPersonForm: true,
                newPersonName: "Partial Name",
                newPersonColorToken: "lavender"
            )
        ) {
            SpeakerPickerFeature()
        }

        await store.send(.cancelNewPerson) {
            $0.isShowingNewPersonForm = false
            $0.newPersonName = ""
            $0.newPersonColorToken = "sky"
        }
    }

    // MARK: - testCloseModalAction

    @Test
    func testCloseModalAction() async {
        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1
            )
        ) {
            SpeakerPickerFeature()
        }

        // closeModal should return none (parent handles dismissal)
        await store.send(.closeModal)
    }

    // MARK: - testOnAppearDoesNotReloadIfAlreadyLoaded

    @Test
    func testOnAppearDoesNotReloadIfAlreadyLoaded() async {
        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople  // Already loaded
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.databaseClient.fetchPeople = {
                Issue.record("Should not reload when people already exist")
                return []
            }
        }

        // onAppear should not trigger reload when people already exist
        await store.send(.onAppear)
    }

    // MARK: - testSelectedPersonIdDefaultsToCurrentPersonId

    @Test
    func testSelectedPersonIdDefaultsToCurrentPersonId() async {
        let state = SpeakerPickerFeature.State(
            speakerTrackId: "track-1",
            sessionId: SessionID("session-1"),
            displayOrder: 1,
            currentPersonId: PersonID("person-2")
        )

        #expect(state.selectedPersonId == PersonID("person-2"))
    }

    // MARK: - Current User Tests

    @Test
    func testCurrentUserOptionVisibleWhenProfileHasName() async {
        let profile = UserProfile(name: "Jane Doe")
        let state = SpeakerPickerFeature.State(
            speakerTrackId: "track-1",
            sessionId: SessionID("session-1"),
            displayOrder: 1,
            userProfile: profile
        )

        #expect(state.showCurrentUserOption == true)
    }

    @Test
    func testCurrentUserOptionHiddenWhenProfileHasEmptyName() async {
        let profile = UserProfile(name: "   ")
        let state = SpeakerPickerFeature.State(
            speakerTrackId: "track-1",
            sessionId: SessionID("session-1"),
            displayOrder: 1,
            userProfile: profile
        )

        #expect(state.showCurrentUserOption == false)
    }

    @Test
    func testSelectCurrentUser() async {
        let profile = UserProfile(name: "Jane Doe")
        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople,
                userProfile: profile
            )
        ) {
            SpeakerPickerFeature()
        }

        // Select current user
        await store.send(.personSelected(SpeakerPickerFeature.State.currentUserPersonId)) {
            $0.selectedPersonId = SpeakerPickerFeature.State.currentUserPersonId
        }

        #expect(store.state.isCurrentUserSelected == true)
    }

    @Test
    func testConfirmCurrentUserSelection_createsNewPerson() async {
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let profile = UserProfile(name: "Jane Doe")

        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeople,
                selectedPersonId: SpeakerPickerFeature.State.currentUserPersonId,
                userProfile: profile
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSpeakerTracks = { _ in
                [mockSpeakerTrack]
            }
            $0.databaseClient.fetchPeople = { mockPeople }
            $0.databaseClient.createPerson = { _ in }
            $0.databaseClient.updateSpeakerTrack = { _ in }
        }

        await store.send(.confirmSelection)

        // The actual person ID is the newly created person's ID
        await store.receive(\.selectionConfirmed)
    }

    @Test
    func testConfirmCurrentUserSelection_reusesExistingPerson() async {
        // When user's name matches an existing person, it should reuse that person
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let profile = UserProfile(name: "alice smith") // lowercase to test case-insensitive matching
        let mockPeopleWithAlice = mockPeople

        let store = TestStore(
            initialState: SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: SessionID("session-1"),
                displayOrder: 1,
                people: mockPeopleWithAlice,
                selectedPersonId: SpeakerPickerFeature.State.currentUserPersonId,
                userProfile: profile
            )
        ) {
            SpeakerPickerFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSpeakerTracks = { _ in
                [mockSpeakerTrack]
            }
            $0.databaseClient.fetchPeople = { mockPeopleWithAlice }
            // No createPerson should be called since we're reusing existing
            $0.databaseClient.updateSpeakerTrack = { _ in }
        }

        await store.send(.confirmSelection)

        // Should reuse Alice's ID (person-1)
        await store.receive(\.selectionConfirmed)
    }
}
