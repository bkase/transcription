import Foundation
import Models
import Persistence
import Audio
import Dependencies
import DependenciesMacros
import ZIPFoundation

// MARK: - Export Schema Models

/// Top-level export transcript structure containing all session data
/// This is the JSON representation used in transcript.json
public struct ExportTranscript: Codable, Equatable, Sendable {
    /// Schema version for forward/backward compatibility
    public let schemaVersion: String
    /// Session metadata
    public let session: ExportSession
    /// Ordered transcript segments
    public let segments: [ExportSegment]
    /// Speaker tracks with mappings to people
    public let speakerTracks: [ExportSpeakerTrack]
    /// People referenced by speaker tracks
    public let people: [ExportPerson]

    public init(
        schemaVersion: String = "1.0",
        session: ExportSession,
        segments: [ExportSegment],
        speakerTracks: [ExportSpeakerTrack],
        people: [ExportPerson]
    ) {
        self.schemaVersion = schemaVersion
        self.session = session
        self.segments = segments
        self.speakerTracks = speakerTracks
        self.people = people
    }
}

/// Session metadata for export
public struct ExportSession: Codable, Equatable, Sendable {
    /// Unique session identifier
    public let id: String
    /// When the recording started (ISO 8601)
    public let startedAt: Date
    /// When the recording ended (ISO 8601), nil if still recording
    public let endedAt: Date?
    /// Optional user-provided title
    public let title: String?
    /// Total duration in milliseconds
    public let durationMs: Int?
    /// Number of distinct speakers detected
    public let speakerCount: Int
    /// Relative path to audio file in bundle
    public let audioPath: String?

    public init(
        id: String,
        startedAt: Date,
        endedAt: Date?,
        title: String?,
        durationMs: Int?,
        speakerCount: Int,
        audioPath: String?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.durationMs = durationMs
        self.speakerCount = speakerCount
        self.audioPath = audioPath
    }

    /// Create from a SessionRecord
    public init(from record: SessionRecord, audioPath: String? = nil) {
        self.id = record.id
        self.startedAt = record.startedAt
        self.endedAt = record.endedAt
        self.title = record.title
        self.durationMs = record.durationMs
        self.speakerCount = record.speakerCount
        self.audioPath = audioPath ?? record.audioPath
    }
}

/// A transcript segment for export
public struct ExportSegment: Codable, Equatable, Sendable {
    /// Unique segment identifier
    public let id: String
    /// Start time in milliseconds from session start
    public let startMs: Int
    /// End time in milliseconds from session start
    public let endMs: Int
    /// Machine speaker ID (e.g., "spk_0")
    public let speakerId: String?
    /// Transcribed text content
    public let text: String
    /// Confidence score (0.0 to 1.0)
    public let confidence: Double?

    public init(
        id: String,
        startMs: Int,
        endMs: Int,
        speakerId: String?,
        text: String,
        confidence: Double?
    ) {
        self.id = id
        self.startMs = startMs
        self.endMs = endMs
        self.speakerId = speakerId
        self.text = text
        self.confidence = confidence
    }

    /// Create from a TranscriptSegmentRecord
    public init(from record: TranscriptSegmentRecord) {
        self.id = record.id
        self.startMs = record.startMs
        self.endMs = record.endMs
        self.speakerId = record.machineSpeakerId
        self.text = record.text
        self.confidence = record.confidence
    }
}

/// A speaker track mapping machine speaker to person
public struct ExportSpeakerTrack: Codable, Equatable, Sendable {
    /// Machine speaker ID (e.g., "spk_0")
    public let speakerId: String
    /// Display order (1 = "Speaker 1")
    public let displayOrder: Int
    /// Person ID if assigned, nil otherwise
    public let personId: String?

    public init(speakerId: String, displayOrder: Int, personId: String?) {
        self.speakerId = speakerId
        self.displayOrder = displayOrder
        self.personId = personId
    }

    /// Create from a SpeakerTrackRecord
    public init(from record: SpeakerTrackRecord) {
        self.speakerId = record.machineSpeakerId
        self.displayOrder = record.displayOrder
        self.personId = record.personId
    }
}

/// A person record for export
public struct ExportPerson: Codable, Equatable, Sendable {
    /// Unique person identifier
    public let id: String
    /// Display name
    public let name: String
    /// Color token for UI display
    public let colorToken: String

    public init(id: String, name: String, colorToken: String) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
    }

    /// Create from a PersonRecord
    public init(from record: PersonRecord) {
        self.id = record.id
        self.name = record.name
        self.colorToken = record.colorToken
    }
}

/// Metadata about the export bundle
/// This is stored in metadata.json
public struct ExportMetadata: Codable, Equatable, Sendable {
    /// Schema version for the metadata format
    public let schemaVersion: String
    /// App version that created the export
    public let appVersion: String
    /// Build number
    public let buildNumber: String
    /// Timestamp when export was created (ISO 8601)
    public let exportedAt: Date
    /// Optional trace ID for debugging
    public let traceId: String?
    /// Processing statistics
    public let stats: ExportStats

    public init(
        schemaVersion: String = "1.0",
        appVersion: String,
        buildNumber: String,
        exportedAt: Date,
        traceId: String?,
        stats: ExportStats
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.exportedAt = exportedAt
        self.traceId = traceId
        self.stats = stats
    }
}

/// Processing statistics for the export
public struct ExportStats: Codable, Equatable, Sendable {
    /// Number of transcript segments
    public let segmentCount: Int
    /// Number of speaker tracks
    public let speakerTrackCount: Int
    /// Total duration in milliseconds
    public let durationMs: Int?
    /// Number of assigned speakers (with personId)
    public let assignedSpeakerCount: Int

    public init(
        segmentCount: Int,
        speakerTrackCount: Int,
        durationMs: Int?,
        assignedSpeakerCount: Int
    ) {
        self.segmentCount = segmentCount
        self.speakerTrackCount = speakerTrackCount
        self.durationMs = durationMs
        self.assignedSpeakerCount = assignedSpeakerCount
    }
}

// MARK: - Export Bundle Assembly

/// Helper to assemble export data from database records
public enum ExportAssembler {
    /// Create ExportTranscript from database records
    public static func assembleTranscript(
        session: SessionRecord,
        segments: [TranscriptSegmentRecord],
        speakerTracks: [SpeakerTrackRecord],
        people: [PersonRecord],
        audioPath: String? = nil
    ) -> ExportTranscript {
        // Only include people that are referenced by speaker tracks
        let referencedPersonIds = Set(speakerTracks.compactMap(\.personId))
        let referencedPeople = people.filter { referencedPersonIds.contains($0.id) }

        return ExportTranscript(
            session: ExportSession(from: session, audioPath: audioPath),
            segments: segments.map(ExportSegment.init(from:)),
            speakerTracks: speakerTracks.map(ExportSpeakerTrack.init(from:)),
            people: referencedPeople.map(ExportPerson.init(from:))
        )
    }

    /// Create ExportMetadata with the given parameters
    public static func assembleMetadata(
        appVersion: String,
        buildNumber: String,
        exportedAt: Date,
        traceId: String?,
        segmentCount: Int,
        speakerTracks: [SpeakerTrackRecord],
        durationMs: Int?
    ) -> ExportMetadata {
        let assignedCount = speakerTracks.filter { $0.personId != nil }.count

        return ExportMetadata(
            appVersion: appVersion,
            buildNumber: buildNumber,
            exportedAt: exportedAt,
            traceId: traceId,
            stats: ExportStats(
                segmentCount: segmentCount,
                speakerTrackCount: speakerTracks.count,
                durationMs: durationMs,
                assignedSpeakerCount: assignedCount
            )
        )
    }
}

// MARK: - JSON Encoder Configuration

extension JSONEncoder {
    /// Configured encoder for export JSON files
    public static var exportEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    /// Configured decoder for import JSON files
    public static var exportDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - ExportFormat

/// Supported export formats
public enum ExportFormat: String, Sendable, CaseIterable {
    case json
    case markdown
    case vtt
}

// MARK: - ExportResult

/// Result of an export operation
public struct ExportResult: Sendable, Equatable {
    public let url: URL
    public let format: ExportFormat

    public init(url: URL, format: ExportFormat) {
        self.url = url
        self.format = format
    }
}

// MARK: - ExportClient

/// Client for exporting session data
@DependencyClient
public struct ExportClient: Sendable {
    /// Export a session to the specified format
    public var exportSession: @Sendable (_ sessionId: SessionID, _ format: ExportFormat) async throws -> ExportResult
    /// Export a session to all formats as a bundle
    public var exportBundle: @Sendable (_ sessionId: SessionID) async throws -> URL
    /// Export all sessions to a combined zip bundle
    public var exportAllSessions: @Sendable () async throws -> URL
    /// Get available export formats
    public var availableFormats: @Sendable () -> [ExportFormat] = { ExportFormat.allCases }
}

/// Error thrown by ExportClient operations
public enum ExportError: Error, Equatable, Sendable {
    case sessionNotFound(SessionID)
    case exportFailed(String)
}

extension ExportClient: DependencyKey {
    /// Create a live ExportClient with default app version info
    public static func live(
        appVersion: String = "1.0.0",
        buildNumber: String = "1"
    ) -> Self {
        @Dependency(\.databaseClient) var databaseClient
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.preferencesClient) var preferencesClient
        @Dependency(\.date) var date
        @Dependency(\.uuid) var uuid

        return Self(
            exportSession: { sessionId, format in
                // Fetch session data
                guard let session = try await databaseClient.fetchSession(sessionId) else {
                    throw ExportError.sessionNotFound(sessionId)
                }

                let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
                let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)
                let people = try await databaseClient.fetchPeople()

                // Assemble transcript
                let transcript = ExportAssembler.assembleTranscript(
                    session: session,
                    segments: segments,
                    speakerTracks: speakerTracks,
                    people: people
                )

                // Generate content based on format
                let content: String
                let fileExtension: String
                switch format {
                case .json:
                    let data = try JSONEncoder.exportEncoder.encode(transcript)
                    content = String(data: data, encoding: .utf8) ?? ""
                    fileExtension = "json"
                case .markdown:
                    content = MarkdownWriter.write(transcript)
                    fileExtension = "md"
                case .vtt:
                    content = VttWriter.write(transcript)
                    fileExtension = "vtt"
                }

                // Write to temp file
                let tempDir = fileClient.temporaryDirectory()
                let fileName = "\(uuid().uuidString).\(fileExtension)"
                let outputURL = tempDir.appendingPathComponent(fileName)
                try await fileClient.write(Data(content.utf8), outputURL)

                return ExportResult(url: outputURL, format: format)
            },
            exportBundle: { sessionId in
                // Fetch session data
                guard let session = try await databaseClient.fetchSession(sessionId) else {
                    throw ExportError.sessionNotFound(sessionId)
                }

                let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
                let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)
                let people = try await databaseClient.fetchPeople()

                // Determine audio source URL if available
                let audioSourceURL: URL?
                if let audioPath = session.audioPath {
                    audioSourceURL = URL(fileURLWithPath: audioPath)
                } else {
                    audioSourceURL = nil
                }

                // Assemble transcript and metadata
                let transcript = ExportAssembler.assembleTranscript(
                    session: session,
                    segments: segments,
                    speakerTracks: speakerTracks,
                    people: people,
                    audioPath: audioSourceURL != nil ? ExportBundleWriter.BundleFile.audio : nil
                )

                let metadata = ExportAssembler.assembleMetadata(
                    appVersion: appVersion,
                    buildNumber: buildNumber,
                    exportedAt: date.now,
                    traceId: nil,
                    segmentCount: segments.count,
                    speakerTracks: speakerTracks,
                    durationMs: session.durationMs
                )

                // Get privacy mode
                let retentionMode = preferencesClient.getAudioRetentionMode()

                // Create bundle
                let tempDir = fileClient.temporaryDirectory()
                let bundleName = "export-\(sessionId.rawValue)"

                let result = try await ExportBundleWriter.writeBundleWithPrivacy(
                    transcript: transcript,
                    metadata: metadata,
                    audioSourceURL: audioSourceURL,
                    outputDirectory: tempDir,
                    bundleName: bundleName,
                    fileClient: fileClient,
                    retentionMode: retentionMode
                )

                return result.url
            },
            exportAllSessions: {
                // Fetch all sessions
                let sessions = try await databaseClient.fetchSessions()
                let people = try await databaseClient.fetchPeople()

                // Get privacy mode
                let retentionMode = preferencesClient.getAudioRetentionMode()

                // Create a staging directory for all session bundles
                let tempDir = fileClient.temporaryDirectory()
                let timestamp = ISO8601DateFormatter().string(from: date.now)
                    .replacingOccurrences(of: ":", with: "-")
                let exportName = "vapor-export-\(timestamp)"
                let stagingDirectory = tempDir.appendingPathComponent(exportName)
                try await fileClient.createDirectory(stagingDirectory)

                // Process each session
                for session in sessions {
                    let sessionId = SessionID(rawValue: session.id)
                    let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
                    let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)

                    // Determine audio source URL if available
                    let audioSourceURL: URL?
                    if let audioPath = session.audioPath {
                        audioSourceURL = URL(fileURLWithPath: audioPath)
                    } else {
                        audioSourceURL = nil
                    }

                    // Assemble transcript and metadata
                    let transcript = ExportAssembler.assembleTranscript(
                        session: session,
                        segments: segments,
                        speakerTracks: speakerTracks,
                        people: people,
                        audioPath: audioSourceURL != nil ? ExportBundleWriter.BundleFile.audio : nil
                    )

                    let metadata = ExportAssembler.assembleMetadata(
                        appVersion: appVersion,
                        buildNumber: buildNumber,
                        exportedAt: date.now,
                        traceId: nil,
                        segmentCount: segments.count,
                        speakerTracks: speakerTracks,
                        durationMs: session.durationMs
                    )

                    // Create session subdirectory
                    let sessionName = session.title ?? session.id
                    let safeName = sessionName.replacingOccurrences(of: "/", with: "-")
                        .replacingOccurrences(of: ":", with: "-")
                    let sessionDir = stagingDirectory.appendingPathComponent(safeName)
                    try await fileClient.createDirectory(sessionDir)

                    // Write session bundle files directly (not zipped)
                    let metadataData = try JSONEncoder.exportEncoder.encode(metadata)
                    let metadataURL = sessionDir.appendingPathComponent(ExportBundleWriter.BundleFile.metadata)
                    try await fileClient.write(metadataData, metadataURL)

                    // Include transcript artifacts unless audioOnly mode
                    if retentionMode != .audioOnly {
                        let transcriptData = try JSONEncoder.exportEncoder.encode(transcript)
                        let transcriptURL = sessionDir.appendingPathComponent(ExportBundleWriter.BundleFile.transcript)
                        try await fileClient.write(transcriptData, transcriptURL)

                        let markdownContent = MarkdownWriter.write(transcript)
                        let markdownURL = sessionDir.appendingPathComponent(ExportBundleWriter.BundleFile.markdown)
                        try await fileClient.write(Data(markdownContent.utf8), markdownURL)

                        let vttContent = VttWriter.write(transcript)
                        let vttURL = sessionDir.appendingPathComponent(ExportBundleWriter.BundleFile.vtt)
                        try await fileClient.write(Data(vttContent.utf8), vttURL)
                    }

                    // Include audio unless transcriptOnly mode
                    if retentionMode != .transcriptOnly, let audioSourceURL = audioSourceURL, fileClient.exists(audioSourceURL) {
                        let audioData = try await fileClient.read(audioSourceURL)
                        let audioDestURL = sessionDir.appendingPathComponent(ExportBundleWriter.BundleFile.audio)
                        try await fileClient.write(audioData, audioDestURL)
                    }
                }

                // Create the final zip archive
                let zipURL = tempDir.appendingPathComponent("\(exportName).zip")
                try ExportBundleWriter.createZipArchiveRecursive(from: stagingDirectory, to: zipURL)

                // Clean up staging directory
                try await fileClient.delete(stagingDirectory)

                return zipURL
            },
            availableFormats: { ExportFormat.allCases }
        )
    }

    public static var liveValue: Self { live() }
    public static var testValue: Self { Self() }
}

extension DependencyValues {
    public var exportClient: ExportClient {
        get { self[ExportClient.self] }
        set { self[ExportClient.self] = newValue }
    }
}

// MARK: - FileClient

/// Client for file system operations
@DependencyClient
public struct FileClient: Sendable {
    /// Read data from a file
    public var read: @Sendable (_ url: URL) async throws -> Data
    /// Write data to a file
    public var write: @Sendable (_ data: Data, _ url: URL) async throws -> Void
    /// Delete a file
    public var delete: @Sendable (_ url: URL) async throws -> Void
    /// Check if a file exists
    public var exists: @Sendable (_ url: URL) -> Bool = { _ in false }
    /// Create a directory
    public var createDirectory: @Sendable (_ url: URL) async throws -> Void
    /// Get temporary directory URL
    public var temporaryDirectory: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
}

/// Error thrown by FileClient operations
public enum FileClientError: Error, Equatable, Sendable {
    case fileNotFound(URL)
    case writeError(String)
}

/// In-memory file storage for testing
/// Uses a class with locks to support synchronous `exists` calls
public final class InMemoryFileStorage: @unchecked Sendable {
    /// Stored file data keyed by URL path
    private var files: [String: Data] = [:]
    /// Set of created directories
    private var directories: Set<String> = []
    /// Temp directory base path
    public let tempDirectory: URL
    /// Lock for thread-safe access
    private let lock = NSLock()

    public init(tempDirectory: URL = URL(fileURLWithPath: "/tmp/vapor-test")) {
        self.tempDirectory = tempDirectory
    }

    /// Read data from a file
    public func read(_ url: URL) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let data = files[url.path] else {
            throw FileClientError.fileNotFound(url)
        }
        return data
    }

    /// Write data to a file
    public func write(_ data: Data, to url: URL) {
        lock.lock()
        defer { lock.unlock() }
        files[url.path] = data
    }

    /// Delete a file
    public func delete(_ url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        // Allow deleting files
        if files.removeValue(forKey: url.path) != nil {
            return
        }
        // Allow deleting directories (remove all files with that prefix)
        let prefix = url.path.hasSuffix("/") ? url.path : url.path + "/"
        var deletedAny = false
        for key in files.keys where key.hasPrefix(prefix) {
            files.removeValue(forKey: key)
            deletedAny = true
        }
        if directories.remove(url.path) != nil {
            deletedAny = true
        }
        if !deletedAny {
            throw FileClientError.fileNotFound(url)
        }
    }

    /// Check if a file exists
    public func exists(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return files[url.path] != nil || directories.contains(url.path)
    }

    /// Create a directory
    public func createDirectory(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        directories.insert(url.path)
    }

    /// Get all stored file paths (for testing)
    public func allFilePaths() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(files.keys).sorted()
    }

    /// Reset storage (for testing)
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        files.removeAll()
        directories.removeAll()
    }
}

extension FileClient: DependencyKey {
    public static var liveValue: Self {
        let fileManager = FileManager.default
        return Self(
            read: { url in try Data(contentsOf: url) },
            write: { data, url in try data.write(to: url) },
            delete: { url in try fileManager.removeItem(at: url) },
            exists: { url in fileManager.fileExists(atPath: url.path) },
            createDirectory: { url in
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            },
            temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) }
        )
    }

    public static var testValue: Self { Self() }

    /// Create an in-memory FileClient for testing
    /// - Parameters:
    ///   - storage: Optional shared storage. If nil, creates a new one.
    ///   - tempDirectory: URL for temporary directory. Defaults to /tmp/vapor-test
    /// - Returns: A FileClient backed by in-memory storage
    public static func inMemory(
        storage: InMemoryFileStorage? = nil,
        tempDirectory: URL = URL(fileURLWithPath: "/tmp/vapor-test")
    ) -> Self {
        let storage = storage ?? InMemoryFileStorage(tempDirectory: tempDirectory)
        return Self(
            read: { url in try storage.read(url) },
            write: { data, url in storage.write(data, to: url) },
            delete: { url in try storage.delete(url) },
            exists: { url in storage.exists(url) },
            createDirectory: { url in storage.createDirectory(url) },
            temporaryDirectory: { storage.tempDirectory }
        )
    }
}

extension DependencyValues {
    public var fileClient: FileClient {
        get { self[FileClient.self] }
        set { self[FileClient.self] = newValue }
    }
}

// MARK: - Markdown Writer

/// Generates human-readable Markdown from an ExportTranscript
public enum MarkdownWriter {
    /// Generate Markdown representation of the transcript
    public static func write(_ transcript: ExportTranscript) -> String {
        var output = ""

        // Title
        let title = transcript.session.title ?? "Transcript"
        output += "# \(title)\n\n"

        // Session metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let formattedDate = dateFormatter.string(from: transcript.session.startedAt)
        output += "**Date:** \(formattedDate)\n"

        if let durationMs = transcript.session.durationMs {
            let durationFormatted = formatDuration(milliseconds: durationMs)
            output += "**Duration:** \(durationFormatted)\n"
        }

        if transcript.session.speakerCount > 0 {
            output += "**Speakers:** \(transcript.session.speakerCount)\n"
        }

        output += "\n---\n\n"

        // Build speaker lookup
        let speakerLookup = buildSpeakerLookup(transcript)

        // Transcript segments
        for segment in transcript.segments {
            let speakerName = resolveSpeakerName(segment.speakerId, lookup: speakerLookup)
            let timestamp = formatTimestamp(milliseconds: segment.startMs)

            output += "**\(speakerName)** (\(timestamp))\n"
            output += "\(segment.text)\n\n"
        }

        return output
    }

    /// Build a lookup from machine speaker ID to display name
    private static func buildSpeakerLookup(_ transcript: ExportTranscript) -> [String: String] {
        var lookup: [String: String] = [:]
        let peopleLookup = Dictionary(uniqueKeysWithValues: transcript.people.map { ($0.id, $0.name) })

        for track in transcript.speakerTracks {
            if let personId = track.personId, let name = peopleLookup[personId] {
                lookup[track.speakerId] = name
            } else {
                lookup[track.speakerId] = "Speaker \(track.displayOrder)"
            }
        }

        return lookup
    }

    /// Resolve speaker ID to display name
    private static func resolveSpeakerName(_ speakerId: String?, lookup: [String: String]) -> String {
        guard let id = speakerId else { return "Unknown" }
        return lookup[id] ?? "Unknown"
    }

    /// Format milliseconds as HH:MM:SS or MM:SS
    private static func formatDuration(milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format milliseconds as MM:SS for timestamps
    private static func formatTimestamp(milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - VTT Writer

/// Generates WebVTT captions from an ExportTranscript
public enum VttWriter {
    /// Generate VTT representation of the transcript
    public static func write(_ transcript: ExportTranscript) -> String {
        var output = "WEBVTT\n\n"

        // Build speaker lookup
        let speakerLookup = buildSpeakerLookup(transcript)

        // Write each segment as a cue
        for (index, segment) in transcript.segments.enumerated() {
            let cueNumber = index + 1
            let startTime = formatVttTimestamp(milliseconds: segment.startMs)
            let endTime = formatVttTimestamp(milliseconds: segment.endMs)
            let speakerName = resolveSpeakerName(segment.speakerId, lookup: speakerLookup)

            output += "\(cueNumber)\n"
            output += "\(startTime) --> \(endTime)\n"
            output += "<v \(speakerName)>\(segment.text)\n\n"
        }

        return output
    }

    /// Build a lookup from machine speaker ID to display name
    private static func buildSpeakerLookup(_ transcript: ExportTranscript) -> [String: String] {
        var lookup: [String: String] = [:]
        let peopleLookup = Dictionary(uniqueKeysWithValues: transcript.people.map { ($0.id, $0.name) })

        for track in transcript.speakerTracks {
            if let personId = track.personId, let name = peopleLookup[personId] {
                lookup[track.speakerId] = name
            } else {
                lookup[track.speakerId] = "Speaker \(track.displayOrder)"
            }
        }

        return lookup
    }

    /// Resolve speaker ID to display name
    private static func resolveSpeakerName(_ speakerId: String?, lookup: [String: String]) -> String {
        guard let id = speakerId else { return "Unknown" }
        return lookup[id] ?? "Unknown"
    }

    /// Format milliseconds as VTT timestamp (HH:MM:SS.mmm)
    private static func formatVttTimestamp(milliseconds: Int) -> String {
        let ms = milliseconds % 1000
        let totalSeconds = milliseconds / 1000
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600

        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, ms)
    }
}

// MARK: - Bundle Writer

/// Creates a zip bundle containing all export artifacts
public enum ExportBundleWriter {
    /// Standard filenames used in export bundles
    public enum BundleFile {
        public static let audio = "audio.caf"
        public static let transcript = "transcript.json"
        public static let markdown = "transcript.md"
        public static let vtt = "transcript.vtt"
        public static let metadata = "metadata.json"
    }

    /// Result of bundle creation
    public struct BundleResult: Sendable, Equatable {
        public let url: URL
        public let files: [String]

        public init(url: URL, files: [String]) {
            self.url = url
            self.files = files
        }
    }

    /// Create an export bundle zip file
    /// - Parameters:
    ///   - transcript: The export transcript data
    ///   - metadata: The export metadata
    ///   - audioSourceURL: Optional URL to the source audio file to include
    ///   - outputDirectory: Directory to write the bundle to
    ///   - bundleName: Name for the bundle (without .zip extension)
    ///   - fileClient: File client for I/O operations
    /// - Returns: URL to the created zip file and list of files included
    public static func writeBundle(
        transcript: ExportTranscript,
        metadata: ExportMetadata,
        audioSourceURL: URL?,
        outputDirectory: URL,
        bundleName: String,
        fileClient: FileClient
    ) async throws -> BundleResult {
        // Create a staging directory for bundle contents
        let stagingDirectory = outputDirectory.appendingPathComponent(bundleName)
        try await fileClient.createDirectory(stagingDirectory)

        var includedFiles: [String] = []

        // Write transcript.json
        let transcriptData = try JSONEncoder.exportEncoder.encode(transcript)
        let transcriptURL = stagingDirectory.appendingPathComponent(BundleFile.transcript)
        try await fileClient.write(transcriptData, transcriptURL)
        includedFiles.append(BundleFile.transcript)

        // Write metadata.json
        let metadataData = try JSONEncoder.exportEncoder.encode(metadata)
        let metadataURL = stagingDirectory.appendingPathComponent(BundleFile.metadata)
        try await fileClient.write(metadataData, metadataURL)
        includedFiles.append(BundleFile.metadata)

        // Write transcript.md
        let markdownContent = MarkdownWriter.write(transcript)
        let markdownURL = stagingDirectory.appendingPathComponent(BundleFile.markdown)
        try await fileClient.write(Data(markdownContent.utf8), markdownURL)
        includedFiles.append(BundleFile.markdown)

        // Write transcript.vtt
        let vttContent = VttWriter.write(transcript)
        let vttURL = stagingDirectory.appendingPathComponent(BundleFile.vtt)
        try await fileClient.write(Data(vttContent.utf8), vttURL)
        includedFiles.append(BundleFile.vtt)

        // Copy audio file if provided
        if let audioSourceURL = audioSourceURL, fileClient.exists(audioSourceURL) {
            let audioData = try await fileClient.read(audioSourceURL)
            let audioDestURL = stagingDirectory.appendingPathComponent(BundleFile.audio)
            try await fileClient.write(audioData, audioDestURL)
            includedFiles.append(BundleFile.audio)
        }

        // Create zip file
        let zipURL = outputDirectory.appendingPathComponent("\(bundleName).zip")
        try createZipArchive(from: stagingDirectory, to: zipURL)

        // Clean up staging directory
        try await fileClient.delete(stagingDirectory)

        return BundleResult(url: zipURL, files: includedFiles)
    }

    /// Create a zip archive from a directory's contents
    private static func createZipArchive(from sourceDirectory: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default

        // Remove existing zip if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Create the archive using ZIPFoundation
        let archive = try Archive(url: destinationURL, accessMode: .create)

        // Get contents of source directory and add each file
        let contents = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: nil
        )

        for fileURL in contents {
            // Add each file at the root level of the archive (just the filename)
            try archive.addEntry(
                with: fileURL.lastPathComponent,
                relativeTo: sourceDirectory
            )
        }
    }

    /// Create a zip archive recursively from a directory including subdirectories
    public static func createZipArchiveRecursive(from sourceDirectory: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default

        // Remove existing zip if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Create the archive using ZIPFoundation
        let archive = try Archive(url: destinationURL, accessMode: .create)

        // Standardize the source directory path to handle /private/var vs /var differences
        let standardizedSourcePath = sourceDirectory.standardizedFileURL.path

        // Get all contents recursively
        guard let enumerator = fileManager.enumerator(
            at: sourceDirectory.standardizedFileURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ExportError.exportFailed("Failed to enumerate directory")
        }

        for case let fileURL as URL in enumerator {
            // Standardize the file URL path
            let standardizedFilePath = fileURL.standardizedFileURL.path

            // Get the relative path from source directory
            let relativePath = standardizedFilePath.replacingOccurrences(
                of: standardizedSourcePath + "/",
                with: ""
            )

            // Check if it's a directory
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Add directory entry
                    try archive.addEntry(
                        with: relativePath + "/",
                        type: .directory,
                        uncompressedSize: Int64(0),
                        provider: { (_: Int64, _: Int) in return Data() }
                    )
                } else {
                    // Add file entry using the standardized source directory
                    try archive.addEntry(
                        with: relativePath,
                        relativeTo: sourceDirectory.standardizedFileURL
                    )
                }
            }
        }
    }

    /// Create an export bundle zip file respecting privacy mode
    /// - Parameters:
    ///   - transcript: The export transcript data
    ///   - metadata: The export metadata
    ///   - audioSourceURL: Optional URL to the source audio file to include
    ///   - outputDirectory: Directory to write the bundle to
    ///   - bundleName: Name for the bundle (without .zip extension)
    ///   - fileClient: File client for I/O operations
    ///   - retentionMode: Privacy mode that controls what artifacts to include
    /// - Returns: URL to the created zip file and list of files included
    public static func writeBundleWithPrivacy(
        transcript: ExportTranscript,
        metadata: ExportMetadata,
        audioSourceURL: URL?,
        outputDirectory: URL,
        bundleName: String,
        fileClient: FileClient,
        retentionMode: AudioRetentionMode
    ) async throws -> BundleResult {
        // Create a staging directory for bundle contents
        let stagingDirectory = outputDirectory.appendingPathComponent(bundleName)
        try await fileClient.createDirectory(stagingDirectory)

        var includedFiles: [String] = []

        // Always include metadata.json
        let metadataData = try JSONEncoder.exportEncoder.encode(metadata)
        let metadataURL = stagingDirectory.appendingPathComponent(BundleFile.metadata)
        try await fileClient.write(metadataData, metadataURL)
        includedFiles.append(BundleFile.metadata)

        // Include transcript artifacts unless audioOnly mode
        if retentionMode != .audioOnly {
            // Write transcript.json
            let transcriptData = try JSONEncoder.exportEncoder.encode(transcript)
            let transcriptURL = stagingDirectory.appendingPathComponent(BundleFile.transcript)
            try await fileClient.write(transcriptData, transcriptURL)
            includedFiles.append(BundleFile.transcript)

            // Write transcript.md
            let markdownContent = MarkdownWriter.write(transcript)
            let markdownURL = stagingDirectory.appendingPathComponent(BundleFile.markdown)
            try await fileClient.write(Data(markdownContent.utf8), markdownURL)
            includedFiles.append(BundleFile.markdown)

            // Write transcript.vtt
            let vttContent = VttWriter.write(transcript)
            let vttURL = stagingDirectory.appendingPathComponent(BundleFile.vtt)
            try await fileClient.write(Data(vttContent.utf8), vttURL)
            includedFiles.append(BundleFile.vtt)
        }

        // Include audio unless transcriptOnly mode
        if retentionMode != .transcriptOnly, let audioSourceURL = audioSourceURL, fileClient.exists(audioSourceURL) {
            let audioData = try await fileClient.read(audioSourceURL)
            let audioDestURL = stagingDirectory.appendingPathComponent(BundleFile.audio)
            try await fileClient.write(audioData, audioDestURL)
            includedFiles.append(BundleFile.audio)
        }

        // Create zip file
        let zipURL = outputDirectory.appendingPathComponent("\(bundleName).zip")
        try createZipArchive(from: stagingDirectory, to: zipURL)

        // Clean up staging directory
        try await fileClient.delete(stagingDirectory)

        return BundleResult(url: zipURL, files: includedFiles)
    }
}
