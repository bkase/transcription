import Foundation
import Testing
import ZIPFoundation
@testable import Export
@testable import Persistence
@testable import Models

@Suite("Privacy Mode Export Tests")
struct PrivacyModeExportTests {

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

    // MARK: - Privacy Mode Tests

    @Test("Transcript-only mode excludes audio from bundle")
    func testTranscriptOnlyExcludesAudio() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a mock audio file
        let audioSourceURL = tempDir.appendingPathComponent("source-audio.caf")
        let mockAudioData = Data("mock audio content".utf8)
        try mockAudioData.write(to: audioSourceURL)

        let result = try await ExportBundleWriter.writeBundleWithPrivacy(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: audioSourceURL,
            outputDirectory: tempDir,
            bundleName: "transcript-only-export",
            fileClient: .liveValue,
            retentionMode: .transcriptOnly
        )

        // Verify audio is NOT included
        #expect(!result.files.contains(ExportBundleWriter.BundleFile.audio))

        // Verify transcript artifacts ARE included
        #expect(result.files.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.metadata))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.vtt))
        #expect(result.files.count == 4)

        // Verify by extracting the zip
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
        #expect(!extractedFiles.contains(ExportBundleWriter.BundleFile.audio))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.vtt))
    }

    @Test("Audio-only mode excludes transcript artifacts from bundle")
    func testAudioOnlyExcludesTranscriptArtifacts() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a mock audio file
        let audioSourceURL = tempDir.appendingPathComponent("source-audio.caf")
        let mockAudioData = Data("mock audio content".utf8)
        try mockAudioData.write(to: audioSourceURL)

        let result = try await ExportBundleWriter.writeBundleWithPrivacy(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: audioSourceURL,
            outputDirectory: tempDir,
            bundleName: "audio-only-export",
            fileClient: .liveValue,
            retentionMode: .audioOnly
        )

        // Verify transcript artifacts are NOT included
        #expect(!result.files.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(!result.files.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(!result.files.contains(ExportBundleWriter.BundleFile.vtt))

        // Verify audio IS included
        #expect(result.files.contains(ExportBundleWriter.BundleFile.audio))

        // Metadata is always included
        #expect(result.files.contains(ExportBundleWriter.BundleFile.metadata))
        #expect(result.files.count == 2)

        // Verify by extracting the zip
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.audio))
        #expect(extractedFiles.contains(ExportBundleWriter.BundleFile.metadata))
        #expect(!extractedFiles.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(!extractedFiles.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(!extractedFiles.contains(ExportBundleWriter.BundleFile.vtt))
    }

    @Test("Both mode includes all artifacts in bundle")
    func testBothModeIncludesAllArtifacts() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a mock audio file
        let audioSourceURL = tempDir.appendingPathComponent("source-audio.caf")
        let mockAudioData = Data("mock audio content".utf8)
        try mockAudioData.write(to: audioSourceURL)

        let result = try await ExportBundleWriter.writeBundleWithPrivacy(
            transcript: Self.testTranscript,
            metadata: Self.testMetadata,
            audioSourceURL: audioSourceURL,
            outputDirectory: tempDir,
            bundleName: "both-mode-export",
            fileClient: .liveValue,
            retentionMode: .both
        )

        // Verify all artifacts are included
        #expect(result.files.contains(ExportBundleWriter.BundleFile.transcript))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.metadata))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.markdown))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.vtt))
        #expect(result.files.contains(ExportBundleWriter.BundleFile.audio))
        #expect(result.files.count == 5)

        // Verify by extracting the zip
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: result.url, to: extractDir)

        let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
        #expect(extractedFiles.count == 5)
    }
}
