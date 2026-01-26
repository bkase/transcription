import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
import DesignSystem
@testable import PeopleFeature

/// Tests for deterministic color assignment to people.
/// Colors cycle through sky → lavender → deep → dusk → sky → ...
@MainActor
struct PeopleColorTests {

    // MARK: - testColorAssignmentStable (Acceptance Criteria)

    @Test
    func testColorAssignmentStable() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        // Track UUIDs for each person created
        var uuidCounter = 0
        let uuids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        ]

        var createdPeople: [PersonRecord] = []

        let store = TestStore(initialState: PeopleFeature.State()) {
            PeopleFeature()
        } withDependencies: {
            $0.uuid = UUIDGenerator { uuids[uuidCounter] }
            $0.date = .constant(mockDate)
            $0.databaseClient.createPerson = { person in
                createdPeople.append(person)
            }
        }

        // Expected colors in order: sky, lavender, deep, dusk, sky (wraps)
        let expectedColors: [SpeakerColor] = [.sky, .lavender, .deep, .dusk, .sky]
        let names = ["Alice", "Bob", "Carol", "Dave", "Eve"]

        for i in 0..<5 {
            // Open add person sheet - should assign color based on people.count
            await store.send(.addPersonTapped) {
                $0.isShowingAddPersonSheet = true
                $0.editingPerson = nil
                $0.formName = ""
                $0.formColorToken = expectedColors[i].rawValue
            }

            await store.send(.formNameChanged(names[i])) {
                $0.formName = names[i]
            }

            await store.send(.savePerson) {
                $0.isSaving = true
            }

            let expectedPerson = PersonRecord(
                id: uuids[i].uuidString,
                name: names[i],
                colorToken: expectedColors[i].rawValue,
                createdAt: mockDate,
                updatedAt: mockDate
            )

            await store.receive(\.personSaved) {
                $0.isSaving = false
                $0.isShowingAddPersonSheet = false
                $0.editingPerson = nil
                $0.formName = ""
                $0.formColorToken = SpeakerColor.sky.rawValue

                // People are sorted alphabetically
                var newPeople = store.state.people
                newPeople.append(expectedPerson)
                newPeople.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                $0.people = newPeople
            }

            uuidCounter += 1
        }

        // Verify all colors were assigned correctly
        #expect(createdPeople.count == 5)
        #expect(createdPeople[0].colorToken == "sky")     // Alice (0th person)
        #expect(createdPeople[1].colorToken == "lavender") // Bob (1st person)
        #expect(createdPeople[2].colorToken == "deep")     // Carol (2nd person)
        #expect(createdPeople[3].colorToken == "dusk")     // Dave (3rd person)
        #expect(createdPeople[4].colorToken == "sky")      // Eve (4th person, wraps)
    }

    // MARK: - testColorAssignmentAfterExistingPeople

    @Test
    func testColorAssignmentAfterExistingPeople() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        // Start with 2 existing people
        let existingPeople = [
            PersonRecord(id: "1", name: "Alice", colorToken: "sky", createdAt: mockDate, updatedAt: mockDate),
            PersonRecord(id: "2", name: "Bob", colorToken: "lavender", createdAt: mockDate, updatedAt: mockDate)
        ]

        let store = TestStore(initialState: PeopleFeature.State(people: existingPeople)) {
            PeopleFeature()
        } withDependencies: {
            $0.uuid = .constant(UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
            $0.date = .constant(mockDate)
            $0.databaseClient.createPerson = { _ in }
        }

        // With 2 existing people, next should get forIndex(2) = deep
        await store.send(.addPersonTapped) {
            $0.isShowingAddPersonSheet = true
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.deep.rawValue
        }
    }

    // MARK: - testForIndexCyclesCorrectly

    @Test
    func testForIndexCyclesCorrectly() {
        // Verify the SpeakerColor.forIndex function cycles correctly
        #expect(SpeakerColor.forIndex(0) == .sky)
        #expect(SpeakerColor.forIndex(1) == .lavender)
        #expect(SpeakerColor.forIndex(2) == .deep)
        #expect(SpeakerColor.forIndex(3) == .dusk)
        #expect(SpeakerColor.forIndex(4) == .sky)      // Wraps
        #expect(SpeakerColor.forIndex(5) == .lavender)
        #expect(SpeakerColor.forIndex(100) == .sky)    // 100 % 4 = 0
        #expect(SpeakerColor.forIndex(101) == .lavender)
    }

    // MARK: - testEditingDoesNotChangeAssignedColor

    @Test
    func testEditingDoesNotChangeAssignedColor() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let existingPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "lavender",  // Original color
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let store = TestStore(initialState: PeopleFeature.State(people: [existingPerson])) {
            PeopleFeature()
        }

        // Edit should preserve the original color, not reassign based on count
        await store.send(.editPersonTapped(existingPerson)) {
            $0.editingPerson = existingPerson
            $0.formName = "Alice"
            $0.formColorToken = "lavender"  // Should preserve original, not change to sky
            $0.isShowingAddPersonSheet = true
        }
    }
}
