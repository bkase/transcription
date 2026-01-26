import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import PeopleFeature

@MainActor
struct PeopleSearchTests {

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

    // MARK: - testSearchIsCaseInsensitive

    @Test
    func testSearchIsCaseInsensitive() async {
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
                name: "Bob ALICE Jones",
                colorToken: "lavender",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: PeopleFeature.State(people: mockPeople)
        ) {
            PeopleFeature()
        }

        // Search with lowercase
        await store.send(.searchQueryChanged("alice")) {
            $0.searchQuery = "alice"
        }

        // Should match both (case-insensitive)
        #expect(store.state.filteredPeople.count == 2)
    }

    // MARK: - testSearchEmptyQueryShowsAll

    @Test
    func testSearchEmptyQueryShowsAll() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockPeople = [
            PersonRecord(
                id: "person-1",
                name: "Alice",
                colorToken: "sky",
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            PersonRecord(
                id: "person-2",
                name: "Bob",
                colorToken: "lavender",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: PeopleFeature.State(
                people: mockPeople,
                searchQuery: "Alice"
            )
        ) {
            PeopleFeature()
        }

        // Verify only Alice matches initially
        #expect(store.state.filteredPeople.count == 1)

        // Clear search
        await store.send(.searchQueryChanged("")) {
            $0.searchQuery = ""
        }

        // Should show all people
        #expect(store.state.filteredPeople.count == 2)
    }

    // MARK: - testSearchNoResultsReturnsEmpty

    @Test
    func testSearchNoResultsReturnsEmpty() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockPeople = [
            PersonRecord(
                id: "person-1",
                name: "Alice",
                colorToken: "sky",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: PeopleFeature.State(people: mockPeople)
        ) {
            PeopleFeature()
        }

        // Search for non-existent name
        await store.send(.searchQueryChanged("Zara")) {
            $0.searchQuery = "Zara"
        }

        // Should return empty results
        #expect(store.state.filteredPeople.isEmpty)
    }

    // MARK: - testSearchPreservesConversationCounts

    @Test
    func testSearchPreservesConversationCounts() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockPeople = [
            PersonRecord(
                id: "person-1",
                name: "Alice",
                colorToken: "sky",
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            PersonRecord(
                id: "person-2",
                name: "Bob",
                colorToken: "lavender",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]
        let mockCounts: [String: Int] = ["person-1": 5, "person-2": 3]

        let store = TestStore(
            initialState: PeopleFeature.State(
                people: mockPeople,
                conversationCounts: mockCounts
            )
        ) {
            PeopleFeature()
        }

        // Search filters list but counts remain accessible
        await store.send(.searchQueryChanged("Alice")) {
            $0.searchQuery = "Alice"
        }

        // Filtered list should have Alice
        #expect(store.state.filteredPeople.count == 1)
        #expect(store.state.filteredPeople.first?.id == "person-1")

        // Conversation count should still be accessible
        #expect(store.state.conversationCount(for: "person-1") == 5)
        #expect(store.state.conversationCount(for: "person-2") == 3)
    }
}
