import Testing
import Foundation
import Dependencies
import Models
@testable import Processing
@testable import Audio

@Test func testScriptedSegmentsEmitted() async throws {
    // Create a custom script with known segments
    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "test-seg-1"),
                text: "First segment",
                startMs: 0,
                endMs: 1000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "test-seg-2"),
                text: "Second segment",
                startMs: 1500,
                endMs: 2500,
                speakerId: "spk_1",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "test-seg-3"),
                text: "Third segment",
                startMs: 3000,
                endMs: 4000,
                speakerId: "spk_0",
                isFinal: false
            ),
        ]
    )

    let mockClient = MockFluidAudioClient.client(script: script)

    // Create a dummy audio stream (mock doesn't actually use it)
    let dummyAudioStream = AsyncStream<AudioFrame> { continuation in
        continuation.finish()
    }

    // Start transcription and collect segments
    let segmentStream = try await mockClient.startTranscription(dummyAudioStream)

    var receivedSegments: [TranscriptSegment] = []
    for await segment in segmentStream {
        receivedSegments.append(segment)
    }

    // Verify all segments were emitted
    #expect(receivedSegments.count == 3, "Should receive exactly 3 segments")

    // Verify first segment (live segments have nil speakerId - diarization deferred to post-stop)
    #expect(receivedSegments[0].id.rawValue == "test-seg-1")
    #expect(receivedSegments[0].text == "First segment")
    #expect(receivedSegments[0].startMs == 0)
    #expect(receivedSegments[0].endMs == 1000)
    #expect(receivedSegments[0].speakerId == nil, "Live segments should have nil speakerId")
    #expect(receivedSegments[0].isFinal == true)

    // Verify second segment
    #expect(receivedSegments[1].id.rawValue == "test-seg-2")
    #expect(receivedSegments[1].text == "Second segment")
    #expect(receivedSegments[1].startMs == 1500)
    #expect(receivedSegments[1].endMs == 2500)
    #expect(receivedSegments[1].speakerId == nil, "Live segments should have nil speakerId")
    #expect(receivedSegments[1].isFinal == true)

    // Verify third segment (partial)
    #expect(receivedSegments[2].id.rawValue == "test-seg-3")
    #expect(receivedSegments[2].text == "Third segment")
    #expect(receivedSegments[2].speakerId == nil, "Live segments should have nil speakerId")
    #expect(receivedSegments[2].isFinal == false)
}

@Test func testEmptyScriptEmitsNoSegments() async throws {
    let mockClient = MockFluidAudioClient.empty

    let dummyAudioStream = AsyncStream<AudioFrame> { continuation in
        continuation.finish()
    }

    let segmentStream = try await mockClient.startTranscription(dummyAudioStream)

    var receivedSegments: [TranscriptSegment] = []
    for await segment in segmentStream {
        receivedSegments.append(segment)
    }

    #expect(receivedSegments.isEmpty, "Empty script should emit no segments")
}

@Test func testTwoSpeakerConversationScript() async throws {
    let mockClient = MockFluidAudioClient.twoSpeakerConversation

    let dummyAudioStream = AsyncStream<AudioFrame> { continuation in
        continuation.finish()
    }

    let segmentStream = try await mockClient.startTranscription(dummyAudioStream)

    var receivedSegments: [TranscriptSegment] = []
    for await segment in segmentStream {
        receivedSegments.append(segment)
    }

    #expect(receivedSegments.count == 3, "Two speaker conversation should have 3 segments")

    // Live segments have nil speakerId (diarization deferred to post-stop processing)
    #expect(receivedSegments[0].speakerId == nil, "Live segments should have nil speakerId")
    #expect(receivedSegments[1].speakerId == nil, "Live segments should have nil speakerId")
    #expect(receivedSegments[2].speakerId == nil, "Live segments should have nil speakerId")

    // Verify all are final
    #expect(receivedSegments.allSatisfy { $0.isFinal })
}

@Test func testPartialSegmentsScript() async throws {
    let mockClient = MockFluidAudioClient.withPartialSegments

    let dummyAudioStream = AsyncStream<AudioFrame> { continuation in
        continuation.finish()
    }

    let segmentStream = try await mockClient.startTranscription(dummyAudioStream)

    var receivedSegments: [TranscriptSegment] = []
    for await segment in segmentStream {
        receivedSegments.append(segment)
    }

    #expect(receivedSegments.count == 4, "Script with partial segments should emit 4 segments")

    // Verify partial vs final
    let partialCount = receivedSegments.filter { !$0.isFinal }.count
    let finalCount = receivedSegments.filter { $0.isFinal }.count
    #expect(partialCount == 2, "Should have 2 partial segments")
    #expect(finalCount == 2, "Should have 2 final segments")
}

@Test func testIsTranscribingState() async throws {
    let actor = MockFluidAudioClientActor(script: .empty)

    // Initially not transcribing
    var isTranscribing = await actor.getIsTranscribing()
    #expect(!isTranscribing, "Should not be transcribing initially")

    // Start transcription
    let dummyAudioStream = AsyncStream<AudioFrame> { continuation in
        continuation.finish()
    }
    let _ = await actor.startTranscription(audioStream: dummyAudioStream)

    // Wait for the stream to complete (empty script)
    try await waitUntil("transcription completes") {
        await actor.getIsTranscribing() == false
    }

    // Should be done transcribing after empty script completes
    isTranscribing = await actor.getIsTranscribing()
    #expect(!isTranscribing, "Should not be transcribing after completion")
}

@Test func testStopTranscription() async throws {
    // Create a script with many segments
    var manySegments: [ScriptedSegment] = []
    for i in 0..<100 {
        let segment = ScriptedSegment(
            id: TranscriptSegmentID(rawValue: "seg-\(i)"),
            text: "Segment \(i)",
            startMs: UInt64(i * 1000),
            endMs: UInt64(i * 1000 + 500),
            speakerId: "spk_0",
            isFinal: true
        )
        manySegments.append(segment)
    }
    let script = MockFluidAudioScript(segments: manySegments)
    let actor = MockFluidAudioClientActor(script: script)

    let dummyAudioStream = AsyncStream<AudioFrame> { continuation in
        continuation.finish()
    }

    let segmentStream = await actor.startTranscription(audioStream: dummyAudioStream)

    // Collect a few segments then stop
    var receivedCount = 0
    for await _ in segmentStream {
        receivedCount += 1
        if receivedCount >= 5 {
            await actor.stopTranscription()
            break
        }
    }

    // Should have stopped after stop was called
    let isTranscribing = await actor.getIsTranscribing()
    #expect(!isTranscribing, "Should not be transcribing after stop")
}

@Test func testScriptedSegmentConversion() {
    let scripted = ScriptedSegment(
        id: TranscriptSegmentID(rawValue: "conv-test"),
        text: "Test conversion",
        startMs: 100,
        endMs: 200,
        speakerId: "spk_test",
        isFinal: true
    )

    let converted = scripted.toTranscriptSegment()

    #expect(converted.id == scripted.id)
    #expect(converted.text == scripted.text)
    #expect(converted.startMs == scripted.startMs)
    #expect(converted.endMs == scripted.endMs)
    #expect(converted.speakerId == scripted.speakerId)
    #expect(converted.isFinal == scripted.isFinal)
}
