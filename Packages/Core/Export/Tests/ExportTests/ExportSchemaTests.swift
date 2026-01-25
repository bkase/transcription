import Foundation
import Testing
@testable import Export
@testable import Persistence
@testable import Models

@Suite("Export Schema Tests")
struct ExportSchemaTests {

    // MARK: - Test Data

    private static let testDate = Date(timeIntervalSince1970: 1706140800) // 2024-01-25 00:00:00 UTC
    private static let testEndDate = Date(timeIntervalSince1970: 1706141400) // 2024-01-25 00:10:00 UTC
    private static let testExportDate = Date(timeIntervalSince1970: 1706142000) // 2024-01-25 00:20:00 UTC

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
        PersonRecord(
            id: "person-bob",
            name: "Bob",
            colorToken: "lavender",
            createdAt: testDate,
            updatedAt: testDate
        ),
    ]

    // MARK: - Encode/Decode Tests

    @Test("ExportTranscript encodes and decodes correctly")
    func testEncodeDecodeSchema() throws {
        // Assemble transcript from test data
        let transcript = ExportAssembler.assembleTranscript(
            session: Self.testSessionRecord,
            segments: Self.testSegmentRecords,
            speakerTracks: Self.testSpeakerTrackRecords,
            people: Self.testPersonRecords,
            audioPath: "audio.caf"
        )

        // Encode to JSON
        let encoder = JSONEncoder.exportEncoder
        let jsonData = try encoder.encode(transcript)

        // Decode back from JSON
        let decoder = JSONDecoder.exportDecoder
        let decoded = try decoder.decode(ExportTranscript.self, from: jsonData)

        // Verify roundtrip
        #expect(decoded == transcript)
        #expect(decoded.schemaVersion == "1.0")
        #expect(decoded.session.id == "session-123")
        #expect(decoded.session.title == "Test Meeting")
        #expect(decoded.segments.count == 2)
        #expect(decoded.speakerTracks.count == 2)
        // Only Alice should be included (Bob is not referenced by any speaker track)
        #expect(decoded.people.count == 1)
        #expect(decoded.people.first?.name == "Alice")
    }

    @Test("ExportMetadata encodes and decodes correctly")
    func testEncodeDecodeMetadata() throws {
        let metadata = ExportAssembler.assembleMetadata(
            appVersion: "1.0.0",
            buildNumber: "42",
            exportedAt: Self.testExportDate,
            traceId: "trace-abc123",
            segmentCount: 2,
            speakerTracks: Self.testSpeakerTrackRecords,
            durationMs: 600000
        )

        // Encode to JSON
        let encoder = JSONEncoder.exportEncoder
        let jsonData = try encoder.encode(metadata)

        // Decode back from JSON
        let decoder = JSONDecoder.exportDecoder
        let decoded = try decoder.decode(ExportMetadata.self, from: jsonData)

        // Verify roundtrip
        #expect(decoded == metadata)
        #expect(decoded.schemaVersion == "1.0")
        #expect(decoded.appVersion == "1.0.0")
        #expect(decoded.buildNumber == "42")
        #expect(decoded.traceId == "trace-abc123")
        #expect(decoded.stats.segmentCount == 2)
        #expect(decoded.stats.speakerTrackCount == 2)
        #expect(decoded.stats.durationMs == 600000)
        #expect(decoded.stats.assignedSpeakerCount == 1)
    }

    @Test("ExportSession initializes from SessionRecord correctly")
    func testExportSessionFromRecord() {
        let exportSession = ExportSession(from: Self.testSessionRecord, audioPath: "custom/audio.caf")

        #expect(exportSession.id == "session-123")
        #expect(exportSession.startedAt == Self.testDate)
        #expect(exportSession.endedAt == Self.testEndDate)
        #expect(exportSession.title == "Test Meeting")
        #expect(exportSession.durationMs == 600000)
        #expect(exportSession.speakerCount == 2)
        #expect(exportSession.audioPath == "custom/audio.caf")
    }

    @Test("ExportSegment initializes from TranscriptSegmentRecord correctly")
    func testExportSegmentFromRecord() {
        let record = Self.testSegmentRecords[0]
        let exportSegment = ExportSegment(from: record)

        #expect(exportSegment.id == "seg-1")
        #expect(exportSegment.startMs == 0)
        #expect(exportSegment.endMs == 3000)
        #expect(exportSegment.speakerId == "spk_0")
        #expect(exportSegment.text == "Hello, how are you?")
        #expect(exportSegment.confidence == 0.95)
    }

    @Test("ExportSpeakerTrack initializes from SpeakerTrackRecord correctly")
    func testExportSpeakerTrackFromRecord() {
        let assignedTrack = Self.testSpeakerTrackRecords[0]
        let exportTrack = ExportSpeakerTrack(from: assignedTrack)

        #expect(exportTrack.speakerId == "spk_0")
        #expect(exportTrack.displayOrder == 1)
        #expect(exportTrack.personId == "person-alice")

        let unassignedTrack = Self.testSpeakerTrackRecords[1]
        let exportUnassigned = ExportSpeakerTrack(from: unassignedTrack)

        #expect(exportUnassigned.speakerId == "spk_1")
        #expect(exportUnassigned.displayOrder == 2)
        #expect(exportUnassigned.personId == nil)
    }

    @Test("ExportPerson initializes from PersonRecord correctly")
    func testExportPersonFromRecord() {
        let record = Self.testPersonRecords[0]
        let exportPerson = ExportPerson(from: record)

        #expect(exportPerson.id == "person-alice")
        #expect(exportPerson.name == "Alice")
        #expect(exportPerson.colorToken == "sky")
    }

    @Test("ExportAssembler filters people to only those referenced by speaker tracks")
    func testAssemblerFiltersUnreferencedPeople() {
        let transcript = ExportAssembler.assembleTranscript(
            session: Self.testSessionRecord,
            segments: Self.testSegmentRecords,
            speakerTracks: Self.testSpeakerTrackRecords,
            people: Self.testPersonRecords,
            audioPath: nil
        )

        // Only Alice is referenced by speaker track 1, Bob is not referenced
        #expect(transcript.people.count == 1)
        #expect(transcript.people.first?.id == "person-alice")
        #expect(transcript.people.first?.name == "Alice")
    }

    @Test("ExportStats calculates assigned speaker count correctly")
    func testExportStatsAssignedCount() {
        let metadata = ExportAssembler.assembleMetadata(
            appVersion: "1.0.0",
            buildNumber: "1",
            exportedAt: Self.testExportDate,
            traceId: nil,
            segmentCount: 10,
            speakerTracks: Self.testSpeakerTrackRecords,
            durationMs: 120000
        )

        // Only track-1 has a personId assigned
        #expect(metadata.stats.assignedSpeakerCount == 1)
        #expect(metadata.stats.speakerTrackCount == 2)
    }

    @Test("JSON output uses ISO 8601 dates")
    func testJsonUsesIso8601Dates() throws {
        let session = ExportSession(
            id: "test",
            startedAt: Self.testDate,
            endedAt: nil,
            title: nil,
            durationMs: nil,
            speakerCount: 0,
            audioPath: nil
        )

        let encoder = JSONEncoder.exportEncoder
        let jsonData = try encoder.encode(session)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // ISO 8601 format check
        #expect(jsonString.contains("2024-01-25T00:00:00Z"))
    }

    @Test("JSON output is pretty printed and sorted")
    func testJsonFormatting() throws {
        let metadata = ExportMetadata(
            appVersion: "1.0.0",
            buildNumber: "1",
            exportedAt: Self.testExportDate,
            traceId: nil,
            stats: ExportStats(segmentCount: 0, speakerTrackCount: 0, durationMs: nil, assignedSpeakerCount: 0)
        )

        let encoder = JSONEncoder.exportEncoder
        let jsonData = try encoder.encode(metadata)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Pretty printed means newlines
        #expect(jsonString.contains("\n"))
        // Sorted keys means appVersion comes before buildNumber
        let appVersionIndex = jsonString.range(of: "appVersion")!.lowerBound
        let buildNumberIndex = jsonString.range(of: "buildNumber")!.lowerBound
        #expect(appVersionIndex < buildNumberIndex)
    }

    @Test("Empty segments and speaker tracks produce valid export")
    func testEmptyTranscript() throws {
        let emptyTranscript = ExportAssembler.assembleTranscript(
            session: Self.testSessionRecord,
            segments: [],
            speakerTracks: [],
            people: []
        )

        let encoder = JSONEncoder.exportEncoder
        let jsonData = try encoder.encode(emptyTranscript)
        let decoded = try JSONDecoder.exportDecoder.decode(ExportTranscript.self, from: jsonData)

        #expect(decoded.segments.isEmpty)
        #expect(decoded.speakerTracks.isEmpty)
        #expect(decoded.people.isEmpty)
        #expect(decoded.session.id == "session-123")
    }
}
