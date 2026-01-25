import Foundation
import Testing
import ZIPFoundation
@testable import Export
@testable import Persistence
@testable import Models

@Suite("Export Bundle Tests")
struct ExportBundleTests {

    // MARK: - Test Data

    private static let testDate = Date(timeIntervalSince1970: 1706140800) // 2024-01-25 00:00:00 UTC
    private static let testEndDate = Date(timeIntervalSince1970: 1706141400) // 2024-01-25 00:10:00 UTC
    private static let testExportDate = Date(timeIntervalSince1970: 1706142000) // 2024-01-25 00:20:00 UTC

    private static let testSession = ExportSession(
        id: "session-123",
        startedAt: testDate,
        endedAt: testEndDate,
        title: "Test Meeting",
        durationMs: 600000,
        speakerCount: 2,
        audioPath: "audio.caf"
    )

    private static let testSegments: [ExportSegment] = [
        ExportSegment(
            id: "seg-1",
            startMs: 0,
            endMs: 3000,
            speakerId: "spk_0",
            text: "Hello, how are you?",
            confidence: 0.95
        ),
        ExportSegment(
            id: "seg-2",
            startMs: 3000,
            endMs: 6000,
            speakerId: "spk_1",
            text: "I'm doing well, thanks!",
            confidence: 0.92
        ),
    ]

    private static let testSpeakerTracks: [ExportSpeakerTrack] = [
        ExportSpeakerTrack(speakerId: "spk_0", displayOrder: 1, personId: "person-alice"),
        ExportSpeakerTrack(speakerId: "spk_1", displayOrder: 2, personId: nil),
    ]

    private static let testPeople: [ExportPerson] = [
        ExportPerson(id: "person-alice", name: "Alice", colorToken: "sky"),
    ]

    private static let testTranscript = ExportTranscript(
        session: testSession,
        segments: testSegments,
        speakerTracks: testSpeakerTracks,
        people: testPeople
    )

    private static let testMetadata = ExportMetadata(
        appVersion: "1.0.0",
        buildNumber: "100",
        exportedAt: testExportDate,
        traceId: "trace-123",
        stats: ExportStats(
            segmentCount: 2,
            speakerTrackCount: 2,
            durationMs: 600000,
            assignedSpeakerCount: 1
        )
    )

    // MARK: - Bundle Tests

    @Test("Bundle contains all files without audio")
    func testBundleContainsAllFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try await ExportBundleWriter.writeBundle(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: nil,
            outputDirectory: tempDir,
            bundleName: "test-export",
            fileClient: .liveValue
        )

        // Verify zip was created
        #expect(FileManager.default.fileExists(atPath: result.url.path))
        #expect(result.url.pathExtension == "zip")

        // Verify expected files are listed (no audio since source wasn't provided)
        #expect(result.files.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.metadata))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.vtt))
        #expect(!result.files.contains(ExportBundleWriter.BundleFile.audio))
        #expect(result.files.count == 4)

        // Verify zip contents by extracting
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        // Check files exist in extracted archive
        let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.metadata))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.vtt))
    }

    @Test("Bundle includes audio when source exists")
    func testBundleIncludesAudio() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a mock audio file
        let audioSourceURL = tempDir.appendingPathComponent("source-audio.caf")
        let mockAudioData = Data("mock audio content".utf8)
        try mockAudioData.write(to: audioSourceURL)

        let result = try await ExportBundleWriter.writeBundle(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: audioSourceURL,
            outputDirectory: tempDir,
            bundleName: "test-export-with-audio",
            fileClient: .liveValue
        )

        // Verify audio is included
        #expect(result.files.contains(ExportBundleWriter.BundleFile.audio))
        #expect(result.files.count == 5)

        // Verify audio content in zip
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let extractedAudioURL = extractDir.appendingPathComponent(ExportBundleWriter.BundleFile.audio)
        let extractedAudioData = try Data(contentsOf: extractedAudioURL)
        #expect(extractedAudioData == mockAudioData)
    }

    @Test("Bundle transcript.json is valid")
    func testBundleTranscriptJsonValid() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try await ExportBundleWriter.writeBundle(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: nil,
            outputDirectory: tempDir,
            bundleName: "test-json",
            fileClient: .liveValue
        )

        // Extract and parse transcript.json
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let transcriptURL = extractDir.appendingPathComponent(ExportBundleWriter.BundleFile.transcript)
        let transcriptData = try Data(contentsOf: transcriptURL)
        let decodedTranscript = try JSONDecoder.exportDecoder.decode(ExportTranscript.self, from: transcriptData)

        // Verify content
        #expect(decodedTranscript.session.id == "session-123")
        #expect(decodedTranscript.session.title == "Test Meeting")
        #expect(decodedTranscript.segments.count == 2)
        #expect(decodedTranscript.speakerTracks.count == 2)
        #expect(decodedTranscript.people.count == 1)
    }

    @Test("Bundle metadata.json is valid")
    func testBundleMetadataJsonValid() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try await ExportBundleWriter.writeBundle(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: nil,
            outputDirectory: tempDir,
            bundleName: "test-metadata",
            fileClient: .liveValue
        )

        // Extract and parse metadata.json
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let metadataURL = extractDir.appendingPathComponent(ExportBundleWriter.BundleFile.metadata)
        let metadataData = try Data(contentsOf: metadataURL)
        let decodedMetadata = try JSONDecoder.exportDecoder.decode(ExportMetadata.self, from: metadataData)

        // Verify content
        #expect(decodedMetadata.appVersion == "1.0.0")
        #expect(decodedMetadata.buildNumber == "100")
        #expect(decodedMetadata.stats.segmentCount == 2)
        #expect(decodedMetadata.stats.speakerTrackCount == 2)
        #expect(decodedMetadata.stats.assignedSpeakerCount == 1)
    }

    @Test("Bundle transcript.md contains expected content")
    func testBundleMarkdownContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try await ExportBundleWriter.writeBundle(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: nil,
            outputDirectory: tempDir,
            bundleName: "test-markdown",
            fileClient: .liveValue
        )

        // Extract and read markdown
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let markdownURL = extractDir.appendingPathComponent(ExportBundleWriter.BundleFile.markdown)
        let markdownContent = try String(contentsOf: markdownURL, encoding: .utf8)

        // Verify content
        #expect(markdownContent.contains("# Test Meeting"))
        #expect(markdownContent.contains("**Alice**"))
        #expect(markdownContent.contains("**Speaker 2**"))
        #expect(markdownContent.contains("Hello, how are you?"))
        #expect(markdownContent.contains("I'm doing well, thanks!"))
    }

    @Test("Bundle transcript.vtt contains expected content")
    func testBundleVttContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try await ExportBundleWriter.writeBundle(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: nil,
            outputDirectory: tempDir,
            bundleName: "test-vtt",
            fileClient: .liveValue
        )

        // Extract and read VTT
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let vttURL = extractDir.appendingPathComponent(ExportBundleWriter.BundleFile.vtt)
        let vttContent = try String(contentsOf: vttURL, encoding: .utf8)

        // Verify content
        #expect(vttContent.hasPrefix("WEBVTT"))
        #expect(vttContent.contains("<v Alice>Hello, how are you?"))
        #expect(vttContent.contains("<v Speaker 2>I'm doing well, thanks!"))
        #expect(vttContent.contains("00:00:00.000 --> 00:00:03.000"))
        #expect(vttContent.contains("00:00:03.000 --> 00:00:06.000"))
    }

    @Test("Bundle cleans up staging directory")
    func testBundleCleansUpStaging() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try await ExportBundleWriter.writeBundle(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: nil,
            outputDirectory: tempDir,
            bundleName: "test-cleanup",
            fileClient: .liveValue
        )

        // Verify staging directory was cleaned up
        let stagingDir = tempDir.appendingPathComponent("test-cleanup")
        #expect(!FileManager.default.fileExists(atPath: stagingDir.path))
    }
}
