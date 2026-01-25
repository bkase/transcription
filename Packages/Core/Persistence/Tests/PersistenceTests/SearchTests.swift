import Testing
import Foundation
import GRDB
import Models
@testable import Persistence

// MARK: - FTS Search Tests

@Test func testFtsSearchReturnsRankedSessions() async throws {
    // Create an in-memory database with migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()

    // Create sessions
    try await client.createSession(SessionRecord(
        id: "session-1",
        startedAt: now,
        processingState: .processed,
        updatedAt: now
    ))
    try await client.createSession(SessionRecord(
        id: "session-2",
        startedAt: now.addingTimeInterval(-3600),
        processingState: .processed,
        updatedAt: now
    ))
    try await client.createSession(SessionRecord(
        id: "session-3",
        startedAt: now.addingTimeInterval(-7200),
        processingState: .processed,
        updatedAt: now
    ))

    // Add transcript segments with searchable text
    // Session 1: mentions "swift" once
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-1-1",
        sessionId: "session-1",
        startMs: 0,
        endMs: 5000,
        text: "Let's talk about swift programming today.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Session 2: mentions "swift" multiple times - should rank higher
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-2-1",
        sessionId: "session-2",
        startMs: 0,
        endMs: 5000,
        text: "Swift is a great language. I love swift. Swift swift swift!",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-2-2",
        sessionId: "session-2",
        startMs: 5000,
        endMs: 10000,
        text: "Swift development is fun.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Session 3: no mention of "swift"
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-3-1",
        sessionId: "session-3",
        startMs: 0,
        endMs: 5000,
        text: "Python is also a nice language.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Search for "swift"
    let results = try await client.searchSessions("swift")

    // Should find sessions 1 and 2, but not 3
    #expect(results.count == 2)

    // Session 2 should rank higher (lower bm25 score) because it has more matches
    let sessionIds = results.map { $0.sessionId.rawValue }
    #expect(sessionIds.contains("session-1"))
    #expect(sessionIds.contains("session-2"))
    #expect(!sessionIds.contains("session-3"))

    // Verify session-2 ranks higher (appears first due to better relevance)
    #expect(results[0].sessionId.rawValue == "session-2")
    #expect(results[1].sessionId.rawValue == "session-1")
}

@Test func testSearchSessionsWithDetailsReturnsFullRecords() async throws {
    // Test that searchSessionsWithDetails returns full SessionRecord objects
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()

    // Create sessions with full details
    try await client.createSession(SessionRecord(
        id: "session-1",
        startedAt: now,
        title: "Swift Programming",
        previewText: "Discussion about Swift",
        durationMs: 60000,
        processingState: .processed,
        speakerCount: 2,
        updatedAt: now
    ))
    try await client.createSession(SessionRecord(
        id: "session-2",
        startedAt: now.addingTimeInterval(-3600),
        title: "Python Basics",
        previewText: "Introduction to Python",
        durationMs: 45000,
        processingState: .processed,
        speakerCount: 1,
        updatedAt: now
    ))

    // Add transcript segments
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-1",
        sessionId: "session-1",
        startMs: 0,
        endMs: 5000,
        text: "Let's talk about swift programming.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-2",
        sessionId: "session-2",
        startMs: 0,
        endMs: 5000,
        text: "Python is a versatile language.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Search for "swift" - should return full session record
    let results = try await client.searchSessionsWithDetails("swift")

    #expect(results.count == 1)

    let session = results[0]
    #expect(session.id == "session-1")
    #expect(session.title == "Swift Programming")
    #expect(session.previewText == "Discussion about Swift")
    #expect(session.durationMs == 60000)
    #expect(session.speakerCount == 2)
    #expect(session.processingState == .processed)
}

@Test func testSearchSessionsWithDetailsPreservesRanking() async throws {
    // Test that results are ordered by match count (relevance)
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()

    // Create sessions
    try await client.createSession(SessionRecord(
        id: "session-few-matches",
        startedAt: now,
        title: "Few Mentions",
        processingState: .processed,
        updatedAt: now
    ))
    try await client.createSession(SessionRecord(
        id: "session-many-matches",
        startedAt: now.addingTimeInterval(-3600),
        title: "Many Mentions",
        processingState: .processed,
        updatedAt: now
    ))

    // Session with few matches
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-1",
        sessionId: "session-few-matches",
        startMs: 0,
        endMs: 5000,
        text: "One mention of swift here.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Session with many matches (more segments with "swift")
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-2a",
        sessionId: "session-many-matches",
        startMs: 0,
        endMs: 5000,
        text: "Swift is great!",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-2b",
        sessionId: "session-many-matches",
        startMs: 5000,
        endMs: 10000,
        text: "More swift content here.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-2c",
        sessionId: "session-many-matches",
        startMs: 10000,
        endMs: 15000,
        text: "Swift swift swift!",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Search should return many-matches first (higher relevance)
    let results = try await client.searchSessionsWithDetails("swift")

    #expect(results.count == 2)
    #expect(results[0].id == "session-many-matches")
    #expect(results[1].id == "session-few-matches")
}

@Test func testFtsSearchReturnsEmptyForNoMatches() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()

    // Create a session with transcript
    try await client.createSession(SessionRecord(
        id: "session-1",
        startedAt: now,
        processingState: .processed,
        updatedAt: now
    ))
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-1",
        sessionId: "session-1",
        startMs: 0,
        endMs: 5000,
        text: "Hello world, this is a test.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Search for something not in transcripts
    let results = try await client.searchSessions("xyznonexistent")
    #expect(results.isEmpty)
}

@Test func testFtsIndexUpdatesOnSegmentChange() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()

    // Create session and segment
    try await client.createSession(SessionRecord(
        id: "session-1",
        startedAt: now,
        processingState: .processed,
        updatedAt: now
    ))
    try await client.createTranscriptSegment(TranscriptSegmentRecord(
        id: "seg-1",
        sessionId: "session-1",
        startMs: 0,
        endMs: 5000,
        text: "Initial text about cats.",
        isFinal: true,
        createdAt: now,
        updatedAt: now
    ))

    // Verify initial search works
    let catsResults = try await client.searchSessions("cats")
    #expect(catsResults.count == 1)

    let dogsResults = try await client.searchSessions("dogs")
    #expect(dogsResults.isEmpty)

    // Update the segment text
    var segment = (try await client.fetchTranscriptSegments(SessionID("session-1")))[0]
    segment.text = "Updated text about dogs."
    try await client.updateTranscriptSegment(segment)

    // Verify FTS index was updated
    let catsAfter = try await client.searchSessions("cats")
    #expect(catsAfter.isEmpty)

    let dogsAfter = try await client.searchSessions("dogs")
    #expect(dogsAfter.count == 1)
}

// MARK: - Timeline Grouping Tests

@Test func testTimelineGroupingByDate() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let calendar = Calendar.current
    let now = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
    let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)! // Still "this week" usually
    let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
    let twoWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -2, to: now)!

    // Create sessions at different times
    try await client.createSession(SessionRecord(
        id: "session-today",
        startedAt: now,
        processingState: .processed,
        updatedAt: now
    ))
    try await client.createSession(SessionRecord(
        id: "session-yesterday",
        startedAt: yesterday,
        processingState: .processed,
        updatedAt: yesterday
    ))
    try await client.createSession(SessionRecord(
        id: "session-this-week",
        startedAt: twoDaysAgo,
        processingState: .processed,
        updatedAt: twoDaysAgo
    ))
    try await client.createSession(SessionRecord(
        id: "session-last-week",
        startedAt: lastWeek,
        processingState: .processed,
        updatedAt: lastWeek
    ))
    try await client.createSession(SessionRecord(
        id: "session-older",
        startedAt: twoWeeksAgo,
        processingState: .processed,
        updatedAt: twoWeeksAgo
    ))

    // Fetch grouped sessions
    let groups = try await client.fetchSessionsGroupedByDate(now)

    // Verify we have the expected buckets
    let buckets = groups.map { $0.bucket }

    // Today
    #expect(buckets.contains(.today))
    let todayGroup = groups.first { $0.bucket == .today }!
    #expect(todayGroup.sessions.count == 1)
    #expect(todayGroup.sessions[0].id == "session-today")

    // Yesterday
    #expect(buckets.contains(.yesterday))
    let yesterdayGroup = groups.first { $0.bucket == .yesterday }!
    #expect(yesterdayGroup.sessions.count == 1)
    #expect(yesterdayGroup.sessions[0].id == "session-yesterday")

    // Groups are in order (today first, older last)
    #expect(groups[0].bucket == .today)
    #expect(groups[1].bucket == .yesterday)
}

@Test func testTimelineGroupingEmptyDatabase() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    let groups = try await client.fetchSessionsGroupedByDate(Date())
    #expect(groups.isEmpty)
}

@Test func testDateBucketCalculation() throws {
    let calendar = Calendar.current
    let reference = Date()

    // Today
    #expect(DateBucket.bucket(for: reference, relativeTo: reference) == .today)

    // Yesterday
    let yesterday = calendar.date(byAdding: .day, value: -1, to: reference)!
    #expect(DateBucket.bucket(for: yesterday, relativeTo: reference) == .yesterday)

    // Two weeks ago should be older (past last week)
    let twoWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -2, to: reference)!
    let bucket = DateBucket.bucket(for: twoWeeksAgo, relativeTo: reference)
    // Could be thisMonth or older depending on current date in month
    #expect(bucket == .thisMonth || bucket == .older)
}

@Test func testTimelineGroupingPreservesOrderWithinBucket() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let client = DatabaseClient.live(dbQueue: dbQueue)

    // Use a fixed reference date at noon to avoid timezone boundary issues
    let calendar = Calendar.current
    let now = Date()
    let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!

    // Create multiple sessions today at different times (all clearly within today)
    try await client.createSession(SessionRecord(
        id: "session-early",
        startedAt: noon.addingTimeInterval(-3600), // 11:00 AM
        processingState: .processed,
        updatedAt: noon
    ))
    try await client.createSession(SessionRecord(
        id: "session-later",
        startedAt: noon.addingTimeInterval(-1800), // 11:30 AM
        processingState: .processed,
        updatedAt: noon
    ))
    try await client.createSession(SessionRecord(
        id: "session-newest",
        startedAt: noon, // 12:00 PM
        processingState: .processed,
        updatedAt: noon
    ))

    let groups = try await client.fetchSessionsGroupedByDate(noon)

    #expect(groups.count == 1)
    #expect(groups[0].bucket == .today)
    #expect(groups[0].sessions.count == 3)

    // Should be ordered by startedAt descending (newest first)
    #expect(groups[0].sessions[0].id == "session-newest")
    #expect(groups[0].sessions[1].id == "session-later")
    #expect(groups[0].sessions[2].id == "session-early")
}
