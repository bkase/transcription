import Testing
import Foundation
import Dependencies
import Models
import Persistence
import Observability
@testable import Processing

// MARK: - Recovery Routine Tests

@Test func testInterruptedRecordingReconciled() async throws {
    // Create an in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Track logged messages
    actor LogCapture {
        var logs: [String] = []
        func append(_ message: String) {
            logs.append(message)
        }
    }
    let logCapture = LogCapture()

    // Create stale sessions (in recording state, no endedAt)
    let now = Date()
    let staleSession1 = SessionRecord(
        id: "stale-session-1",
        startedAt: now.addingTimeInterval(-3600), // 1 hour ago
        endedAt: nil,
        processingState: .recording,
        speakerCount: 0,
        updatedAt: now.addingTimeInterval(-3600)
    )
    let staleSession2 = SessionRecord(
        id: "stale-session-2",
        startedAt: now.addingTimeInterval(-7200), // 2 hours ago
        endedAt: nil,
        processingState: .recording,
        speakerCount: 0,
        updatedAt: now.addingTimeInterval(-7200)
    )
    // Non-stale session (already processed)
    let processedSession = SessionRecord(
        id: "processed-session",
        startedAt: now.addingTimeInterval(-86400), // yesterday
        endedAt: now.addingTimeInterval(-86400 + 3600),
        processingState: .processed,
        speakerCount: 2,
        updatedAt: now.addingTimeInterval(-86400 + 3600)
    )

    try await databaseClient.createSession(staleSession1)
    try await databaseClient.createSession(staleSession2)
    try await databaseClient.createSession(processedSession)

    // Run recovery routine with dependencies injected
    let result = try await withDependencies {
        $0.databaseClient = databaseClient
        $0.loggingClient = LoggingClient(
            log: { entry in
                await logCapture.append("[\(entry.level)] \(entry.message)")
            },
            currentTraceId: { nil },
            setTraceId: { _ in },
            startTrace: { TraceID("test-trace") },
            endTrace: { }
        )
        $0.date = .constant(now)
    } operation: {
        try await RecoveryRoutineClient.live().run()
    }

    // Verify recovery result
    #expect(result.staleSessionIds.count == 2)
    #expect(result.reconciledCount == 2)

    // Check that session IDs are correct
    let staleIds = Set(result.staleSessionIds.map(\.rawValue))
    #expect(staleIds.contains("stale-session-1"))
    #expect(staleIds.contains("stale-session-2"))

    // Verify sessions were updated in the database
    let updatedSession1 = try await databaseClient.fetchSession(SessionID("stale-session-1"))
    #expect(updatedSession1?.processingState == .partial)
    #expect(updatedSession1?.endedAt != nil)

    let updatedSession2 = try await databaseClient.fetchSession(SessionID("stale-session-2"))
    #expect(updatedSession2?.processingState == .partial)
    #expect(updatedSession2?.endedAt != nil)

    // Verify processed session was not touched
    let unchanged = try await databaseClient.fetchSession(SessionID("processed-session"))
    #expect(unchanged?.processingState == .processed)

    // Verify logging
    let logs = await logCapture.logs
    #expect(logs.contains { $0.contains("Starting recovery routine") })
    #expect(logs.contains { $0.contains("Found 2 stale recording") })
    #expect(logs.contains { $0.contains("Reconciled 2 stale recording") })
}

@Test func testRecoveryWithNoStaleRecordings() async throws {
    // Create an in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()
    // Only create a processed session (no stale ones)
    let processedSession = SessionRecord(
        id: "processed-session",
        startedAt: now.addingTimeInterval(-86400),
        endedAt: now.addingTimeInterval(-86400 + 3600),
        processingState: .processed,
        speakerCount: 2,
        updatedAt: now.addingTimeInterval(-86400 + 3600)
    )
    try await databaseClient.createSession(processedSession)

    // Run recovery routine
    let result = try await withDependencies {
        $0.databaseClient = databaseClient
        $0.loggingClient = LoggingClient(
            log: { _ in },
            currentTraceId: { nil },
            setTraceId: { _ in },
            startTrace: { TraceID("test-trace") },
            endTrace: { }
        )
        $0.date = .constant(now)
    } operation: {
        try await RecoveryRoutineClient.live().run()
    }

    // Verify no stale recordings were found
    #expect(result == .empty)
    #expect(result.staleSessionIds.isEmpty)
    #expect(result.reconciledCount == 0)
}

@Test func testRecoveryWithPartialStateSessions() async throws {
    // Create an in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let now = Date()
    // Session already in partial state (previously recovered)
    let partialSession = SessionRecord(
        id: "partial-session",
        startedAt: now.addingTimeInterval(-3600),
        endedAt: now.addingTimeInterval(-1800), // has endedAt
        processingState: .partial,
        speakerCount: 1,
        updatedAt: now.addingTimeInterval(-1800)
    )
    // Session in recording state but with endedAt (shouldn't happen, but test edge case)
    let recordingWithEndedAt = SessionRecord(
        id: "recording-with-endedat",
        startedAt: now.addingTimeInterval(-7200),
        endedAt: now.addingTimeInterval(-3600),
        processingState: .recording,
        speakerCount: 0,
        updatedAt: now.addingTimeInterval(-3600)
    )
    // Actually stale session
    let staleSession = SessionRecord(
        id: "stale-session",
        startedAt: now.addingTimeInterval(-1800),
        endedAt: nil,
        processingState: .recording,
        speakerCount: 0,
        updatedAt: now.addingTimeInterval(-1800)
    )

    try await databaseClient.createSession(partialSession)
    try await databaseClient.createSession(recordingWithEndedAt)
    try await databaseClient.createSession(staleSession)

    // Run recovery routine
    let result = try await withDependencies {
        $0.databaseClient = databaseClient
        $0.loggingClient = LoggingClient(
            log: { _ in },
            currentTraceId: { nil },
            setTraceId: { _ in },
            startTrace: { TraceID("test-trace") },
            endTrace: { }
        )
        $0.date = .constant(now)
    } operation: {
        try await RecoveryRoutineClient.live().run()
    }

    // Only the truly stale session (recording + no endedAt) should be found
    #expect(result.staleSessionIds.count == 1)
    #expect(result.staleSessionIds.first?.rawValue == "stale-session")
    #expect(result.reconciledCount == 1)
}
