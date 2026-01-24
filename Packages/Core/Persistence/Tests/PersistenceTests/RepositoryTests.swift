import Testing
import Foundation
import GRDB
import Models
@testable import Persistence

// MARK: - Session Repository Tests

@Test func testInsertAndFetchSession() async throws {
    // Create an in-memory database with migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    // Create a session record
    let sessionId = SessionID("session-1")
    let now = Date()
    let session = SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        endedAt: nil,
        title: "Test Session",
        previewText: "Hello world...",
        durationMs: 60000,
        audioPath: "/path/to/audio.m4a",
        processingState: .recording,
        speakerCount: 2,
        updatedAt: now
    )

    // Insert the session
    try await client.createSession(session)

    // Fetch all sessions
    let sessions = try await client.fetchSessions()
    #expect(sessions.count == 1)
    #expect(sessions[0].id == sessionId.rawValue)
    #expect(sessions[0].title == "Test Session")
    #expect(sessions[0].previewText == "Hello world...")
    #expect(sessions[0].durationMs == 60000)
    #expect(sessions[0].processingState == .recording)
    #expect(sessions[0].speakerCount == 2)

    // Fetch by ID
    let fetched = try await client.fetchSession(sessionId)
    #expect(fetched != nil)
    #expect(fetched?.id == sessionId.rawValue)
    #expect(fetched?.title == "Test Session")

    // Fetch non-existent session
    let notFound = try await client.fetchSession(SessionID("nonexistent"))
    #expect(notFound == nil)
}

@Test func testTranscriptSegmentOrdering() async throws {
    // Create an in-memory database with migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    // First create a session (required due to foreign key)
    let sessionId = SessionID("session-1")
    let now = Date()
    let session = SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        processingState: .recording,
        updatedAt: now
    )
    try await client.createSession(session)

    // Insert segments OUT OF ORDER to verify ordering works
    let segment3 = TranscriptSegmentRecord(
        id: "seg-3",
        sessionId: sessionId.rawValue,
        startMs: 5000,
        endMs: 7500,
        machineSpeakerId: "speaker-1",
        text: "Third segment",
        confidence: 0.95,
        isFinal: true,
        createdAt: now,
        updatedAt: now
    )
    let segment1 = TranscriptSegmentRecord(
        id: "seg-1",
        sessionId: sessionId.rawValue,
        startMs: 0,
        endMs: 2500,
        machineSpeakerId: "speaker-1",
        text: "First segment",
        confidence: 0.92,
        isFinal: true,
        createdAt: now,
        updatedAt: now
    )
    let segment2 = TranscriptSegmentRecord(
        id: "seg-2",
        sessionId: sessionId.rawValue,
        startMs: 2500,
        endMs: 5000,
        machineSpeakerId: "speaker-2",
        text: "Second segment",
        confidence: 0.88,
        isFinal: true,
        createdAt: now,
        updatedAt: now
    )

    // Insert in non-chronological order
    try await client.createTranscriptSegment(segment3)
    try await client.createTranscriptSegment(segment1)
    try await client.createTranscriptSegment(segment2)

    // Fetch segments - should be ordered by startMs
    let segments = try await client.fetchTranscriptSegments(sessionId)

    #expect(segments.count == 3)

    // Verify ordering by startMs
    #expect(segments[0].id == "seg-1")
    #expect(segments[0].startMs == 0)
    #expect(segments[0].text == "First segment")

    #expect(segments[1].id == "seg-2")
    #expect(segments[1].startMs == 2500)
    #expect(segments[1].text == "Second segment")

    #expect(segments[2].id == "seg-3")
    #expect(segments[2].startMs == 5000)
    #expect(segments[2].text == "Third segment")

    // Verify segments only for this session (create another session with segments)
    let sessionId2 = SessionID("session-2")
    let session2 = SessionRecord(
        id: sessionId2.rawValue,
        startedAt: now,
        processingState: .recording,
        updatedAt: now
    )
    try await client.createSession(session2)

    let otherSegment = TranscriptSegmentRecord(
        id: "other-seg",
        sessionId: sessionId2.rawValue,
        startMs: 0,
        endMs: 1000,
        text: "Other session segment",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    )
    try await client.createTranscriptSegment(otherSegment)

    // Fetch for first session should still only have 3 segments
    let session1Segments = try await client.fetchTranscriptSegments(sessionId)
    #expect(session1Segments.count == 3)

    // Fetch for second session should have 1 segment
    let session2Segments = try await client.fetchTranscriptSegments(sessionId2)
    #expect(session2Segments.count == 1)
    #expect(session2Segments[0].id == "other-seg")
}

// MARK: - Session Update and Delete Tests

@Test func testUpdateSession() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let sessionId = SessionID("session-1")
    let now = Date()
    var session = SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        title: "Original Title",
        processingState: .recording,
        updatedAt: now
    )

    try await client.createSession(session)

    // Update the session
    session.title = "Updated Title"
    session.processingState = .processed
    session.endedAt = now.addingTimeInterval(3600)
    session.durationMs = 3600000
    session.updatedAt = now.addingTimeInterval(3600)

    try await client.updateSession(session)

    let fetched = try await client.fetchSession(sessionId)
    #expect(fetched?.title == "Updated Title")
    #expect(fetched?.processingState == .processed)
    #expect(fetched?.durationMs == 3600000)
    #expect(fetched?.endedAt != nil)
}

@Test func testDeleteSession() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let sessionId = SessionID("session-1")
    let now = Date()
    let session = SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        processingState: .recording,
        updatedAt: now
    )

    try await client.createSession(session)

    // Verify it exists
    let before = try await client.fetchSession(sessionId)
    #expect(before != nil)

    // Delete it
    try await client.deleteSession(sessionId)

    // Verify it's gone
    let after = try await client.fetchSession(sessionId)
    #expect(after == nil)
}

// MARK: - People Repository Tests

@Test func testInsertAndFetchPerson() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let personId = PersonID("person-1")
    let now = Date()
    let person = PersonRecord(
        id: personId.rawValue,
        name: "Alice",
        colorToken: "vapor-blue",
        createdAt: now,
        updatedAt: now
    )

    try await client.createPerson(person)

    let fetched = try await client.fetchPerson(personId)
    #expect(fetched != nil)
    #expect(fetched?.name == "Alice")
    #expect(fetched?.colorToken == "vapor-blue")

    // Fetch all people
    let people = try await client.fetchPeople()
    #expect(people.count == 1)
}

@Test func testPeopleOrderedByName() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()

    // Insert in non-alphabetical order
    try await client.createPerson(PersonRecord(
        id: "person-z", name: "Zara", colorToken: "red", createdAt: now, updatedAt: now
    ))
    try await client.createPerson(PersonRecord(
        id: "person-a", name: "Alice", colorToken: "blue", createdAt: now, updatedAt: now
    ))
    try await client.createPerson(PersonRecord(
        id: "person-m", name: "Mike", colorToken: "green", createdAt: now, updatedAt: now
    ))

    let people = try await client.fetchPeople()
    #expect(people.count == 3)
    #expect(people[0].name == "Alice")
    #expect(people[1].name == "Mike")
    #expect(people[2].name == "Zara")
}

// MARK: - Speaker Track Repository Tests

@Test func testSpeakerTracksOrderedByDisplayOrder() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let sessionId = SessionID("session-1")
    let now = Date()

    // Create session first
    try await client.createSession(SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        processingState: .recording,
        updatedAt: now
    ))

    // Insert tracks out of display order
    try await client.createSpeakerTrack(SpeakerTrackRecord(
        id: "track-2",
        sessionId: sessionId.rawValue,
        machineSpeakerId: "speaker-B",
        displayOrder: 1
    ))
    try await client.createSpeakerTrack(SpeakerTrackRecord(
        id: "track-1",
        sessionId: sessionId.rawValue,
        machineSpeakerId: "speaker-A",
        displayOrder: 0
    ))

    let tracks = try await client.fetchSpeakerTracks(sessionId)
    #expect(tracks.count == 2)
    #expect(tracks[0].displayOrder == 0)
    #expect(tracks[0].machineSpeakerId == "speaker-A")
    #expect(tracks[1].displayOrder == 1)
    #expect(tracks[1].machineSpeakerId == "speaker-B")
}

// MARK: - Speaker Segment Repository Tests

@Test func testSpeakerSegmentsOrderedByStartMs() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let sessionId = SessionID("session-1")
    let now = Date()

    // Create session first
    try await client.createSession(SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        processingState: .recording,
        updatedAt: now
    ))

    // Insert segments out of order
    try await client.createSpeakerSegment(SpeakerSegmentRecord(
        id: "spk-seg-2",
        sessionId: sessionId.rawValue,
        startMs: 5000,
        endMs: 10000,
        machineSpeakerId: "speaker-B",
        score: 0.9
    ))
    try await client.createSpeakerSegment(SpeakerSegmentRecord(
        id: "spk-seg-1",
        sessionId: sessionId.rawValue,
        startMs: 0,
        endMs: 5000,
        machineSpeakerId: "speaker-A",
        score: 0.95
    ))

    let segments = try await client.fetchSpeakerSegments(sessionId)
    #expect(segments.count == 2)
    #expect(segments[0].startMs == 0)
    #expect(segments[0].machineSpeakerId == "speaker-A")
    #expect(segments[1].startMs == 5000)
    #expect(segments[1].machineSpeakerId == "speaker-B")
}

// MARK: - Cascade Delete Tests

@Test func testCascadeDeleteRemovesRelatedRecords() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let sessionId = SessionID("session-1")
    let now = Date()

    // Create session
    try await client.createSession(SessionRecord(
        id: sessionId.rawValue,
        startedAt: now,
        processingState: .recording,
        updatedAt: now
    ))

    // Add related records
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-1",
        sessionId: sessionId.rawValue,
        startMs: 0,
        endMs: 1000,
        text: "Hello",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))
    try await client.createSpeakerTrack(SpeakerTrackRecord(
        id: "track-1",
        sessionId: sessionId.rawValue,
        machineSpeakerId: "speaker-1",
        displayOrder: 0
    ))
    try await client.createSpeakerSegment(SpeakerSegmentRecord(
        id: "spk-1",
        sessionId: sessionId.rawValue,
        startMs: 0,
        endMs: 1000,
        machineSpeakerId: "speaker-1"
    ))

    // Verify related records exist
    #expect(try await client.fetchTranscriptSegments(sessionId).count == 1)
    #expect(try await client.fetchSpeakerTracks(sessionId).count == 1)
    #expect(try await client.fetchSpeakerSegments(sessionId).count == 1)

    // Delete session - should cascade
    try await client.deleteSession(sessionId)

    // Verify all related records are gone
    #expect(try await client.fetchTranscriptSegments(sessionId).count == 0)
    #expect(try await client.fetchSpeakerTracks(sessionId).count == 0)
    #expect(try await client.fetchSpeakerSegments(sessionId).count == 0)
}

// MARK: - Sessions Ordered by StartedAt (Descending)

@Test func testSessionsOrderedByStartedAtDescending() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()
    let yesterday = now.addingTimeInterval(-86400)
    let lastWeek = now.addingTimeInterval(-604800)

    // Insert in non-chronological order
    try await client.createSession(SessionRecord(
        id: "session-old",
        startedAt: lastWeek,
        processingState: .processed,
        updatedAt: lastWeek
    ))
    try await client.createSession(SessionRecord(
        id: "session-new",
        startedAt: now,
        processingState: .recording,
        updatedAt: now
    ))
    try await client.createSession(SessionRecord(
        id: "session-mid",
        startedAt: yesterday,
        processingState: .partial,
        updatedAt: yesterday
    ))

    let sessions = try await client.fetchSessions()
    #expect(sessions.count == 3)
    // Should be newest first (descending order)
    #expect(sessions[0].id == "session-new")
    #expect(sessions[1].id == "session-mid")
    #expect(sessions[2].id == "session-old")
}
