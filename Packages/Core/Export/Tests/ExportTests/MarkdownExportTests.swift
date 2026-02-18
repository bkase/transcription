import Foundation
import Testing
@testable import Export
@testable import Persistence
@testable import Models

@Suite("Markdown Export Tests")
struct MarkdownExportTests {

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

    @Test("Markdown output matches golden fixture")
    func testMarkdownOutputGolden() {
        // Assemble transcript from test data
        let transcript = ExportAssembler.assembleTranscript(
            session: Self.testSessionRecord,
            segments: Self.testSegmentRecords,
            speakerTracks: Self.testSpeakerTrackRecords,
            people: Self.testPersonRecords,
            audioPath: "audio.m4a"
        )

        // Generate Markdown
        let markdown = MarkdownWriter.write(transcript)

        // Golden fixture - expected output
        // Note: DateFormatter output depends on locale, so we check key parts
        #expect(markdown.contains("# Test Meeting"))
        #expect(markdown.contains("**Duration:** 10:00"))
        #expect(markdown.contains("**Speakers:** 2"))
        #expect(markdown.contains("---"))
        #expect(markdown.contains("**Alice** (00:00)"))
        #expect(markdown.contains("Hello, how are you?"))
        #expect(markdown.contains("**Speaker 2** (00:03)"))
        #expect(markdown.contains("I'm doing well, thanks!"))
    }

    @Test("Markdown uses session title as heading")
    func testMarkdownTitle() {
        let transcript = ExportTranscript(
            session: ExportSession(
                id: "test",
                startedAt: Self.testDate,
                endedAt: nil,
                title: "My Custom Title",
                durationMs: nil,
                speakerCount: 0,
                audioPath: nil
            ),
            segments: [],
            speakerTracks: [],
            people: []
        )

        let markdown = MarkdownWriter.write(transcript)
        #expect(markdown.hasPrefix("# My Custom Title\n"))
    }

    @Test("Markdown defaults to 'Transcript' when no title")
    func testMarkdownDefaultTitle() {
        let transcript = ExportTranscript(
            session: ExportSession(
                id: "test",
                startedAt: Self.testDate,
                endedAt: nil,
                title: nil,
                durationMs: nil,
                speakerCount: 0,
                audioPath: nil
            ),
            segments: [],
            speakerTracks: [],
            people: []
        )

        let markdown = MarkdownWriter.write(transcript)
        #expect(markdown.hasPrefix("# Transcript\n"))
    }

    @Test("Markdown formats duration correctly for hours")
    func testMarkdownDurationHours() {
        let transcript = ExportTranscript(
            session: ExportSession(
                id: "test",
                startedAt: Self.testDate,
                endedAt: nil,
                title: "Test",
                durationMs: 3661000, // 1:01:01
                speakerCount: 0,
                audioPath: nil
            ),
            segments: [],
            speakerTracks: [],
            people: []
        )

        let markdown = MarkdownWriter.write(transcript)
        #expect(markdown.contains("**Duration:** 1:01:01"))
    }

    @Test("Markdown handles unassigned speaker with display order")
    func testMarkdownUnassignedSpeaker() {
        let transcript = ExportTranscript(
            session: ExportSession(
                id: "test",
                startedAt: Self.testDate,
                endedAt: nil,
                title: "Test",
                durationMs: nil,
                speakerCount: 1,
                audioPath: nil
            ),
            segments: [
                ExportSegment(
                    id: "seg-1",
                    startMs: 5000,
                    endMs: 8000,
                    speakerId: "spk_0",
                    text: "Hello",
                    confidence: nil
                )
            ],
            speakerTracks: [
                ExportSpeakerTrack(speakerId: "spk_0", displayOrder: 3, personId: nil)
            ],
            people: []
        )

        let markdown = MarkdownWriter.write(transcript)
        #expect(markdown.contains("**Speaker 3** (00:05)"))
    }

    @Test("Markdown handles nil speakerId as Unknown")
    func testMarkdownNilSpeaker() {
        let transcript = ExportTranscript(
            session: ExportSession(
                id: "test",
                startedAt: Self.testDate,
                endedAt: nil,
                title: "Test",
                durationMs: nil,
                speakerCount: 0,
                audioPath: nil
            ),
            segments: [
                ExportSegment(
                    id: "seg-1",
                    startMs: 0,
                    endMs: 1000,
                    speakerId: nil,
                    text: "Mystery voice",
                    confidence: nil
                )
            ],
            speakerTracks: [],
            people: []
        )

        let markdown = MarkdownWriter.write(transcript)
        #expect(markdown.contains("**Unknown** (00:00)"))
    }

    @Test("Markdown handles empty segments")
    func testMarkdownEmptySegments() {
        let transcript = ExportTranscript(
            session: ExportSession(
                id: "test",
                startedAt: Self.testDate,
                endedAt: nil,
                title: "Empty Session",
                durationMs: 0,
                speakerCount: 0,
                audioPath: nil
            ),
            segments: [],
            speakerTracks: [],
            people: []
        )

        let markdown = MarkdownWriter.write(transcript)
        #expect(markdown.contains("# Empty Session"))
        #expect(markdown.contains("---"))
        // After the separator, there should be no segment content
        let parts = markdown.components(separatedBy: "---")
        #expect(parts.count == 2)
        #expect(parts[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
