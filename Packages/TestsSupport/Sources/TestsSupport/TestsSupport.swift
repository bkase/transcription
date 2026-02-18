import Foundation
import Models
import Persistence
import Audio
import Processing
import SnapshotTesting
import Gen

// MARK: - ID Generators

/// Generator for random UUID-style strings (used as ID bases)
private let uuidStyleStringGen: Gen<String> = Gen.letterOrNumber.string(of: .always(8))

/// Generator for SessionID values with deterministic prefixes
public let sessionIDGen: Gen<SessionID> = uuidStyleStringGen.map { SessionID(rawValue: "session-\($0)") }

/// Generator for PersonID values with deterministic prefixes
public let personIDGen: Gen<PersonID> = uuidStyleStringGen.map { PersonID(rawValue: "person-\($0)") }

/// Generator for SpeakerTrackID values with deterministic prefixes
public let speakerTrackIDGen: Gen<SpeakerTrackID> = uuidStyleStringGen.map { SpeakerTrackID(rawValue: "track-\($0)") }

/// Generator for TranscriptSegmentID values with deterministic prefixes
public let transcriptSegmentIDGen: Gen<TranscriptSegmentID> = uuidStyleStringGen.map { TranscriptSegmentID(rawValue: "segment-\($0)") }

// MARK: - Time Generators

/// Generator for milliseconds values (0 to 600000 - 10 minutes max)
public let millisecondsGen: Gen<Int> = Gen.int(in: 0...600_000)

/// Generator for Milliseconds type
public let millisecondsTypeGen: Gen<Milliseconds> = millisecondsGen.map { Milliseconds($0) }

/// Generator for UInt64 milliseconds (commonly used for timestamps)
public let uint64MillisecondsGen: Gen<UInt64> = Gen.int(in: 0...600_000).map { UInt64($0) }

/// Generator for duration values in ms (1-30 seconds)
public let durationMsGen: Gen<Int> = Gen.int(in: 1000...30000)

/// Generator for UInt64 duration values in ms
public let uint64DurationMsGen: Gen<UInt64> = durationMsGen.map { UInt64($0) }

// MARK: - Text Generators

/// Array of realistic transcript text snippets
private let transcriptTexts = [
    "Hello, how are you doing today?",
    "That sounds like a great idea.",
    "Let me think about that for a moment.",
    "I completely agree with your point.",
    "Can you explain that in more detail?",
    "Thanks for sharing your perspective.",
    "What are the next steps we should take?",
    "I appreciate your feedback on this.",
    "Let's schedule a follow-up meeting.",
    "That's an interesting observation.",
    "We should consider the alternatives.",
    "I'll look into that and get back to you.",
    "Good morning everyone.",
    "Let's get started with the agenda.",
    "Any questions before we proceed?",
]

/// Generator for realistic transcript text snippets
public let transcriptTextGen: Gen<String> = Gen.element(of: transcriptTexts).map { $0 ?? "Hello" }

/// Array of person names
private let personNames = [
    "Alice Johnson",
    "Bob Smith",
    "Carol Williams",
    "David Brown",
    "Emma Davis",
    "Frank Miller",
    "Grace Wilson",
    "Henry Taylor",
]

/// Generator for person names
public let personNameGen: Gen<String> = Gen.element(of: personNames).map { $0 ?? "Unknown" }

/// Array of color tokens
private let colorTokens = ["sky", "lavender", "deep", "dusk"]

/// Generator for color tokens
public let colorTokenGen: Gen<String> = Gen.element(of: colorTokens).map { $0 ?? "sky" }

/// Generator for machine speaker IDs (e.g., "speaker_0", "speaker_1")
public let machineSpeakerIDGen: Gen<String> = Gen.int(in: 0...9).map { "speaker_\($0)" }

// MARK: - Optional String Generators

/// Generator for optional machine speaker IDs
public let optionalMachineSpeakerIDGen: Gen<String?> = zip(Gen.bool, machineSpeakerIDGen)
    .map { (includeIt, speakerId) in includeIt ? speakerId : nil }

// MARK: - TranscriptSegment Generators

/// Generator for TranscriptSegment (from Processing module)
public let transcriptSegmentGen: Gen<TranscriptSegment> = zip(
    transcriptSegmentIDGen,
    transcriptTextGen,
    uint64MillisecondsGen,
    uint64DurationMsGen,
    optionalMachineSpeakerIDGen,
    Gen.bool
).map { (id, text, startMs, durationMs, speakerId, isFinal) in
    TranscriptSegment(
        id: id,
        text: text,
        startMs: startMs,
        endMs: startMs + durationMs,
        speakerId: speakerId,
        isFinal: isFinal
    )
}

/// Generator for final-only TranscriptSegments (isFinal = true)
public let finalTranscriptSegmentGen: Gen<TranscriptSegment> = zip(
    transcriptSegmentIDGen,
    transcriptTextGen,
    uint64MillisecondsGen,
    uint64DurationMsGen,
    optionalMachineSpeakerIDGen
).map { (id, text, startMs, durationMs, speakerId) in
    TranscriptSegment(
        id: id,
        text: text,
        startMs: startMs,
        endMs: startMs + durationMs,
        speakerId: speakerId,
        isFinal: true
    )
}

// MARK: - Database Record Generators

/// Array of processing states
private let processingStates: [ProcessingState] = [.recording, .partial, .processed, .failed]

/// Generator for ProcessingState
public let processingStateGen: Gen<ProcessingState> = Gen.element(of: processingStates).map { $0 ?? .recording }

/// Generator for timestamps (Unix timestamp in reasonable range)
public let timestampGen: Gen<Double> = Gen.int(in: 1700000000...1800000000).map { Double($0) }

/// Generator for Date values
public let dateGen: Gen<Date> = timestampGen.map { Date(timeIntervalSince1970: $0) }

/// Generator for completed SessionRecord (with endedAt and processed state)
public let completedSessionRecordGen: Gen<SessionRecord> = zip(
    sessionIDGen,
    dateGen,
    Gen.int(in: 60...3600),
    Gen.int(in: 1...100),
    transcriptTextGen,
    millisecondsGen,
    Gen.int(in: 1...5)
).map { (sessionId, startedAt, durationSec, meetingNum, previewText, durationMs, speakerCount) in
    let endedAt = startedAt.addingTimeInterval(Double(durationSec))
    return SessionRecord(
        id: sessionId.rawValue,
        startedAt: startedAt,
        endedAt: endedAt,
        title: "Meeting \(meetingNum)",
        previewText: previewText,
        durationMs: durationMs,
        audioPath: "/audio/\(sessionId.rawValue).m4a",
        processingState: .processed,
        speakerCount: speakerCount,
        updatedAt: endedAt
    )
}

/// Helper struct for session record generation
private struct SessionRecordInputs {
    let sessionId: SessionID
    let startedAt: Date
    let hasEnded: Bool
    let durationSec: Int
    let title: String?
    let previewText: String?
    let durationMs: Int
    let state: ProcessingState
    let speakerCount: Int
}

/// First batch of session inputs
private let sessionRecordBatch1 = zip(
    sessionIDGen,
    dateGen,
    Gen.bool,
    Gen.int(in: 60...3600),
    Gen.bool
)

/// Second batch of session inputs
private let sessionRecordBatch2 = zip(
    Gen.int(in: 1...100),
    Gen.bool,
    transcriptTextGen,
    millisecondsGen,
    processingStateGen
)

/// Generator for SessionRecord (random states)
public let sessionRecordGen: Gen<SessionRecord> = zip(
    sessionRecordBatch1,
    sessionRecordBatch2,
    Gen.int(in: 0...5)
).map { (batch1, batch2, speakerCount) in
    let (sessionId, startedAt, hasEnded, durationSec, hasTitle) = batch1
    let (meetingNum, hasPreview, previewText, durationMs, state) = batch2

    let endedAt: Date? = hasEnded ? startedAt.addingTimeInterval(Double(durationSec)) : nil
    let title: String? = hasTitle ? "Meeting \(meetingNum)" : nil
    let preview: String? = hasPreview ? previewText : nil
    let finalDurationMs: Int? = hasEnded ? durationMs : nil
    let finalState: ProcessingState = hasEnded ? state : .recording
    let updatedAt = endedAt ?? startedAt

    return SessionRecord(
        id: sessionId.rawValue,
        startedAt: startedAt,
        endedAt: endedAt,
        title: title,
        previewText: preview,
        durationMs: finalDurationMs,
        audioPath: nil,
        processingState: finalState,
        speakerCount: speakerCount,
        updatedAt: updatedAt
    )
}

/// Generator for PersonRecord
public let personRecordGen: Gen<PersonRecord> = zip(
    personIDGen,
    personNameGen,
    colorTokenGen,
    dateGen
).map { (personId, name, colorToken, createdAt) in
    PersonRecord(
        id: personId.rawValue,
        name: name,
        colorToken: colorToken,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

/// Generator for optional confidence values
public let optionalConfidenceGen: Gen<Double?> = zip(Gen.bool, Gen.int(in: 50...100))
    .map { (includeIt, value) in includeIt ? Double(value) / 100.0 : nil }

/// Generator for TranscriptSegmentRecord
public let transcriptSegmentRecordGen: Gen<TranscriptSegmentRecord> = zip(
    transcriptSegmentIDGen,
    sessionIDGen,
    millisecondsGen,
    durationMsGen,
    optionalMachineSpeakerIDGen,
    transcriptTextGen,
    optionalConfidenceGen,
    Gen.bool,
    dateGen
).map { (segmentId, sessionId, startMs, durationMs, speakerId, text, confidence, isFinal, createdAt) in
    TranscriptSegmentRecord(
        id: segmentId.rawValue,
        sessionId: sessionId.rawValue,
        startMs: startMs,
        endMs: startMs + durationMs,
        machineSpeakerId: speakerId,
        text: text,
        confidence: confidence,
        isFinal: isFinal,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

/// Generator for optional PersonID raw values
public let optionalPersonIdRawGen: Gen<String?> = zip(Gen.bool, personIDGen)
    .map { (includeIt, personId) in includeIt ? personId.rawValue : nil }

/// Generator for SpeakerTrackRecord
public let speakerTrackRecordGen: Gen<SpeakerTrackRecord> = zip(
    speakerTrackIDGen,
    sessionIDGen,
    machineSpeakerIDGen,
    Gen.int(in: 1...10),
    optionalPersonIdRawGen
).map { (trackId, sessionId, machineSpeakerId, displayOrder, personId) in
    SpeakerTrackRecord(
        id: trackId.rawValue,
        sessionId: sessionId.rawValue,
        machineSpeakerId: machineSpeakerId,
        displayOrder: displayOrder,
        personId: personId
    )
}

// MARK: - Audio Generators

/// Generator for audio frame timestamp
public let audioTimestampGen: Gen<UInt64> = uint64MillisecondsGen

/// Generator for audio sample value
public let audioSampleGen: Gen<Float> = Gen.int(in: -32768...32767).map { Float($0) / 32768.0 }

/// Generator for AudioFrame with 480 samples (10ms at 48kHz)
public let audioFrameGen: Gen<AudioFrame> = zip(
    audioTimestampGen,
    audioSampleGen.array(of: .always(480))
).map { (timestamp, samples) in
    var samplesCopy = samples
    let data = Data(bytes: &samplesCopy, count: samples.count * MemoryLayout<Float>.size)
    return AudioFrame(data: data, timestamp: timestamp)
}

// MARK: - Compound Generator Functions

/// Creates a generator for a sequence of AudioFrames with sequential timestamps
/// - Parameters:
///   - count: Number of frames to generate
///   - startTimestamp: Starting timestamp in milliseconds
/// - Returns: Generator producing an array of AudioFrames
public func audioFrameSequenceGen(count: Int, startTimestamp: UInt64 = 0) -> Gen<[AudioFrame]> {
    audioSampleGen.array(of: .always(480)).array(of: .always(count)).map { sampleArrays in
        var frames: [AudioFrame] = []
        var currentTimestamp = startTimestamp
        let frameDurationMs: UInt64 = 10 // 10ms per frame at 48kHz with 480 samples

        for samples in sampleArrays {
            var samplesCopy = samples
            let data = Data(bytes: &samplesCopy, count: samples.count * MemoryLayout<Float>.size)
            frames.append(AudioFrame(data: data, timestamp: currentTimestamp))
            currentTimestamp += frameDurationMs
        }
        return frames
    }
}

/// Creates a generator for a sequence of transcript segments with sequential timing
/// - Parameters:
///   - count: Number of segments to generate
///   - sessionId: Session ID to associate with all segments
/// - Returns: Generator producing an array of TranscriptSegmentRecords
public func transcriptSegmentSequenceGen(count: Int, sessionId: SessionID) -> Gen<[TranscriptSegmentRecord]> {
    zip(
        durationMsGen.array(of: .always(count)),
        transcriptTextGen.array(of: .always(count))
    ).map { (durations, texts) in
        var segments: [TranscriptSegmentRecord] = []
        var currentStartMs = 0
        let createdAt = Date()

        for i in 0..<count {
            let durationMs = durations[i]
            let endMs = currentStartMs + durationMs
            let speakerIndex = i % 2 // Alternate between two speakers
            let machineSpeakerId = "speaker_\(speakerIndex)"

            let segment = TranscriptSegmentRecord(
                id: "segment-\(i)",
                sessionId: sessionId.rawValue,
                startMs: currentStartMs,
                endMs: endMs,
                machineSpeakerId: machineSpeakerId,
                text: texts[i],
                confidence: 0.95,
                isFinal: true,
                createdAt: createdAt,
                updatedAt: createdAt
            )
            segments.append(segment)
            currentStartMs = endMs + 100 // Small gap between segments
        }
        return segments
    }
}

// MARK: - Snapshot Testing Helpers

/// Helper function for asserting snapshots
public func assertSnapshot<Value>(
    matching value: Value,
    as snapshotting: Snapshotting<Value, some Any>,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    SnapshotTesting.assertSnapshot(
        of: value,
        as: snapshotting,
        file: file,
        testName: testName,
        line: line
    )
}
