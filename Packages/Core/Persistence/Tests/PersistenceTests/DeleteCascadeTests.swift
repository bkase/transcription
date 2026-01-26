import Testing
import Foundation
import GRDB
import Models
@testable import Persistence

// MARK: - Delete Cascade Tests

/// Tests verifying that cascade delete removes all related artifacts
/// when a session is deleted.

@Test func testDeleteCascadesArtifacts() async throws {
    // Create an in-memory database with migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let sessionId = SessionID("session-cascade")
    let now = Date()

    // Create session
    try await client.createSession(SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        endedAt: now.addingTimeInterval(600),
        title: "Cascade Test Session",
        previewText: "Testing cascade delete",
        durationMs: 600000,
        audioPath: "/audio/cascade-test.caf",
        processingState: .processed,
        speakerCount: 3,
        updatedAt: now
    ))

    // Create multiple transcript segments
    for i in 0..<5 {
        try await client.createTranscriptSegment(TranscriptSegmentRecord(
            id: "seg-\(i)",
            sessionId: sessionId.rawValue,
            startMs: i * 2000,
            endMs: (i + 1) * 2000,
            machineSpeakerId: "speaker-\(i % 2)",
            text: "Segment \(i) text content",
            confidence: 0.9 + Double(i) * 0.01,
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ))
    }

    // Create multiple speaker tracks
    for i in 0..<3 {
        try await client.createSpeakerTrack(SpeakerTrackRecord(
            id: "track-\(i)",
            sessionId: sessionId.rawValue,
            machineSpeakerId: "speaker-\(i)",
            displayOrder: i,
            personId: nil
        ))
    }

    // Create multiple speaker segments
    for i in 0..<4 {
        try await client.createSpeakerSegment(SpeakerSegmentRecord(
            id: "spk-seg-\(i)",
            sessionId: sessionId.rawValue,
            startMs: i * 2500,
            endMs: (i + 1) * 2500,
            machineSpeakerId: "speaker-\(i % 2)",
            score: 0.85 + Double(i) * 0.03
        ))
    }

    // Verify all records exist
    let sessionBefore = try await client.fetchSession(sessionId)
    #expect(sessionBefore != nil)
    #expect(sessionBefore?.title == "Cascade Test Session")

    let segmentsBefore = try await client.fetchTranscriptSegments(sessionId)
    #expect(segmentsBefore.count == 5)

    let tracksBefore = try await client.fetchSpeakerTracks(sessionId)
    #expect(tracksBefore.count == 3)

    let speakerSegsBefore = try await client.fetchSpeakerSegments(sessionId)
    #expect(speakerSegsBefore.count == 4)

    // Delete the session
    try await client.deleteSession(sessionId)

    // Verify session is gone
    let sessionAfter = try await client.fetchSession(sessionId)
    #expect(sessionAfter == nil)

    // Verify all related records are cascade deleted
    let segmentsAfter = try await client.fetchTranscriptSegments(sessionId)
    #expect(segmentsAfter.isEmpty, "Transcript segments should be cascade deleted")

    let tracksAfter = try await client.fetchSpeakerTracks(sessionId)
    #expect(tracksAfter.isEmpty, "Speaker tracks should be cascade deleted")

    let speakerSegsAfter = try await client.fetchSpeakerSegments(sessionId)
    #expect(speakerSegsAfter.isEmpty, "Speaker segments should be cascade deleted")
}

@Test func testDeleteDoesNotAffectOtherSessions() async throws {
    // Create an in-memory database with migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()

    // Create two sessions
    let session1Id = SessionID("session-1")
    let session2Id = SessionID("session-2")

    try await client.createSession(SessionRecord(
        id: session1Id.rawValue,
        startedAt: now,
        title: "Session 1",
        processingState: .processed,
        updatedAt: now
    ))

    try await client.createSession(SessionRecord(
        id: session2Id.rawValue,
        startedAt: now.addingTimeInterval(100),
        title: "Session 2",
        processingState: .processed,
        updatedAt: now
    ))

    // Add segments to both sessions
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-s1-1",
        sessionId: session1Id.rawValue,
        startMs: 0,
        endMs: 1000,
        text: "Session 1 segment",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-s2-1",
        sessionId: session2Id.rawValue,
        startMs: 0,
        endMs: 1000,
        text: "Session 2 segment",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Add speaker tracks to both sessions
    try await client.createSpeakerTrack(SpeakerTrackRecord(
        id: "track-s1",
        sessionId: session1Id.rawValue,
        machineSpeakerId: "speaker-1",
        displayOrder: 0
    ))

    try await client.createSpeakerTrack(SpeakerTrackRecord(
        id: "track-s2",
        sessionId: session2Id.rawValue,
        machineSpeakerId: "speaker-1",
        displayOrder: 0
    ))

    // Verify both sessions have data
    #expect(try await client.fetchTranscriptSegments(session1Id).count == 1)
    #expect(try await client.fetchTranscriptSegments(session2Id).count == 1)
    #expect(try await client.fetchSpeakerTracks(session1Id).count == 1)
    #expect(try await client.fetchSpeakerTracks(session2Id).count == 1)

    // Delete session 1 only
    try await client.deleteSession(session1Id)

    // Verify session 1 and its data are gone
    #expect(try await client.fetchSession(session1Id) == nil)
    #expect(try await client.fetchTranscriptSegments(session1Id).isEmpty)
    #expect(try await client.fetchSpeakerTracks(session1Id).isEmpty)

    // Verify session 2 is unaffected
    let session2 = try await client.fetchSession(session2Id)
    #expect(session2 != nil)
    #expect(session2?.title == "Session 2")
    #expect(try await client.fetchTranscriptSegments(session2Id).count == 1)
    #expect(try await client.fetchSpeakerTracks(session2Id).count == 1)
}

@Test func testDeleteNonExistentSession() async throws {
    // Create an in-memory database with migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    // Deleting a non-existent session should not throw
    try await client.deleteSession(SessionID("nonexistent"))

    // Verify nothing in the database
    let sessions = try await client.fetchSessions()
    #expect(sessions.isEmpty)
}

@Test func testDeleteWithPersonAssignmentKeepsPerson() async throws {
    // Create an in-memory database with migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()
    let sessionId = SessionID("session-with-person")
    let personId = PersonID("person-alice")

    // Create a person
    try await client.createPerson(PersonRecord(
        id: personId.rawValue,
        name: "Alice",
        colorToken: "sky",
        createdAt: now,
        updatedAt: now
    ))

    // Create a session
    try await client.createSession(SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        title: "Session with Alice",
        processingState: .processed,
        updatedAt: now
    ))

    // Create a speaker track assigned to Alice
    try await client.createSpeakerTrack(SpeakerTrackRecord(
        id: "track-alice",
        sessionId: sessionId.rawValue,
        machineSpeakerId: "speaker-0",
        displayOrder: 0,
        personId: personId.rawValue
    ))

    // Verify setup
    let trackBefore = try await client.fetchSpeakerTracks(sessionId)
    #expect(trackBefore.count == 1)
    #expect(trackBefore[0].personId == personId.rawValue)

    let personBefore = try await client.fetchPerson(personId)
    #expect(personBefore != nil)

    // Delete the session
    try await client.deleteSession(sessionId)

    // Verify session and track are gone
    #expect(try await client.fetchSession(sessionId) == nil)
    #expect(try await client.fetchSpeakerTracks(sessionId).isEmpty)

    // Verify person still exists (ON DELETE SET NULL for personId, not CASCADE)
    let personAfter = try await client.fetchPerson(personId)
    #expect(personAfter != nil, "Person should not be deleted when session is deleted")
    #expect(personAfter?.name == "Alice")
}
