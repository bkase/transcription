import Foundation
import Testing
import Dependencies
import ZIPFoundation
@testable import Export
@testable import Persistence
@testable import Models

@Suite("Export Client Tests")
struct ExportClientTests {

    // MARK: - Test Data

    private static let testDate = Date(timeIntervalSince1970: 1706140800) // 2024-01-25 00:00:00 UTC
    private static let testEndDate = Date(timeIntervalSince1970: 1706141400) // 2024-01-25 00:10:00 UTC
    private static let testExportDate = Date(timeIntervalSince1970: 1706142000) // 2024-01-25 00:20:00 UTC
    private static let testUUID = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000001")!

    private static let testSessionId = SessionID("session-123")

    private static let testSessionRecord = SessionRecord(
        id: "session-123",
        startedAt: testDate,
        endedAt: testEndDate,
        title: "Test Meeting",
        previewText: "Hello, how are you?",
        durationMs: 600000,
        audioPath: nil,
        processingState: .processed,
        speakerCount: 2,
        updatedAt: testDate
    )

    private static let testSegments: [TranscriptSegmentRecord] = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-123",
            startMs: 0,
            endMs: 3000,
            machineSpeakerId: "spk_0",
            text: "Hello, how are you?",
            confidence: 0.95,
            isFinal: true,
            createdAt: testDate,
            updatedAt: testDate
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-123",
            startMs: 3000,
            endMs: 6000,
            machineSpeakerId: "spk_1",
            text: "I'm doing well, thanks!",
            confidence: 0.92,
            isFinal: true,
            createdAt: testDate,
            updatedAt: testDate
        ),
    ]

    private static let testSpeakerTracks: [SpeakerTrackRecord] = [
        SpeakerTrackRecord(
            id: "track-1",
            sessionId: "session-123",
            machineSpeakerId: "spk_0",
            displayOrder: 1,
            personId: "person-alice"
        ),
        SpeakerTrackRecord(
            id: "track-2",
            sessionId: "session-123",
            machineSpeakerId: "spk_1",
            displayOrder: 2,
            personId: nil
        ),
    ]

    private static let testPeople: [PersonRecord] = [
        PersonRecord(
            id: "person-alice",
            name: "Alice",
            colorToken: "sky",
            createdAt: testDate,
            updatedAt: testDate
        ),
    ]

    // MARK: - Tests

    @Test("ExportClient exportBundle invokes bundle writer")
    func testExportClientInvokesBundleWriter() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create client with mocked dependencies
        let client = withDependencies {
            $0.databaseClient.fetchSession = { id in
                #expect(id == Self.testSessionId)
                return Self.testSessionRecord
            }
            $0.databaseClient.fetchTranscriptSegments = { id in
                #expect(id == Self.testSessionId)
                return Self.testSegments
            }
            $0.databaseClient.fetchSpeakerTracks = { id in
                #expect(id == Self.testSessionId)
                return Self.testSpeakerTracks
            }
            $0.databaseClient.fetchPeople = {
                return Self.testPeople
            }
            $0.fileClient = .liveValue
            $0.preferencesClient.getAudioRetentionMode = { .both }
            $0.date = .constant(Self.testExportDate)
            $0.uuid = .constant(Self.testUUID)
        } operation: {
            ExportClient.live(appVersion: "1.0.0", buildNumber: "100")
        }

        // Call exportBundle
        let bundleURL = try await client.exportBundle(Self.testSessionId)

        // Verify zip was created
        #expect(FileManager.default.fileExists(atPath: bundleURL.path))
        #expect(bundleURL.pathExtension == "zip")

        // Extract and verify contents
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: bundleURL, to: extractDir)

        // Check files exist
        let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.metadata))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.vtt))

        // Verify transcript.json content
        let transcriptURL = extractDir.appendingPathComponent(ExportBundleWriter.BundleFile.transcript)
        let transcriptData = try Data(contentsOf: transcriptURL)
        let transcript = try JSONDecoder.exportDecoder.decode(ExportTranscript.self, from: transcriptData)

        #expect(transcript.session.id == "session-123")
        #expect(transcript.session.title == "Test Meeting")
        #expect(transcript.segments.count == 2)
        #expect(transcript.speakerTracks.count == 2)
        #expect(transcript.people.count == 1)
        #expect(transcript.people.first?.name == "Alice")

        // Verify metadata.json content
        let metadataURL = extractDir.appendingPathComponent(ExportBundleWriter.BundleFile.metadata)
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder.exportDecoder.decode(ExportMetadata.self, from: metadataData)

        #expect(metadata.appVersion == "1.0.0")
        #expect(metadata.buildNumber == "100")
        #expect(metadata.stats.segmentCount == 2)

        // Clean up generated bundle
        try? FileManager.default.removeItem(at: bundleURL)
    }

    @Test("ExportClient exportSession returns correct format")
    func testExportClientExportSession() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create client with mocked dependencies
        let client = withDependencies {
            $0.databaseClient.fetchSession = { _ in Self.testSessionRecord }
            $0.databaseClient.fetchTranscriptSegments = { _ in Self.testSegments }
            $0.databaseClient.fetchSpeakerTracks = { _ in Self.testSpeakerTracks }
            $0.databaseClient.fetchPeople = { Self.testPeople }
            $0.fileClient = .liveValue
            $0.date = .constant(Self.testExportDate)
            $0.uuid = .constant(Self.testUUID)
        } operation: {
            ExportClient.live()
        }

        // Test JSON export
        let jsonResult = try await client.exportSession(Self.testSessionId, .json)
        #expect(jsonResult.format == .json)
        #expect(FileManager.default.fileExists(atPath: jsonResult.url.path))

        let jsonData = try Data(contentsOf: jsonResult.url)
        let transcript = try JSONDecoder.exportDecoder.decode(ExportTranscript.self, from: jsonData)
        #expect(transcript.session.id == "session-123")

        // Test Markdown export
        let mdResult = try await client.exportSession(Self.testSessionId, .markdown)
        #expect(mdResult.format == .markdown)
        #expect(FileManager.default.fileExists(atPath: mdResult.url.path))

        let mdContent = try String(contentsOf: mdResult.url, encoding: .utf8)
        #expect(mdContent.contains("# Test Meeting"))
        #expect(mdContent.contains("**Alice**"))

        // Test VTT export
        let vttResult = try await client.exportSession(Self.testSessionId, .vtt)
        #expect(vttResult.format == .vtt)
        #expect(FileManager.default.fileExists(atPath: vttResult.url.path))

        let vttContent = try String(contentsOf: vttResult.url, encoding: .utf8)
        #expect(vttContent.hasPrefix("WEBVTT"))
        #expect(vttContent.contains("<v Alice>"))

        // Clean up
        try? FileManager.default.removeItem(at: jsonResult.url)
        try? FileManager.default.removeItem(at: mdResult.url)
        try? FileManager.default.removeItem(at: vttResult.url)
    }

    @Test("ExportClient throws error for non-existent session")
    func testExportClientThrowsForMissingSession() async throws {
        let client = withDependencies {
            $0.databaseClient.fetchSession = { _ in nil }
            $0.fileClient = .liveValue
        } operation: {
            ExportClient.live()
        }

        let missingId = SessionID("nonexistent")

        // Test exportBundle throws
        await #expect(throws: ExportError.sessionNotFound(missingId)) {
            _ = try await client.exportBundle(missingId)
        }

        // Test exportSession throws
        await #expect(throws: ExportError.sessionNotFound(missingId)) {
            _ = try await client.exportSession(missingId, .json)
        }
    }

    @Test("ExportClient availableFormats returns all formats")
    func testExportClientAvailableFormats() {
        let client = ExportClient.live()

        let formats = client.availableFormats()

        #expect(formats.count == 3)
        #expect(formats.contains(.json))
        #expect(formats.contains(.markdown))
        #expect(formats.contains(.vtt))
    }

    // MARK: - Export All Sessions Tests

    private static let testSessionRecord2 = SessionRecord(
        id: "session-456",
        startedAt: testDate,
        endedAt: testEndDate,
        title: "Second Meeting",
        previewText: "Good morning!",
        durationMs: 300000,
        audioPath: nil,
        processingState: .processed,
        speakerCount: 1,
        updatedAt: testDate
    )

    private static let testSegments2: [TranscriptSegmentRecord] = [
        TranscriptSegmentRecord(
            id: "seg-3",
            sessionId: "session-456",
            startMs: 0,
            endMs: 2000,
            machineSpeakerId: "spk_0",
            text: "Good morning!",
            confidence: 0.98,
            isFinal: true,
            createdAt: testDate,
            updatedAt: testDate
        ),
    ]

    private static let testSpeakerTracks2: [SpeakerTrackRecord] = [
        SpeakerTrackRecord(
            id: "track-3",
            sessionId: "session-456",
            machineSpeakerId: "spk_0",
            displayOrder: 1,
            personId: nil
        ),
    ]

    @Test("ExportClient exportAllSessions creates combined bundle")
    func testExportAllSessionsCreatesCombinedBundle() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Use a unique timestamp for this test to avoid conflicts
        let uniqueDate = Date(timeIntervalSince1970: 1706143000) // Different from testExportDate

        // Create client with mocked dependencies for multiple sessions
        let client = withDependencies {
            $0.databaseClient.fetchSessions = {
                [Self.testSessionRecord, Self.testSessionRecord2]
            }
            $0.databaseClient.fetchTranscriptSegments = { id in
                if id.rawValue == "session-123" {
                    return Self.testSegments
                } else {
                    return Self.testSegments2
                }
            }
            $0.databaseClient.fetchSpeakerTracks = { id in
                if id.rawValue == "session-123" {
                    return Self.testSpeakerTracks
                } else {
                    return Self.testSpeakerTracks2
                }
            }
            $0.databaseClient.fetchPeople = {
                return Self.testPeople
            }
            $0.fileClient = .liveValue
            $0.preferencesClient.getAudioRetentionMode = { .both }
            $0.date = .constant(uniqueDate)
            $0.uuid = .constant(Self.testUUID)
        } operation: {
            ExportClient.live(appVersion: "1.0.0", buildNumber: "100")
        }

        // Call exportAllSessions
        let bundleURL = try await client.exportAllSessions()

        // Verify zip was created
        #expect(FileManager.default.fileExists(atPath: bundleURL.path))
        #expect(bundleURL.pathExtension == "zip")

        // Open archive and verify contents without extracting
        let archive = try Archive(url: bundleURL, accessMode: .read)
        var entryPaths: [String] = []
        for entry in archive {
            entryPaths.append(entry.path)
        }

        // Verify session directories and files exist in archive
        #expect(entryPaths.contains(where: { $0.hasPrefix("Test Meeting/") }))
        #expect(entryPaths.contains(where: { $0.hasPrefix("Second Meeting/") }))
        #expect(entryPaths.contains("Test Meeting/transcript.json"))
        #expect(entryPaths.contains("Test Meeting/metadata.json"))
        #expect(entryPaths.contains("Test Meeting/transcript.md"))
        #expect(entryPaths.contains("Test Meeting/transcript.vtt"))
        #expect(entryPaths.contains("Second Meeting/transcript.json"))
        #expect(entryPaths.contains("Second Meeting/metadata.json"))

        // Clean up generated bundle
        try? FileManager.default.removeItem(at: bundleURL)
    }

    @Test("ExportClient exportAllSessions works with empty sessions list")
    func testExportAllSessionsWithEmptySessions() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Use a unique timestamp for this test to avoid conflicts
        let uniqueDate = Date(timeIntervalSince1970: 1706144000) // Different from other tests

        // Create client with no sessions
        let client = withDependencies {
            $0.databaseClient.fetchSessions = { [] }
            $0.databaseClient.fetchPeople = { [] }
            $0.fileClient = .liveValue
            $0.preferencesClient.getAudioRetentionMode = { .both }
            $0.date = .constant(uniqueDate)
            $0.uuid = .constant(Self.testUUID)
        } operation: {
            ExportClient.live(appVersion: "1.0.0", buildNumber: "100")
        }

        // Call exportAllSessions - should succeed with empty bundle
        let bundleURL = try await client.exportAllSessions()

        // Verify zip was created
        #expect(FileManager.default.fileExists(atPath: bundleURL.path))
        #expect(bundleURL.pathExtension == "zip")

        // Clean up
        try? FileManager.default.removeItem(at: bundleURL)
    }
}
