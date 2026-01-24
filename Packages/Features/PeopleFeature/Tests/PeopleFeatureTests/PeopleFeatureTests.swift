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

        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        } withDependencies: {
            $0.databaseClient.fetchPeople = { mockPeople }
        }

        // onAppear should trigger loadPeople (no immediate state change)
        await store.send(.onAppear)

        // loadPeople is sent next
        await store.receive(\.loadPeople) {
            $0.isLoading = true
        }

        // Receive the loaded people
        await store.receive(\.peopleLoaded) {
            $0.isLoading = false
            $0.people = mockPeople
        }
    }

    // MARK: - testSearchFiltersPeople

    @Test
    func testSearchFiltersPeople() async {
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
            ),
            PersonRecord(
                id: "person-3",
                name: "Alice Johnson",
                colorToken: "dusk",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: PeopleFeature.State(people: mockPeople)
        ) {
            PeopleFeature()
        }

        // Verify initial state has all people
        #expect(store.state.people.count == 3)
        #expect(store.state.filteredPeople.count == 3)

        // Search for "Alice"
        await store.send(.searchQueryChanged("Alice")) {
            $0.searchQuery = "Alice"
        }

        // Verify filtered results
        #expect(store.state.filteredPeople.count == 2)
        #expect(store.state.filteredPeople.allSatisfy { $0.name.contains("Alice") })
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
}
