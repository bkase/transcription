import Foundation
import Testing
import Gen
@testable import TestsSupport
@testable import Models
@testable import Persistence
@testable import Audio
@testable import Processing

/// Tests that verify generators produce deterministic results with seeded randomness.
///
/// Property testing generators must be deterministic given the same seed,
/// which enables reproducible test failures.
@Suite
struct GeneratorsTests {

    // MARK: - ID Generator Tests

    @Test func testSessionIDGeneratorDeterministic() {
        // Given the same seed, generators should produce identical results
        var rng1 = Xoshiro(seed: 12345)
        var rng2 = Xoshiro(seed: 12345)

        let id1 = sessionIDGen.run(using: &rng1)
        let id2 = sessionIDGen.run(using: &rng2)

        #expect(id1 == id2, "Same seed should produce identical SessionIDs")
        #expect(id1.rawValue.hasPrefix("session-"), "SessionID should have 'session-' prefix")
    }

    @Test func testPersonIDGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 42)
        var rng2 = Xoshiro(seed: 42)

        let id1 = personIDGen.run(using: &rng1)
        let id2 = personIDGen.run(using: &rng2)

        #expect(id1 == id2, "Same seed should produce identical PersonIDs")
        #expect(id1.rawValue.hasPrefix("person-"), "PersonID should have 'person-' prefix")
    }

    @Test func testTranscriptSegmentIDGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 99)
        var rng2 = Xoshiro(seed: 99)

        let id1 = transcriptSegmentIDGen.run(using: &rng1)
        let id2 = transcriptSegmentIDGen.run(using: &rng2)

        #expect(id1 == id2, "Same seed should produce identical TranscriptSegmentIDs")
        #expect(id1.rawValue.hasPrefix("segment-"), "TranscriptSegmentID should have 'segment-' prefix")
    }

    @Test func testSpeakerTrackIDGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 777)
        var rng2 = Xoshiro(seed: 777)

        let id1 = speakerTrackIDGen.run(using: &rng1)
        let id2 = speakerTrackIDGen.run(using: &rng2)

        #expect(id1 == id2, "Same seed should produce identical SpeakerTrackIDs")
        #expect(id1.rawValue.hasPrefix("track-"), "SpeakerTrackID should have 'track-' prefix")
    }

    // MARK: - TranscriptSegment Generator Tests

    @Test func testTranscriptSegmentGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 12345)
        var rng2 = Xoshiro(seed: 12345)

        let segment1 = transcriptSegmentGen.run(using: &rng1)
        let segment2 = transcriptSegmentGen.run(using: &rng2)

        #expect(segment1 == segment2, "Same seed should produce identical TranscriptSegments")
        #expect(segment1.endMs > segment1.startMs, "End time should be after start time")
    }

    @Test func testFinalTranscriptSegmentGeneratorAlwaysFinal() {
        var rng = Xoshiro(seed: 54321)

        // Generate multiple segments and verify they're all final
        for _ in 0..<10 {
            let segment = finalTranscriptSegmentGen.run(using: &rng)
            #expect(segment.isFinal, "finalTranscriptSegmentGen should always produce final segments")
        }
    }

    // MARK: - SessionRecord Generator Tests

    @Test func testSessionRecordGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 555)
        var rng2 = Xoshiro(seed: 555)

        let session1 = sessionRecordGen.run(using: &rng1)
        let session2 = sessionRecordGen.run(using: &rng2)

        #expect(session1 == session2, "Same seed should produce identical SessionRecords")
    }

    @Test func testCompletedSessionRecordGeneratorProperties() {
        var rng = Xoshiro(seed: 888)

        let session = completedSessionRecordGen.run(using: &rng)

        #expect(session.endedAt != nil, "Completed session should have endedAt")
        #expect(session.processingState == .processed, "Completed session should be in processed state")
        #expect(session.speakerCount >= 1, "Completed session should have at least 1 speaker")
        #expect(session.audioPath != nil, "Completed session should have audio path")
    }

    // MARK: - PersonRecord Generator Tests

    @Test func testPersonRecordGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 111)
        var rng2 = Xoshiro(seed: 111)

        let person1 = personRecordGen.run(using: &rng1)
        let person2 = personRecordGen.run(using: &rng2)

        #expect(person1 == person2, "Same seed should produce identical PersonRecords")
        #expect(!person1.name.isEmpty, "Person name should not be empty")
        #expect(!person1.colorToken.isEmpty, "Color token should not be empty")
    }

    // MARK: - TranscriptSegmentRecord Generator Tests

    @Test func testTranscriptSegmentRecordGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 222)
        var rng2 = Xoshiro(seed: 222)

        let record1 = transcriptSegmentRecordGen.run(using: &rng1)
        let record2 = transcriptSegmentRecordGen.run(using: &rng2)

        #expect(record1.id == record2.id, "Same seed should produce identical segment IDs")
        #expect(record1.sessionId == record2.sessionId, "Same seed should produce identical session IDs")
        #expect(record1.text == record2.text, "Same seed should produce identical text")
        #expect(record1.endMs > record1.startMs, "End time should be after start time")
    }

    // MARK: - SpeakerTrackRecord Generator Tests

    @Test func testSpeakerTrackRecordGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 333)
        var rng2 = Xoshiro(seed: 333)

        let track1 = speakerTrackRecordGen.run(using: &rng1)
        let track2 = speakerTrackRecordGen.run(using: &rng2)

        #expect(track1.id == track2.id, "Same seed should produce identical track IDs")
        #expect(track1.machineSpeakerId == track2.machineSpeakerId, "Same seed should produce identical machine speaker IDs")
        #expect(track1.machineSpeakerId.hasPrefix("speaker_"), "Machine speaker ID should have 'speaker_' prefix")
    }

    // MARK: - AudioFrame Generator Tests

    @Test func testAudioFrameGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 444)
        var rng2 = Xoshiro(seed: 444)

        let frame1 = audioFrameGen.run(using: &rng1)
        let frame2 = audioFrameGen.run(using: &rng2)

        #expect(frame1 == frame2, "Same seed should produce identical AudioFrames")
        #expect(frame1.data.count == 480 * MemoryLayout<Float>.size, "Audio frame should have 480 float samples (10ms at 48kHz)")
    }

    @Test func testAudioFrameSequenceGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 666)
        var rng2 = Xoshiro(seed: 666)

        let sequence1 = audioFrameSequenceGen(count: 5, startTimestamp: 0).run(using: &rng1)
        let sequence2 = audioFrameSequenceGen(count: 5, startTimestamp: 0).run(using: &rng2)

        #expect(sequence1.count == 5, "Should produce 5 frames")
        #expect(sequence2.count == 5, "Should produce 5 frames")

        for i in 0..<5 {
            #expect(sequence1[i] == sequence2[i], "Frame \(i) should be identical with same seed")
        }
    }

    @Test func testAudioFrameSequenceTimestampsSequential() {
        var rng = Xoshiro(seed: 123)

        let sequence = audioFrameSequenceGen(count: 10, startTimestamp: 1000).run(using: &rng)

        #expect(sequence[0].timestamp == 1000, "First frame should have start timestamp")

        // Verify sequential timestamps (10ms apart for 48kHz audio with 480 samples)
        for i in 1..<sequence.count {
            let expectedTimestamp = 1000 + UInt64(i * 10)
            #expect(sequence[i].timestamp == expectedTimestamp, "Frame \(i) should have timestamp \(expectedTimestamp)")
        }
    }

    // MARK: - Transcript Segment Sequence Generator Tests

    @Test func testTranscriptSegmentSequenceGeneratorDeterministic() {
        var rng1 = Xoshiro(seed: 999)
        var rng2 = Xoshiro(seed: 999)

        let sessionId = SessionID(rawValue: "test-session")
        let sequence1 = transcriptSegmentSequenceGen(count: 3, sessionId: sessionId).run(using: &rng1)
        let sequence2 = transcriptSegmentSequenceGen(count: 3, sessionId: sessionId).run(using: &rng2)

        #expect(sequence1.count == 3, "Should produce 3 segments")

        for i in 0..<3 {
            #expect(sequence1[i].text == sequence2[i].text, "Segment \(i) text should be identical")
            #expect(sequence1[i].startMs == sequence2[i].startMs, "Segment \(i) startMs should be identical")
            #expect(sequence1[i].endMs == sequence2[i].endMs, "Segment \(i) endMs should be identical")
        }
    }

    @Test func testTranscriptSegmentSequenceAlternatesSpeakers() {
        var rng = Xoshiro(seed: 1234)

        let sessionId = SessionID(rawValue: "test-session")
        let sequence = transcriptSegmentSequenceGen(count: 4, sessionId: sessionId).run(using: &rng)

        #expect(sequence[0].machineSpeakerId == "speaker_0", "First segment should be speaker_0")
        #expect(sequence[1].machineSpeakerId == "speaker_1", "Second segment should be speaker_1")
        #expect(sequence[2].machineSpeakerId == "speaker_0", "Third segment should be speaker_0")
        #expect(sequence[3].machineSpeakerId == "speaker_1", "Fourth segment should be speaker_1")
    }

    @Test func testTranscriptSegmentSequenceTimesAreSequential() {
        var rng = Xoshiro(seed: 5678)

        let sessionId = SessionID(rawValue: "test-session")
        let sequence = transcriptSegmentSequenceGen(count: 5, sessionId: sessionId).run(using: &rng)

        #expect(sequence[0].startMs == 0, "First segment should start at 0")

        // Verify each segment follows the previous one
        for i in 1..<sequence.count {
            // Each segment should start 100ms after the previous segment ended
            #expect(sequence[i].startMs == sequence[i-1].endMs + 100,
                    "Segment \(i) should start 100ms after segment \(i-1) ends")
        }
    }

    // MARK: - Multiple Runs Consistency Test

    @Test func testMultipleGeneratorsWithSameSeedConsistent() {
        // This test verifies that running multiple different generators
        // with the same RNG produces consistent results
        var rng1 = Xoshiro(seed: 9999)
        var rng2 = Xoshiro(seed: 9999)

        // Run same sequence of generators
        let session1 = sessionIDGen.run(using: &rng1)
        let person1 = personIDGen.run(using: &rng1)
        let segment1 = transcriptSegmentGen.run(using: &rng1)

        let session2 = sessionIDGen.run(using: &rng2)
        let person2 = personIDGen.run(using: &rng2)
        let segment2 = transcriptSegmentGen.run(using: &rng2)

        #expect(session1 == session2, "Session IDs should match")
        #expect(person1 == person2, "Person IDs should match")
        #expect(segment1 == segment2, "Segments should match")
    }
}
