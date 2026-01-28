import Testing
import GRDB
@testable import Persistence

@Test func testMigrationsCreateTables() throws {
    // Create an in-memory database and run migrations
    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Verify all expected tables exist
    let expectedTables = [
        "sessions",
        "people",
        "speaker_tracks",
        "transcript_segments",
        "speaker_segments"
    ]

    try dbQueue.read { db in
        for tableName in expectedTables {
            let tableExists = try db.tableExists(tableName)
            #expect(tableExists, "Table '\(tableName)' should exist")
        }
    }
}

@Test func testSessionsTableHasCorrectColumns() throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    try dbQueue.read { db in
        let columns = try db.columns(in: "sessions")
        let columnNames = Set(columns.map { $0.name })

        let expectedColumns: Set<String> = [
            "id",
            "startedAt",
            "endedAt",
            "title",
            "previewText",
            "durationMs",
            "audioPath",
            "processingState",
            "speakerCount",
            "updatedAt",
            "processingError"
        ]

        #expect(columnNames == expectedColumns, "Sessions table should have all expected columns")
    }
}

@Test func testPeopleTableHasCorrectColumns() throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    try dbQueue.read { db in
        let columns = try db.columns(in: "people")
        let columnNames = Set(columns.map { $0.name })

        let expectedColumns: Set<String> = [
            "id",
            "name",
            "colorToken",
            "imageData",
            "createdAt",
            "updatedAt"
        ]

        #expect(columnNames == expectedColumns, "People table should have all expected columns")
    }
}

@Test func testSpeakerTracksTableHasCorrectColumns() throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    try dbQueue.read { db in
        let columns = try db.columns(in: "speaker_tracks")
        let columnNames = Set(columns.map { $0.name })

        let expectedColumns: Set<String> = [
            "id",
            "sessionId",
            "machineSpeakerId",
            "displayOrder",
            "personId"
        ]

        #expect(columnNames == expectedColumns, "Speaker tracks table should have all expected columns")
    }
}

@Test func testTranscriptSegmentsTableHasCorrectColumns() throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    try dbQueue.read { db in
        let columns = try db.columns(in: "transcript_segments")
        let columnNames = Set(columns.map { $0.name })

        let expectedColumns: Set<String> = [
            "id",
            "sessionId",
            "startMs",
            "endMs",
            "machineSpeakerId",
            "text",
            "confidence",
            "isFinal",
            "createdAt",
            "updatedAt"
        ]

        #expect(columnNames == expectedColumns, "Transcript segments table should have all expected columns")
    }
}

@Test func testSpeakerSegmentsTableHasCorrectColumns() throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    try dbQueue.read { db in
        let columns = try db.columns(in: "speaker_segments")
        let columnNames = Set(columns.map { $0.name })

        let expectedColumns: Set<String> = [
            "id",
            "sessionId",
            "startMs",
            "endMs",
            "machineSpeakerId",
            "score",
            "isOverlap"
        ]

        #expect(columnNames == expectedColumns, "Speaker segments table should have all expected columns")
    }
}

@Test func testIndexesAreCreated() throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    try dbQueue.read { db in
        // Check indexes exist
        let indexes = try db.indexes(on: "sessions")
        let indexNames = Set(indexes.map { $0.name })

        #expect(indexNames.contains("idx_sessions_startedAt"), "Index on sessions.startedAt should exist")
        #expect(indexNames.contains("idx_sessions_processingState"), "Index on sessions.processingState should exist")
    }
}

@Test func testMigrationIsIdempotent() throws {
    // Running migrations multiple times should not fail
    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Run migrator again - should be a no-op
    try AppMigrations.migrator.migrate(dbQueue)

    // Verify tables still exist
    try dbQueue.read { db in
        let tableExists = try db.tableExists("sessions")
        #expect(tableExists, "Table 'sessions' should still exist after running migrations again")
    }
}
