import Foundation
import Models
import Dependencies
import DependenciesMacros
import GRDB

// MARK: - Processing State

public enum ProcessingState: String, Codable, Sendable, DatabaseValueConvertible {
    case recording
    case transcribing
    case partial
    case processed
    case failed
}

// MARK: - Database Records

public struct SessionRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "sessions"

    public var id: String
    public var startedAt: Date
    public var endedAt: Date?
    public var title: String?
    public var previewText: String?
    public var durationMs: Int?
    public var audioPath: String?
    public var processingState: ProcessingState
    public var speakerCount: Int
    public var updatedAt: Date
    /// Error message when processingState is .failed (e.g., transcription error)
    public var processingError: String?

    public init(
        id: String,
        startedAt: Date,
        endedAt: Date? = nil,
        title: String? = nil,
        previewText: String? = nil,
        durationMs: Int? = nil,
        audioPath: String? = nil,
        processingState: ProcessingState = .recording,
        speakerCount: Int = 0,
        updatedAt: Date,
        processingError: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.previewText = previewText
        self.durationMs = durationMs
        self.audioPath = audioPath
        self.processingState = processingState
        self.speakerCount = speakerCount
        self.updatedAt = updatedAt
        self.processingError = processingError
    }
}

public struct PersonRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "people"

    public var id: String
    public var name: String
    public var colorToken: String
    public var imageData: Data?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        colorToken: String,
        imageData: Data? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.imageData = imageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SpeakerTrackRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "speaker_tracks"

    public var id: String
    public var sessionId: String
    public var machineSpeakerId: String
    public var displayOrder: Int
    public var personId: String?

    public init(
        id: String,
        sessionId: String,
        machineSpeakerId: String,
        displayOrder: Int,
        personId: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.machineSpeakerId = machineSpeakerId
        self.displayOrder = displayOrder
        self.personId = personId
    }
}

public struct TranscriptSegmentRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "transcript_segments"

    public var id: String
    public var sessionId: String
    public var startMs: Int
    public var endMs: Int
    public var machineSpeakerId: String?
    public var text: String
    public var confidence: Double?
    public var isFinal: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        sessionId: String,
        startMs: Int,
        endMs: Int,
        machineSpeakerId: String? = nil,
        text: String,
        confidence: Double? = nil,
        isFinal: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.startMs = startMs
        self.endMs = endMs
        self.machineSpeakerId = machineSpeakerId
        self.text = text
        self.confidence = confidence
        self.isFinal = isFinal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SpeakerSegmentRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "speaker_segments"

    public var id: String
    public var sessionId: String
    public var startMs: Int
    public var endMs: Int
    public var machineSpeakerId: String
    public var score: Double?
    public var isOverlap: Bool

    public init(
        id: String,
        sessionId: String,
        startMs: Int,
        endMs: Int,
        machineSpeakerId: String,
        score: Double? = nil,
        isOverlap: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.startMs = startMs
        self.endMs = endMs
        self.machineSpeakerId = machineSpeakerId
        self.score = score
        self.isOverlap = isOverlap
    }
}

// MARK: - Session Speaker Info

/// Speaker info for displaying in session cards.
/// Joins speaker_tracks with people table to get display data.
public struct SessionSpeakerInfo: Sendable, Equatable {
    public let sessionId: String
    public let machineSpeakerId: String
    public let displayOrder: Int
    public let personId: String?
    public let personName: String?
    public let personColorToken: String?
    public let personImageData: Data?

    public init(
        sessionId: String,
        machineSpeakerId: String,
        displayOrder: Int,
        personId: String? = nil,
        personName: String? = nil,
        personColorToken: String? = nil,
        personImageData: Data? = nil
    ) {
        self.sessionId = sessionId
        self.machineSpeakerId = machineSpeakerId
        self.displayOrder = displayOrder
        self.personId = personId
        self.personName = personName
        self.personColorToken = personColorToken
        self.personImageData = personImageData
    }
}

// MARK: - Search Result Types

/// A search result containing a session ID and its relevance score
public struct SessionSearchResult: Sendable, Equatable {
    public let sessionId: SessionID
    public let rank: Double

    public init(sessionId: SessionID, rank: Double) {
        self.sessionId = sessionId
        self.rank = rank
    }
}

/// Date bucket for grouping sessions in timeline
public enum DateBucket: String, Sendable, Equatable, CaseIterable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case older

    /// Calculate the date bucket for a given date relative to a reference date
    public static func bucket(for date: Date, relativeTo reference: Date, calendar: Calendar = .current) -> DateBucket {
        // Today
        if calendar.isDate(date, inSameDayAs: reference) {
            return .today
        }

        // Yesterday
        let startOfReferenceDay = calendar.startOfDay(for: reference)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfReferenceDay),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return .yesterday
        }

        // This week (not today or yesterday)
        if calendar.isDate(date, equalTo: reference, toGranularity: .weekOfYear) {
            return .thisWeek
        }

        // Last week
        if let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: reference),
           calendar.isDate(date, equalTo: lastWeekDate, toGranularity: .weekOfYear) {
            return .lastWeek
        }

        // This month (not in this or last week)
        if calendar.isDate(date, equalTo: reference, toGranularity: .month) {
            return .thisMonth
        }

        return .older
    }
}

/// A group of sessions in a specific date bucket
public struct SessionGroup: Sendable, Equatable {
    public let bucket: DateBucket
    public let sessions: [SessionRecord]

    public init(bucket: DateBucket, sessions: [SessionRecord]) {
        self.bucket = bucket
        self.sessions = sessions
    }
}

// MARK: - Migrations

public enum AppMigrations {
    public static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            // Sessions table
            try db.create(table: "sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
                t.column("title", .text)
                t.column("previewText", .text)
                t.column("durationMs", .integer)
                t.column("audioPath", .text)
                t.column("processingState", .text).notNull().defaults(to: "recording")
                t.column("speakerCount", .integer).notNull().defaults(to: 0)
                t.column("updatedAt", .datetime).notNull()
            }

            // People table
            try db.create(table: "people") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("colorToken", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Speaker tracks table
            try db.create(table: "speaker_tracks") { t in
                t.column("id", .text).primaryKey()
                t.column("sessionId", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("machineSpeakerId", .text).notNull()
                t.column("displayOrder", .integer).notNull()
                t.column("personId", .text)
                    .references("people", onDelete: .setNull)
            }

            // Transcript segments table
            try db.create(table: "transcript_segments") { t in
                t.column("id", .text).primaryKey()
                t.column("sessionId", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("startMs", .integer).notNull()
                t.column("endMs", .integer).notNull()
                t.column("machineSpeakerId", .text)
                t.column("text", .text).notNull()
                t.column("confidence", .double)
                t.column("isFinal", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Speaker segments table
            try db.create(table: "speaker_segments") { t in
                t.column("id", .text).primaryKey()
                t.column("sessionId", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("startMs", .integer).notNull()
                t.column("endMs", .integer).notNull()
                t.column("machineSpeakerId", .text).notNull()
                t.column("score", .double)
                t.column("isOverlap", .boolean).notNull().defaults(to: false)
            }

            // Indexes for common queries
            try db.create(index: "idx_sessions_startedAt", on: "sessions", columns: ["startedAt"])
            try db.create(index: "idx_sessions_processingState", on: "sessions", columns: ["processingState"])
            try db.create(index: "idx_speaker_tracks_sessionId", on: "speaker_tracks", columns: ["sessionId"])
            try db.create(index: "idx_transcript_segments_sessionId", on: "transcript_segments", columns: ["sessionId"])
            try db.create(index: "idx_transcript_segments_startMs", on: "transcript_segments", columns: ["sessionId", "startMs"])
            try db.create(index: "idx_speaker_segments_sessionId", on: "speaker_segments", columns: ["sessionId"])
        }

        migrator.registerMigration("v2_processing_error") { db in
            // Add processingError column to track transcription failure messages
            try db.alter(table: "sessions") { t in
                t.add(column: "processingError", .text)
            }
        }

        migrator.registerMigration("v3_fts5_search") { db in
            // Create FTS5 virtual table for transcript search
            // NOT using external content table because the column mapping differs (segmentId vs id)
            // We use triggers to keep it in sync manually
            // Use IF NOT EXISTS for idempotency in case of partial migration
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS transcript_fts USING fts5(
                    text,
                    sessionId UNINDEXED,
                    segmentId UNINDEXED
                )
                """)

            // Triggers to keep FTS index in sync with transcript_segments
            // Use IF NOT EXISTS for idempotency
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS transcript_fts_ai AFTER INSERT ON transcript_segments BEGIN
                    INSERT INTO transcript_fts(text, sessionId, segmentId)
                    VALUES (NEW.text, NEW.sessionId, NEW.id);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS transcript_fts_ad AFTER DELETE ON transcript_segments BEGIN
                    DELETE FROM transcript_fts WHERE segmentId = OLD.id;
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS transcript_fts_au AFTER UPDATE ON transcript_segments BEGIN
                    DELETE FROM transcript_fts WHERE segmentId = OLD.id;
                    INSERT INTO transcript_fts(text, sessionId, segmentId)
                    VALUES (NEW.text, NEW.sessionId, NEW.id);
                END
                """)
        }

        migrator.registerMigration("v4_person_image") { db in
            // Add imageData column to people table for profile photos
            try db.alter(table: "people") { t in
                t.add(column: "imageData", .blob)
            }
        }

        return migrator
    }
}

// MARK: - Database Setup

public struct DatabaseConfiguration: Sendable {
    public let path: String?

    public init(path: String? = nil) {
        self.path = path
    }

    public static let inMemory = DatabaseConfiguration(path: nil)

    public static func file(_ path: String) -> DatabaseConfiguration {
        DatabaseConfiguration(path: path)
    }
}

public func makeDatabase(configuration: DatabaseConfiguration) throws -> DatabaseQueue {
    let dbQueue: DatabaseQueue

    if let path = configuration.path {
        dbQueue = try DatabaseQueue(path: path)
    } else {
        dbQueue = try DatabaseQueue()
    }

    try AppMigrations.migrator.migrate(dbQueue)

    return dbQueue
}

// MARK: - DatabaseClient

@DependencyClient
public struct DatabaseClient: Sendable {
    public var fetchSessions: @Sendable () async throws -> [SessionRecord] = { [] }
    public var fetchSession: @Sendable (_ id: SessionID) async throws -> SessionRecord? = { _ in nil }
    public var createSession: @Sendable (_ record: SessionRecord) async throws -> Void
    public var updateSession: @Sendable (_ record: SessionRecord) async throws -> Void
    public var deleteSession: @Sendable (_ id: SessionID) async throws -> Void

    public var fetchPeople: @Sendable () async throws -> [PersonRecord] = { [] }
    public var fetchPerson: @Sendable (_ id: PersonID) async throws -> PersonRecord? = { _ in nil }
    public var createPerson: @Sendable (_ record: PersonRecord) async throws -> Void
    public var updatePerson: @Sendable (_ record: PersonRecord) async throws -> Void
    public var deletePerson: @Sendable (_ id: PersonID) async throws -> Void

    public var fetchSpeakerTracks: @Sendable (_ sessionId: SessionID) async throws -> [SpeakerTrackRecord] = { _ in [] }
    public var createSpeakerTrack: @Sendable (_ record: SpeakerTrackRecord) async throws -> Void
    public var updateSpeakerTrack: @Sendable (_ record: SpeakerTrackRecord) async throws -> Void
    public var deleteSpeakerTracksForSession: @Sendable (_ sessionId: SessionID) async throws -> Void

    public var fetchTranscriptSegments: @Sendable (_ sessionId: SessionID) async throws -> [TranscriptSegmentRecord] = { _ in [] }
    public var createTranscriptSegment: @Sendable (_ record: TranscriptSegmentRecord) async throws -> Void
    public var updateTranscriptSegment: @Sendable (_ record: TranscriptSegmentRecord) async throws -> Void
    public var deleteTranscriptSegmentsForSession: @Sendable (_ sessionId: SessionID) async throws -> Void

    public var fetchSpeakerSegments: @Sendable (_ sessionId: SessionID) async throws -> [SpeakerSegmentRecord] = { _ in [] }
    public var createSpeakerSegment: @Sendable (_ record: SpeakerSegmentRecord) async throws -> Void

    // Search
    public var searchSessions: @Sendable (_ query: String) async throws -> [SessionSearchResult] = { _ in [] }
    public var searchSessionsWithDetails: @Sendable (_ query: String) async throws -> [SessionRecord] = { _ in [] }
    public var fetchSessionsGroupedByDate: @Sendable (_ referenceDate: Date) async throws -> [SessionGroup] = { _ in [] }

    // Conversation counts (distinct sessions per person via speaker_tracks)
    public var fetchPersonConversationCounts: @Sendable () async throws -> [String: Int] = { [:] }

    // Fetch sessions where a person participated (via speaker_tracks)
    public var fetchSessionsForPerson: @Sendable (_ personId: PersonID) async throws -> [SessionRecord] = { _ in [] }

    // Recovery: fetch sessions stuck in recording state (stale recordings)
    public var fetchStaleRecordings: @Sendable () async throws -> [SessionRecord] = { [] }
    // Recovery: mark stale recordings as partial with endedAt set
    public var reconcileStaleRecordings: @Sendable (_ sessionIds: [SessionID], _ now: Date) async throws -> Int = { _, _ in 0 }
    // Recovery: mark sessions stuck in transcribing state as processed
    public var recoverStuckTranscriptions: @Sendable (_ olderThan: Date) async throws -> Int = { _ in 0 }

    /// Fetch speaker info for multiple sessions in a single query.
    /// Returns a dictionary mapping session ID to array of speaker info (track + person data).
    public var fetchSpeakerInfoForSessions: @Sendable (_ sessionIds: [SessionID]) async throws -> [String: [SessionSpeakerInfo]] = { _ in [:] }

    /// Delete all user data (sessions, transcripts, speakers, people) while preserving ML models.
    public var deleteAllData: @Sendable () async throws -> Void
}

extension DatabaseClient: DependencyKey {
    public static func live(dbQueue: DatabaseQueue) -> Self {
        Self(
            fetchSessions: {
                try await dbQueue.read { db in
                    try SessionRecord.order(Column("startedAt").desc).fetchAll(db)
                }
            },
            fetchSession: { id in
                try await dbQueue.read { db in
                    try SessionRecord.fetchOne(db, key: id.rawValue)
                }
            },
            createSession: { record in
                try await dbQueue.write { db in
                    try record.insert(db)
                }
            },
            updateSession: { record in
                try await dbQueue.write { db in
                    try record.update(db)
                }
            },
            deleteSession: { id in
                try await dbQueue.write { db in
                    _ = try SessionRecord.deleteOne(db, key: id.rawValue)
                }
            },
            fetchPeople: {
                try await dbQueue.read { db in
                    try PersonRecord.order(Column("name")).fetchAll(db)
                }
            },
            fetchPerson: { id in
                try await dbQueue.read { db in
                    try PersonRecord.fetchOne(db, key: id.rawValue)
                }
            },
            createPerson: { record in
                try await dbQueue.write { db in
                    try record.insert(db)
                }
            },
            updatePerson: { record in
                try await dbQueue.write { db in
                    try record.update(db)
                }
            },
            deletePerson: { id in
                try await dbQueue.write { db in
                    _ = try PersonRecord.deleteOne(db, key: id.rawValue)
                }
            },
            fetchSpeakerTracks: { sessionId in
                try await dbQueue.read { db in
                    try SpeakerTrackRecord
                        .filter(Column("sessionId") == sessionId.rawValue)
                        .order(Column("displayOrder"))
                        .fetchAll(db)
                }
            },
            createSpeakerTrack: { record in
                try await dbQueue.write { db in
                    try record.insert(db)
                }
            },
            updateSpeakerTrack: { record in
                try await dbQueue.write { db in
                    try record.update(db)
                }
            },
            deleteSpeakerTracksForSession: { sessionId in
                try await dbQueue.write { db in
                    _ = try SpeakerTrackRecord
                        .filter(Column("sessionId") == sessionId.rawValue)
                        .deleteAll(db)
                }
            },
            fetchTranscriptSegments: { sessionId in
                try await dbQueue.read { db in
                    try TranscriptSegmentRecord
                        .filter(Column("sessionId") == sessionId.rawValue)
                        .order(Column("startMs"))
                        .fetchAll(db)
                }
            },
            createTranscriptSegment: { record in
                try await dbQueue.write { db in
                    try record.insert(db)
                }
            },
            updateTranscriptSegment: { record in
                try await dbQueue.write { db in
                    try record.update(db)
                }
            },
            deleteTranscriptSegmentsForSession: { sessionId in
                try await dbQueue.write { db in
                    _ = try TranscriptSegmentRecord
                        .filter(Column("sessionId") == sessionId.rawValue)
                        .deleteAll(db)
                }
            },
            fetchSpeakerSegments: { sessionId in
                try await dbQueue.read { db in
                    try SpeakerSegmentRecord
                        .filter(Column("sessionId") == sessionId.rawValue)
                        .order(Column("startMs"))
                        .fetchAll(db)
                }
            },
            createSpeakerSegment: { record in
                try await dbQueue.write { db in
                    try record.insert(db)
                }
            },
            searchSessions: { query in
                try await dbQueue.read { db in
                    // FTS5 search returns ranked session IDs
                    // Using rank column from FTS5 match (lower rank = more relevant)
                    // We join with sessions to get proper ordering and aggregate matches per session
                    let sql = """
                        SELECT sessionId, COUNT(*) as matchCount
                        FROM transcript_fts
                        WHERE transcript_fts MATCH ?
                        GROUP BY sessionId
                        ORDER BY matchCount DESC
                        """
                    let rows = try Row.fetchAll(db, sql: sql, arguments: [query])
                    return rows.map { row in
                        SessionSearchResult(
                            sessionId: SessionID(row["sessionId"] as String),
                            rank: Double(row["matchCount"] as Int64)
                        )
                    }
                }
            },
            searchSessionsWithDetails: { query in
                try await dbQueue.read { db in
                    // FTS5 search with full session details
                    // Join with sessions table to get all fields, ordered by match count
                    let sql = """
                        SELECT sessions.*, COUNT(*) as matchCount
                        FROM transcript_fts
                        INNER JOIN sessions ON sessions.id = transcript_fts.sessionId
                        WHERE transcript_fts MATCH ?
                        GROUP BY transcript_fts.sessionId
                        ORDER BY matchCount DESC, sessions.startedAt DESC
                        """
                    return try SessionRecord.fetchAll(db, sql: sql, arguments: [query])
                }
            },
            fetchSessionsGroupedByDate: { referenceDate in
                try await dbQueue.read { db in
                    let sessions = try SessionRecord
                        .order(Column("startedAt").desc)
                        .fetchAll(db)

                    // Group sessions by date bucket
                    var groups: [DateBucket: [SessionRecord]] = [:]
                    for session in sessions {
                        let bucket = DateBucket.bucket(for: session.startedAt, relativeTo: referenceDate)
                        groups[bucket, default: []].append(session)
                    }

                    // Return in order of DateBucket.allCases (today first, older last)
                    return DateBucket.allCases.compactMap { bucket in
                        guard let sessions = groups[bucket], !sessions.isEmpty else { return nil }
                        return SessionGroup(bucket: bucket, sessions: sessions)
                    }
                }
            },
            fetchPersonConversationCounts: {
                try await dbQueue.read { db in
                    // Count distinct sessions per person via speaker_tracks
                    let sql = """
                        SELECT personId, COUNT(DISTINCT sessionId) as conversationCount
                        FROM speaker_tracks
                        WHERE personId IS NOT NULL
                        GROUP BY personId
                        """
                    let rows = try Row.fetchAll(db, sql: sql)
                    var counts: [String: Int] = [:]
                    for row in rows {
                        if let personId = row["personId"] as? String {
                            counts[personId] = Int(row["conversationCount"] as Int64)
                        }
                    }
                    return counts
                }
            },
            fetchSessionsForPerson: { personId in
                try await dbQueue.read { db in
                    // Fetch all sessions where the person participated via speaker_tracks
                    let sql = """
                        SELECT DISTINCT sessions.*
                        FROM sessions
                        INNER JOIN speaker_tracks ON sessions.id = speaker_tracks.sessionId
                        WHERE speaker_tracks.personId = ?
                        ORDER BY sessions.startedAt DESC
                        """
                    return try SessionRecord.fetchAll(db, sql: sql, arguments: [personId.rawValue])
                }
            },
            fetchStaleRecordings: {
                try await dbQueue.read { db in
                    // Find sessions that are in 'recording' state but have no endedAt
                    // These are sessions that were interrupted (app crash, force close, etc.)
                    try SessionRecord
                        .filter(Column("processingState") == ProcessingState.recording.rawValue)
                        .filter(Column("endedAt") == nil)
                        .order(Column("startedAt").desc)
                        .fetchAll(db)
                }
            },
            reconcileStaleRecordings: { sessionIds, now in
                guard !sessionIds.isEmpty else { return 0 }
                return try await dbQueue.write { db in
                    var count = 0
                    for sessionId in sessionIds {
                        // Update each stale session to partial state with endedAt set
                        let updateSQL = """
                            UPDATE sessions
                            SET processingState = ?,
                                endedAt = ?,
                                updatedAt = ?
                            WHERE id = ? AND processingState = ?
                            """
                        try db.execute(
                            sql: updateSQL,
                            arguments: [
                                ProcessingState.partial.rawValue,
                                now,
                                now,
                                sessionId.rawValue,
                                ProcessingState.recording.rawValue
                            ]
                        )
                        count += db.changesCount
                    }
                    return count
                }
            },
            recoverStuckTranscriptions: { olderThan in
                try await dbQueue.write { db in
                    // Find sessions stuck in 'transcribing' state that were updated before the cutoff
                    // These are sessions where transcription was interrupted or timed out
                    // We use updatedAt because that's when the session entered transcribing state
                    let updateSQL = """
                        UPDATE sessions
                        SET processingState = ?,
                            processingError = ?,
                            updatedAt = ?
                        WHERE processingState = ?
                        AND updatedAt < ?
                        """
                    try db.execute(
                        sql: updateSQL,
                        arguments: [
                            ProcessingState.partial.rawValue,
                            "Transcription was interrupted or timed out",
                            Date(),
                            ProcessingState.transcribing.rawValue,
                            olderThan
                        ]
                    )
                    return db.changesCount
                }
            },
            fetchSpeakerInfoForSessions: { sessionIds in
                guard !sessionIds.isEmpty else { return [:] }
                return try await dbQueue.read { db in
                    // Build placeholders for IN clause
                    let placeholders = sessionIds.map { _ in "?" }.joined(separator: ", ")
                    let sql = """
                        SELECT
                            st.sessionId,
                            st.machineSpeakerId,
                            st.displayOrder,
                            st.personId,
                            p.name as personName,
                            p.colorToken as personColorToken,
                            p.imageData as personImageData
                        FROM speaker_tracks st
                        LEFT JOIN people p ON st.personId = p.id
                        WHERE st.sessionId IN (\(placeholders))
                        ORDER BY st.sessionId, st.displayOrder
                        """
                    let arguments = StatementArguments(sessionIds.map { $0.rawValue })
                    let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)

                    var result: [String: [SessionSpeakerInfo]] = [:]
                    for row in rows {
                        let info = SessionSpeakerInfo(
                            sessionId: row["sessionId"],
                            machineSpeakerId: row["machineSpeakerId"],
                            displayOrder: Int(row["displayOrder"] as Int64),
                            personId: row["personId"],
                            personName: row["personName"],
                            personColorToken: row["personColorToken"],
                            personImageData: row["personImageData"]
                        )
                        result[info.sessionId, default: []].append(info)
                    }
                    return result
                }
            },
            deleteAllData: {
                try await dbQueue.write { db in
                    // Delete all data from tables in dependency order
                    // FTS index is automatically cleared via triggers when transcript_segments are deleted
                    try db.execute(sql: "DELETE FROM speaker_segments")
                    try db.execute(sql: "DELETE FROM transcript_segments")
                    try db.execute(sql: "DELETE FROM speaker_tracks")
                    try db.execute(sql: "DELETE FROM sessions")
                    try db.execute(sql: "DELETE FROM people")
                }
            }
        )
    }

    public static let liveValue: Self = {
        // Create database in Application Support directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDirectory = appSupport.appendingPathComponent("Vapor", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

        let dbPath = dbDirectory.appendingPathComponent("vapor.sqlite").path
        let dbQueue = try! makeDatabase(configuration: .file(dbPath))

        return .live(dbQueue: dbQueue)
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}
