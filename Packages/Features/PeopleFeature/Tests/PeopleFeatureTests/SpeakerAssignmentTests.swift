import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import PeopleFeature

/// Tests for speaker assignment persistence and conversation count updates.
@MainActor
struct SpeakerAssignmentTests {

    // MARK: - testAssignSpeakerUpdatesCounts

    /// Verify that assigning a speaker track to a person updates the conversation counts.
    /// This test uses the live database to verify the actual SQL query works correctly.
    @Test
    func testAssignSpeakerUpdatesCounts() async throws {
        // Set up in-memory database
        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        let mockDate = Date(timeIntervalSince1970: 1000000)

        // Create a session
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .processed,
            speakerCount: 2,
            updatedAt: mockDate
        )
        try await databaseClient.createSession(session)

        // Create a second session
        let session2 = SessionRecord(
            id: "session-2",
            startedAt: mockDate,
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )
        try await databaseClient.createSession(session2)

        // Create a person
        let person = PersonRecord(
            id: "person-1",
            name: "Alice Smith",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )
        try await databaseClient.createPerson(person)

        // Create speaker tracks without person assignment
        let track1 = SpeakerTrackRecord(
            id: "track-1",
            sessionId: "session-1",
            machineSpeakerId: "speaker_0",
            displayOrder: 1,
            personId: nil
        )
        try await databaseClient.createSpeakerTrack(track1)

        let track2 = SpeakerTrackRecord(
            id: "track-2",
            sessionId: "session-2",
            machineSpeakerId: "speaker_0",
            displayOrder: 1,
            personId: nil
        )
        try await databaseClient.createSpeakerTrack(track2)

        // Initially, conversation count should be 0
        var counts = try await databaseClient.fetchPersonConversationCounts()
        #expect(counts["person-1"] == nil || counts["person-1"] == 0)

        // Assign first track to the person
        let updatedTrack1 = SpeakerTrackRecord(
            id: track1.id,
            sessionId: track1.sessionId,
            machineSpeakerId: track1.machineSpeakerId,
            displayOrder: track1.displayOrder,
            personId: "person-1"
        )
        try await databaseClient.updateSpeakerTrack(updatedTrack1)

        // Now conversation count should be 1
        counts = try await databaseClient.fetchPersonConversationCounts()
        #expect(counts["person-1"] == 1)

        // Assign second track to the same person
        let updatedTrack2 = SpeakerTrackRecord(
            id: track2.id,
            sessionId: track2.sessionId,
            machineSpeakerId: track2.machineSpeakerId,
            displayOrder: track2.displayOrder,
            personId: "person-1"
        )
        try await databaseClient.updateSpeakerTrack(updatedTrack2)

        // Now conversation count should be 2 (distinct sessions)
        counts = try await databaseClient.fetchPersonConversationCounts()
        #expect(counts["person-1"] == 2)
    }

    // MARK: - testMultipleSpeakersInSameSessionCountsOnce

    /// Verify that a person appearing as multiple speakers in the same session
    /// only counts as 1 conversation (uses DISTINCT sessionId).
    @Test
    func testMultipleSpeakersInSameSessionCountsOnce() async throws {
        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        let mockDate = Date(timeIntervalSince1970: 1000000)

        // Create a session
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .processed,
            speakerCount: 2,
            updatedAt: mockDate
        )
        try await databaseClient.createSession(session)

        // Create a person
        let person = PersonRecord(
            id: "person-1",
            name: "Alice Smith",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )
        try await databaseClient.createPerson(person)

        // Create two speaker tracks in the same session, both assigned to the same person
        // (unusual but possible if ML misidentified and user corrected both)
        let track1 = SpeakerTrackRecord(
            id: "track-1",
            sessionId: "session-1",
            machineSpeakerId: "speaker_0",
            displayOrder: 1,
            personId: "person-1"
        )
        try await databaseClient.createSpeakerTrack(track1)

        let track2 = SpeakerTrackRecord(
            id: "track-2",
            sessionId: "session-1",
            machineSpeakerId: "speaker_1",
            displayOrder: 2,
            personId: "person-1"
        )
        try await databaseClient.createSpeakerTrack(track2)

        // Conversation count should be 1, not 2 (uses DISTINCT)
        let counts = try await databaseClient.fetchPersonConversationCounts()
        #expect(counts["person-1"] == 1)
    }

    // MARK: - testPeopleFeatureLoadsConversationCounts

    /// Verify that PeopleFeature loads conversation counts alongside people.
    @Test
    func testPeopleFeatureLoadsConversationCounts() async {
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

        await store.send(.loadPeople) {
            $0.isLoading = true
        }

        await store.receive(\.peopleLoaded) {
            $0.isLoading = false
            $0.people = mockPeople
            $0.conversationCounts = mockCounts
        }

        // Verify the helper function works
        #expect(store.state.conversationCount(for: "person-1") == 5)
        #expect(store.state.conversationCount(for: "person-2") == 3)
        #expect(store.state.conversationCount(for: "person-unknown") == 0)
    }
}
