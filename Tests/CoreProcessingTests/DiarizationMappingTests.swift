import Testing
import Foundation
@testable import Processing

@Test func testDominantSpeakerAssignment() {
    // Test case 1: Single speaker - should return that speaker
    let singleSpeaker = [
        DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 5)
    ]
    #expect(DiarizationMapping.findDominantSpeaker(in: singleSpeaker) == "spk_0")

    // Test case 2: Two speakers, first has longer duration
    let twoSpeakersFirstDominant = [
        DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 3),
        DiarizationMapping.SpeakerSegment(speakerId: "spk_1", startTimeSeconds: 3, endTimeSeconds: 5)
    ]
    // spk_0: 3 seconds, spk_1: 2 seconds
    #expect(DiarizationMapping.findDominantSpeaker(in: twoSpeakersFirstDominant) == "spk_0")

    // Test case 3: Two speakers, second has longer duration
    let twoSpeakersSecondDominant = [
        DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 1),
        DiarizationMapping.SpeakerSegment(speakerId: "spk_1", startTimeSeconds: 1, endTimeSeconds: 5)
    ]
    // spk_0: 1 second, spk_1: 4 seconds
    #expect(DiarizationMapping.findDominantSpeaker(in: twoSpeakersSecondDominant) == "spk_1")

    // Test case 4: Multiple non-contiguous segments for same speaker (aggregation)
    let interleaved = [
        DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 1),   // 1s
        DiarizationMapping.SpeakerSegment(speakerId: "spk_1", startTimeSeconds: 1, endTimeSeconds: 3),   // 2s
        DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 3, endTimeSeconds: 6),   // 3s
        DiarizationMapping.SpeakerSegment(speakerId: "spk_1", startTimeSeconds: 6, endTimeSeconds: 7)    // 1s
    ]
    // spk_0: 1+3 = 4 seconds, spk_1: 2+1 = 3 seconds
    #expect(DiarizationMapping.findDominantSpeaker(in: interleaved) == "spk_0")

    // Test case 5: Three speakers
    let threeSpeakers = [
        DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 2),   // 2s
        DiarizationMapping.SpeakerSegment(speakerId: "spk_1", startTimeSeconds: 2, endTimeSeconds: 5),   // 3s
        DiarizationMapping.SpeakerSegment(speakerId: "spk_2", startTimeSeconds: 5, endTimeSeconds: 10)   // 5s
    ]
    // spk_0: 2s, spk_1: 3s, spk_2: 5s -> spk_2 is dominant
    #expect(DiarizationMapping.findDominantSpeaker(in: threeSpeakers) == "spk_2")

    // Test case 6: Empty segments - should return nil
    #expect(DiarizationMapping.findDominantSpeaker(in: []) == nil)

    // Test case 7: Zero duration segment (start == end)
    let zeroAndNonZero = [
        DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 0),
        DiarizationMapping.SpeakerSegment(speakerId: "spk_1", startTimeSeconds: 0, endTimeSeconds: 1)
    ]
    #expect(DiarizationMapping.findDominantSpeaker(in: zeroAndNonZero) == "spk_1")
}

@Test func testDisplayOrderAssignment() {
    // Test case 1: Single speaker gets order 1
    let single = DiarizationMapping.assignDisplayOrders(speakerIds: ["spk_0"])
    #expect(single == ["spk_0": 1])

    // Test case 2: Two speakers in order
    let two = DiarizationMapping.assignDisplayOrders(speakerIds: ["spk_0", "spk_1"])
    #expect(two == ["spk_0": 1, "spk_1": 2])

    // Test case 3: Repeated speakers preserve first assignment
    let repeated = DiarizationMapping.assignDisplayOrders(speakerIds: ["spk_0", "spk_1", "spk_0", "spk_1", "spk_0"])
    #expect(repeated == ["spk_0": 1, "spk_1": 2])

    // Test case 4: Three speakers with interleaving
    let three = DiarizationMapping.assignDisplayOrders(speakerIds: ["spk_0", "spk_2", "spk_1", "spk_2", "spk_0"])
    #expect(three == ["spk_0": 1, "spk_2": 2, "spk_1": 3])

    // Test case 5: Empty input
    let empty = DiarizationMapping.assignDisplayOrders(speakerIds: [])
    #expect(empty.isEmpty)
}

@Test func testSpeakerSegmentDuration() {
    // Normal segment
    let segment1 = DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 1.5, endTimeSeconds: 4.5)
    #expect(segment1.durationSeconds == 3.0)

    // Zero duration
    let segment2 = DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 2.0, endTimeSeconds: 2.0)
    #expect(segment2.durationSeconds == 0.0)

    // Negative duration (edge case - should clamp to 0)
    let segment3 = DiarizationMapping.SpeakerSegment(speakerId: "spk_0", startTimeSeconds: 5.0, endTimeSeconds: 3.0)
    #expect(segment3.durationSeconds == 0.0)
}
