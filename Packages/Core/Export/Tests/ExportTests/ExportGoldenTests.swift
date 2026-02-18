import Foundation
import Testing
@testable import Export
@testable import Persistence
@testable import Models

/// Golden fixture tests that lock export outputs to stored fixtures for regression detection.
/// These tests compare generated output against pre-recorded "golden" files.
@Suite("Export Golden Fixture Tests")
struct ExportGoldenTests {

    // MARK: - Test Data

    private static let testDate = Date(timeIntervalSince1970: 1706140800) // 2024-01-25 00:00:00 UTC
    private static let testEndDate = Date(timeIntervalSince1970: 1706141400) // 2024-01-25 00:10:00 UTC

    private static let testSessionRecord = SessionRecord(
        id: "session-123",
        startedAt: testDate,
        endedAt: testEndDate,
        title: "Test Meeting",
        previewText: "Hello, how are you?",
        durationMs: 600000,
        audioPath: "audio.m4a",
        processingState: .processed,
        speakerCount: 2,
        updatedAt: testDate
    )

    private static let testSegmentRecords: [TranscriptSegmentRecord] = [
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

    private static let testSpeakerTrackRecords: [SpeakerTrackRecord] = [
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

    private static let testPersonRecords: [PersonRecord] = [
        PersonRecord(
            id: "person-alice",
            name: "Alice",
            colorToken: "sky",
            createdAt: testDate,
            updatedAt: testDate
        ),
    ]

    // MARK: - Golden Tests

    @Test("All export formats match golden fixtures")
    func testGoldensMatch() throws {
        // Assemble transcript from test data
        let transcript = ExportAssembler.assembleTranscript(
            session: Self.testSessionRecord,
            segments: Self.testSegmentRecords,
            speakerTracks: Self.testSpeakerTrackRecords,
            people: Self.testPersonRecords,
            audioPath: "audio.m4a"
        )

        // Test JSON golden
        try verifyJsonGolden(transcript)

        // Test VTT golden
        try verifyVttGolden(transcript)

        // Test Markdown golden (with date line normalization)
        try verifyMarkdownGolden(transcript)
    }

    // MARK: - Verification Helpers

    private func verifyJsonGolden(_ transcript: ExportTranscript) throws {
        let goldenURL = try fixtureURL(named: "golden-transcript.json")
        let goldenData = try Data(contentsOf: goldenURL)
        let goldenString = String(data: goldenData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)

        // Generate JSON from transcript
        let generatedData = try JSONEncoder.exportEncoder.encode(transcript)
        let generatedString = String(data: generatedData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(generatedString == goldenString, "JSON output does not match golden fixture")
    }

    private func verifyVttGolden(_ transcript: ExportTranscript) throws {
        let goldenURL = try fixtureURL(named: "golden-transcript.vtt")
        let goldenString = try String(contentsOf: goldenURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

        // Generate VTT from transcript
        let generatedString = VttWriter.write(transcript).trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(generatedString == goldenString, "VTT output does not match golden fixture")
    }

    private func verifyMarkdownGolden(_ transcript: ExportTranscript) throws {
        let goldenURL = try fixtureURL(named: "golden-transcript.md")
        let goldenString = try String(contentsOf: goldenURL, encoding: .utf8)

        // Generate Markdown from transcript
        let generatedString = MarkdownWriter.write(transcript)

        // Normalize both by removing the **Date:** line (locale-dependent) and trimming whitespace
        let normalizedGolden = stripDateLine(goldenString).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGenerated = stripDateLine(generatedString).trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedGenerated == normalizedGolden, "Markdown output does not match golden fixture (ignoring date)")
    }

    // MARK: - Helper Functions

    private func fixtureURL(named filename: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.fixtureNotFound(filename)
        }
        return url
    }

    private func stripDateLine(_ markdown: String) -> String {
        // Remove lines starting with **Date:**
        let lines = markdown.components(separatedBy: "\n")
        let filteredLines = lines.filter { !$0.hasPrefix("**Date:**") }
        return filteredLines.joined(separator: "\n")
    }

    enum FixtureError: Error {
        case fixtureNotFound(String)
    }
}
