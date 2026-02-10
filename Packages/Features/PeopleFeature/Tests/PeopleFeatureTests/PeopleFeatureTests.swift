import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import PeopleFeature

@MainActor
struct PeopleFeatureTests {

    // MARK: - testLoadPeople

    @Test
    func testLoadPeople() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockPeople = [
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
        let mockCounts: [String: Int] = ["person-1": 5, "person-2": 3]

        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        } withDependencies: {
            $0.databaseClient.fetchPeople = { mockPeople }
            $0.databaseClient.fetchPersonConversationCounts = { mockCounts }
        }

        // onAppear should trigger loadPeople (no immediate state change)
        await store.send(.onAppear)

        // loadPeople is sent next
        await store.receive(\.loadPeople) {
            $0.isLoading = true
        }

        // Receive the loaded people with conversation counts
        await store.receive(\.peopleLoaded) {
            $0.isLoading = false
            $0.people = mockPeople
            $0.conversationCounts = mockCounts
        }
    }

    // MARK: - testPeopleLoadError

    @Test
    func testPeopleLoadError() async {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database connection failed" }
        }

        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        } withDependencies: {
            $0.databaseClient.fetchPeople = {
                throw TestError()
            }
            $0.databaseClient.fetchPersonConversationCounts = { [:] }
        }

        await store.send(.loadPeople) {
            $0.isLoading = true
        }

        await store.receive(\.peopleFailed) {
            $0.isLoading = false
            $0.error = "Database connection failed"
        }
    }

    // MARK: - testOnAppearDoesNotReloadIfAlreadyLoaded

    @Test
    func testOnAppearDoesNotReloadIfAlreadyLoaded() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let existingPeople = [
            PersonRecord(
                id: "person-1",
                name: "Alice Smith",
                colorToken: "sky",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: PeopleFeature.State(people: existingPeople)
        ) {
            PeopleFeature()
        } withDependencies: {
            // Should never be called since people already loaded
            $0.databaseClient.fetchPeople = {
                Issue.record("Should not reload when people already exist")
                return []
            }
        }

        // onAppear should not trigger reload when people already exist
        await store.send(.onAppear)
    }

    // MARK: - testPersonTappedIsNavigationIntent

    @Test
    func testPersonTappedIsNavigationIntent() async {
        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        }

        // personTapped is a navigation intent - no state change expected
        await store.send(.personTapped(PersonID("person-1")))
    }

    // MARK: - testRemovePhotoTapped

    @Test
    func testRemovePhotoTappedClearsFormImageData() async {
        let mockImageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes

        let store = TestStore(initialState: PeopleFeature.State(
            destination: .addPersonSheet,
            formImageData: mockImageData
        )) {
            PeopleFeature()
        }

        await store.send(.removePhotoTapped) {
            $0.formImageData = nil
        }
    }

    @Test
    func testRemovePhotoTappedWhenNoPhotoDoesNothing() async {
        let store = TestStore(initialState: PeopleFeature.State(
            destination: .addPersonSheet,
            formImageData: nil
        )) {
            PeopleFeature()
        }

        // Removing when no photo exists should do nothing (formImageData already nil)
        await store.send(.removePhotoTapped)
    }

    // MARK: - testSelfTappedIsNavigationIntent

    @Test
    func testSelfTappedIsNavigationIntent() async {
        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        }

        // selfTapped is a navigation intent - no state change expected
        await store.send(.selfTapped)
    }

    // MARK: - testIsCurrentUserDetection

    @Test
    func testIsCurrentUserDetection() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let userProfile = UserProfile(name: "Alice Smith")
        let person = PersonRecord(
            id: "person-1",
            name: "Alice Smith",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )
        let otherPerson = PersonRecord(
            id: "person-2",
            name: "Bob Jones",
            colorToken: "lavender",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let state = PeopleFeature.State(
            people: [person, otherPerson],
            userProfile: userProfile
        )

        // Person with matching name should be detected as current user
        #expect(state.isCurrentUser(person) == true)
        // Person with different name should not be current user
        #expect(state.isCurrentUser(otherPerson) == false)
    }

    @Test
    func testIsCurrentUserDetectionCaseInsensitive() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let userProfile = UserProfile(name: "ALICE SMITH")
        let person = PersonRecord(
            id: "person-1",
            name: "alice smith",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let state = PeopleFeature.State(
            people: [person],
            userProfile: userProfile
        )

        // Case-insensitive matching should work
        #expect(state.isCurrentUser(person) == true)
    }

    @Test
    func testIsCurrentUserReturnsFalseWhenProfileEmpty() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let person = PersonRecord(
            id: "person-1",
            name: "Alice Smith",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let state = PeopleFeature.State(
            people: [person],
            userProfile: .empty
        )

        // With empty profile, no one should be detected as current user
        #expect(state.isCurrentUser(person) == false)
    }
}
