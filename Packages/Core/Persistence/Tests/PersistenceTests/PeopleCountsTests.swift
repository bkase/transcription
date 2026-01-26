import Testing
import Foundation
@testable import Persistence

/// Tests for conversation count computation from speaker track assignments.
/// These tests verify the SQL query that counts distinct sessions per person.

@Test func testCountsComputedFromAssignments() async throws {
    // Create an in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let mockDate = Date(timeIntervalSince1970: 1000000)

    // Create two sessions
    let session1 = SessionRecord(
        id: "session-1",
        startedAt: mockDate,
        processingState: .processed,
        speakerCount: 2,
        updatedAt: mockDate
    )
    try await databaseClient.createSession(session1)

    let session2 = SessionRecord(
        id: "session-2",
        startedAt: mockDate,
        processingState: .processed,
        speakerCount: 1,
        updatedAt: mockDate
    )
    try await databaseClient.createSession(session2)

    // Create two people
    let personAlice = PersonRecord(
        id: "person-alice",
        name: "Alice Smith",
        colorToken: "sky",
        createdAt: mockDate,
        updatedAt: mockDate
    )
    try await databaseClient.createPerson(personAlice)

    let personBob = PersonRecord(
        id: "person-bob",
        name: "Bob Jones",
        colorToken: "lavender",
        createdAt: mockDate,
        updatedAt: mockDate
    )
    try await databaseClient.createPerson(personBob)

    // Initially, no assignments = no counts
    var counts = try await databaseClient.fetchPersonConversationCounts()
    #expect(counts.isEmpty)

    // Assign Alice to session 1
    let track1 = SpeakerTrackRecord(
        id: "track-1",
        sessionId: "session-1",
        machineSpeakerId: "speaker_0",
        displayOrder: 1,
        personId: "person-alice"
    )
    try await databaseClient.createSpeakerTrack(track1)

    counts = try await databaseClient.fetchPersonConversationCounts()
    #expect(counts["person-alice"] == 1)
    #expect(counts["person-bob"] == nil)

    // Assign Alice to session 2 as well
    let track2 = SpeakerTrackRecord(
        id: "track-2",
        sessionId: "session-2",
        machineSpeakerId: "speaker_0",
        displayOrder: 1,
        personId: "person-alice"
    )
    try await databaseClient.createSpeakerTrack(track2)

    counts = try await databaseClient.fetchPersonConversationCounts()
    #expect(counts["person-alice"] == 2)

    // Assign Bob to session 1
    let track3 = SpeakerTrackRecord(
        id: "track-3",
        sessionId: "session-1",
        machineSpeakerId: "speaker_1",
        displayOrder: 2,
        personId: "person-bob"
    )
    try await databaseClient.createSpeakerTrack(track3)

    counts = try await databaseClient.fetchPersonConversationCounts()
    #expect(counts["person-alice"] == 2)
    #expect(counts["person-bob"] == 1)
}

@Test func testCountsUseDistinctSessions() async throws {
    // Verify that multiple speaker tracks in the same session count as 1 conversation
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let mockDate = Date(timeIntervalSince1970: 1000000)

    // Create one session
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
        name: "Alice",
        colorToken: "sky",
        createdAt: mockDate,
        updatedAt: mockDate
    )
    try await databaseClient.createPerson(person)

    // Create multiple speaker tracks in the same session, all assigned to the same person
    // (this can happen if ML misidentified speakers and user corrects them to the same person)
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

    // Count should be 1, not 2 (uses DISTINCT sessionId)
    let counts = try await databaseClient.fetchPersonConversationCounts()
    #expect(counts["person-1"] == 1)
}

@Test func testCountsIgnoreUnassignedTracks() async throws {
    // Verify that speaker tracks without a personId don't appear in counts
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
        name: "Alice",
        colorToken: "sky",
        createdAt: mockDate,
        updatedAt: mockDate
    )
    try await databaseClient.createPerson(person)

    // Create an unassigned speaker track (personId is nil)
    let unassignedTrack = SpeakerTrackRecord(
        id: "track-1",
        sessionId: "session-1",
        machineSpeakerId: "speaker_0",
        displayOrder: 1,
        personId: nil
    )
    try await databaseClient.createSpeakerTrack(unassignedTrack)

    // Counts should be empty since no tracks are assigned
    let counts = try await databaseClient.fetchPersonConversationCounts()
    #expect(counts.isEmpty)
}
