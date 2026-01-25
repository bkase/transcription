import Foundation
import Testing
@testable import Export
@testable import Persistence
@testable import Models

@Suite("VTT Export Tests")
struct VttExportTests {

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
        audioPath: "audio.caf",
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

    @Test("VTT output matches golden fixture")
    func testVttOutputGolden() {
        // Assemble transcript from test data
        let transcript = ExportAssembler.assembleTranscript(
            session: Self.testSessionRecord,
            segments: Self.testSegmentRecords,
            speakerTracks: Self.testSpeakerTrackRecords,
            people: Self.testPersonRecords,
            audioPath: "audio.caf"
        )

        // Generate VTT
        let vtt = VttWriter.write(transcript)

        // Golden fixture - expected output (note: each cue ends with blank line)
        let expected = "WEBVTT\n\n1\n00:00:00.000 --> 00:00:03.000\n<v Alice>Hello, how are you?\n\n2\n00:00:03.000 --> 00:00:06.000\n<v Speaker 2>I'm doing well, thanks!\n\n"

        #expect(vtt == expected)
    }

    @Test("VTT starts with WEBVTT header")
    func testVttHeader() {
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
            segments: [],
            speakerTracks: [],
            people: []
        )

        let vtt = VttWriter.write(transcript)
        #expect(vtt.hasPrefix("WEBVTT\n"))
    }

    @Test("VTT formats timestamps with milliseconds")
    func testVttTimestampFormat() {
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
                    startMs: 65123, // 1:05.123
                    endMs: 125456,  // 2:05.456
                    speakerId: "spk_0",
                    text: "Test",
                    confidence: nil
                )
            ],
            speakerTracks: [
                ExportSpeakerTrack(speakerId: "spk_0", displayOrder: 1, personId: nil)
            ],
            people: []
        )

        let vtt = VttWriter.write(transcript)
        #expect(vtt.contains("00:01:05.123 --> 00:02:05.456"))
    }

    @Test("VTT handles hour-long timestamps")
    func testVttHourTimestamp() {
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
                    startMs: 3661000, // 1:01:01.000
                    endMs: 7322500,   // 2:02:02.500
                    speakerId: "spk_0",
                    text: "Long recording",
                    confidence: nil
                )
            ],
            speakerTracks: [
                ExportSpeakerTrack(speakerId: "spk_0", displayOrder: 1, personId: nil)
            ],
            people: []
        )

        let vtt = VttWriter.write(transcript)
        #expect(vtt.contains("01:01:01.000 --> 02:02:02.500"))
    }

    @Test("VTT uses voice tag with speaker name")
    func testVttVoiceTag() {
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
                    startMs: 0,
                    endMs: 1000,
                    speakerId: "spk_0",
                    text: "Hello",
                    confidence: nil
                )
            ],
            speakerTracks: [
                ExportSpeakerTrack(speakerId: "spk_0", displayOrder: 1, personId: "person-bob")
            ],
            people: [
                ExportPerson(id: "person-bob", name: "Bob", colorToken: "lavender")
            ]
        )

        let vtt = VttWriter.write(transcript)
        #expect(vtt.contains("<v Bob>Hello"))
    }

    @Test("VTT handles unknown speaker")
    func testVttUnknownSpeaker() {
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
                    text: "Mystery",
                    confidence: nil
                )
            ],
            speakerTracks: [],
            people: []
        )

        let vtt = VttWriter.write(transcript)
        #expect(vtt.contains("<v Unknown>Mystery"))
    }

    @Test("VTT numbers cues sequentially")
    func testVttCueNumbers() {
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
                ExportSegment(id: "a", startMs: 0, endMs: 1000, speakerId: "spk_0", text: "First", confidence: nil),
                ExportSegment(id: "b", startMs: 1000, endMs: 2000, speakerId: "spk_0", text: "Second", confidence: nil),
                ExportSegment(id: "c", startMs: 2000, endMs: 3000, speakerId: "spk_0", text: "Third", confidence: nil),
            ],
            speakerTracks: [
                ExportSpeakerTrack(speakerId: "spk_0", displayOrder: 1, personId: nil)
            ],
            people: []
        )

        let vtt = VttWriter.write(transcript)
        #expect(vtt.contains("\n1\n"))
        #expect(vtt.contains("\n2\n"))
        #expect(vtt.contains("\n3\n"))
    }

    @Test("VTT handles empty segments")
    func testVttEmptySegments() {
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
            segments: [],
            speakerTracks: [],
            people: []
        )

        let vtt = VttWriter.write(transcript)
        #expect(vtt == "WEBVTT\n\n")
    }
}
