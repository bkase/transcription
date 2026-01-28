import Testing
import Foundation
import DesignSystem
import Models
@testable import RecordingFeature

@MainActor
struct RecordingSpeakerRenderingTests {

    // MARK: - Segment Merging Tests

    @Test
    func testMergeConsecutiveSegments_empty() {
        let result = RecordingSpeakerRendering.mergeConsecutiveSegments([])
        #expect(result.isEmpty)
    }

    @Test
    func testMergeConsecutiveSegments_singleSegment() {
        let segment = LiveSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0",
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            isFinal: true
        )

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments([segment])

        #expect(result.count == 1)
        #expect(result[0].id == segment.id)
        #expect(result[0].text == "Hello")
        #expect(result[0].isFinal == true)
    }

    @Test
    func testMergeConsecutiveSegments_noMergeWhenSpeakersDiffer() {
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_1",
                startMs: 5000,
                endMs: 10000,
                text: "Hi there",
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 2)
        #expect(result[0].text == "Hello")
        #expect(result[1].text == "Hi there")
    }

    @Test
    func testMergeConsecutiveSegments_basicMerge() {
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "world",
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 1)
        #expect(result[0].id == TranscriptSegmentID("seg-1")) // Uses first segment's ID
        #expect(result[0].text == "Hello world")
        #expect(result[0].startMs == 0) // Earliest startMs
        #expect(result[0].endMs == 10000) // Latest endMs
        #expect(result[0].machineSpeakerId == "spk_0")
        #expect(result[0].isFinal == true)
    }

    @Test
    func testMergeConsecutiveSegments_maxCharSplit() {
        // Test that segments split when combined text exceeds maxCharacters
        let longText = String(repeating: "a", count: 100)

        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: longText,
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: longText, // Combined would be 201 chars (100 + space + 100)
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments, maxCharacters: 180)

        #expect(result.count == 2)
        #expect(result[0].text == longText)
        #expect(result[1].text == longText)
    }

    @Test
    func testMergeConsecutiveSegments_nilSpeakersNeverMerge() {
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: nil,
                startMs: 0,
                endMs: 5000,
                text: "Unknown 1",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: nil,
                startMs: 5000,
                endMs: 10000,
                text: "Unknown 2",
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 2)
        #expect(result[0].text == "Unknown 1")
        #expect(result[1].text == "Unknown 2")
    }

    @Test
    func testMergeConsecutiveSegments_nilSpeakerBreaksMerge() {
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: nil,
                startMs: 5000,
                endMs: 10000,
                text: "Unknown",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_0",
                startMs: 10000,
                endMs: 15000,
                text: "Goodbye",
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 3)
        #expect(result[0].text == "Hello")
        #expect(result[1].text == "Unknown")
        #expect(result[2].text == "Goodbye")
    }

    @Test
    func testMergeConsecutiveSegments_fivePlusSameSpeaker() {
        // Test that ALL consecutive same-speaker segments are merged (5+)
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "One",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "two",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_0",
                startMs: 10000,
                endMs: 15000,
                text: "three",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-4"),
                machineSpeakerId: "spk_0",
                startMs: 15000,
                endMs: 20000,
                text: "four",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-5"),
                machineSpeakerId: "spk_0",
                startMs: 20000,
                endMs: 25000,
                text: "five",
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 1)
        #expect(result[0].id == TranscriptSegmentID("seg-1"))
        #expect(result[0].text == "One two three four five")
        #expect(result[0].startMs == 0)
        #expect(result[0].endMs == 25000)
    }

    @Test
    func testMergeConsecutiveSegments_complexConversation() {
        // Realistic conversation: A-A-B-A-A-A-B
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 3000,
                text: "Hello",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 3000,
                endMs: 6000,
                text: "how are you?",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_1",
                startMs: 6000,
                endMs: 9000,
                text: "I'm good thanks",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-4"),
                machineSpeakerId: "spk_0",
                startMs: 9000,
                endMs: 12000,
                text: "That's great",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-5"),
                machineSpeakerId: "spk_0",
                startMs: 12000,
                endMs: 15000,
                text: "to hear",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-6"),
                machineSpeakerId: "spk_0",
                startMs: 15000,
                endMs: 18000,
                text: "really",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-7"),
                machineSpeakerId: "spk_1",
                startMs: 18000,
                endMs: 21000,
                text: "Thanks",
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        // Should produce: A(merged), B, A(merged), B
        #expect(result.count == 4)

        #expect(result[0].machineSpeakerId == "spk_0")
        #expect(result[0].text == "Hello how are you?")
        #expect(result[0].startMs == 0)
        #expect(result[0].endMs == 6000)

        #expect(result[1].machineSpeakerId == "spk_1")
        #expect(result[1].text == "I'm good thanks")

        #expect(result[2].machineSpeakerId == "spk_0")
        #expect(result[2].text == "That's great to hear really")
        #expect(result[2].startMs == 9000)
        #expect(result[2].endMs == 18000)

        #expect(result[3].machineSpeakerId == "spk_1")
        #expect(result[3].text == "Thanks")
    }

    @Test
    func testMergeConsecutiveSegments_customMaxCharacters() {
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "world",
                isFinal: true
            )
        ]

        // "Hello world" is 11 chars, set max to 10
        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments, maxCharacters: 10)

        #expect(result.count == 2)
        #expect(result[0].text == "Hello")
        #expect(result[1].text == "world")
    }

    @Test
    func testMergeConsecutiveSegments_isFinalFromLastSegment() {
        // When merging, isFinal should come from the last segment
        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello",
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "world",
                isFinal: false // Last segment is not final
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 1)
        #expect(result[0].text == "Hello world")
        #expect(result[0].isFinal == false) // Uses last segment's isFinal
    }

    @Test
    func testMergeConsecutiveSegments_defaultMaxCharactersIs600() {
        // Verify default max characters is 600
        #expect(RecordingSpeakerRendering.defaultMaxCharacters == 600)
    }

    @Test
    func testMergeConsecutiveSegments_largeTextWithin600Limit() {
        // Test that segments up to 600 chars merge correctly with default limit
        let text400 = String(repeating: "a", count: 400)

        let segments = [
            LiveSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: text400,
                isFinal: true
            ),
            LiveSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "short", // 400 + 1 (space) + 5 = 406 chars, under 600
                isFinal: true
            )
        ]

        let result = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 1)
        #expect(result[0].text.count == 406) // 400 + space + 5
    }

    // MARK: - Speaker Type Resolution Tests

    @Test
    func testSpeakerType_noMachineSpeakerId_returnsUnassigned() {
        let segment = LiveSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil,
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            isFinal: true
        )
        let tracks: [LiveSpeakerTrack] = []

        let result = RecordingSpeakerRendering.speakerType(for: segment, speakerTracks: tracks)

        // Should return unassigned with displayOrder 1 and sky color
        if case let .unassigned(displayOrder, _) = result {
            #expect(displayOrder == 1)
        } else {
            Issue.record("Expected .unassigned but got \(result)")
        }
    }

    @Test
    func testSpeakerType_noMatchingTrack_returnsUnassigned() {
        let segment = LiveSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_unknown",
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            isFinal: true
        )
        let tracks = [
            LiveSpeakerTrack(
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: nil
            )
        ]

        let result = RecordingSpeakerRendering.speakerType(for: segment, speakerTracks: tracks)

        // Should return unassigned with displayOrder 1 (default)
        if case let .unassigned(displayOrder, _) = result {
            #expect(displayOrder == 1)
        } else {
            Issue.record("Expected .unassigned but got \(result)")
        }
    }

    @Test
    func testSpeakerType_trackWithPersonName_returnsSpeaker() {
        let segment = LiveSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0",
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            isFinal: true
        )
        let tracks = [
            LiveSpeakerTrack(
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: "Alice"
            )
        ]

        let result = RecordingSpeakerRendering.speakerType(for: segment, speakerTracks: tracks)

        // Should be .speaker with name and color from displayOrder 0 (sky)
        if case let .speaker(name, _) = result {
            #expect(name == "Alice")
        } else {
            Issue.record("Expected .speaker but got \(result)")
        }
    }

    @Test
    func testSpeakerType_trackWithoutPersonName_displayOrder2_returnsUnassigned() {
        let segment = LiveSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_1",
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            isFinal: true
        )
        let tracks = [
            LiveSpeakerTrack(
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: nil
            ),
            LiveSpeakerTrack(
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personName: nil
            )
        ]

        let result = RecordingSpeakerRendering.speakerType(for: segment, speakerTracks: tracks)

        // Should return unassigned with displayOrder 2 and lavender color
        if case let .unassigned(displayOrder, _) = result {
            #expect(displayOrder == 2)
        } else {
            Issue.record("Expected .unassigned but got \(result)")
        }
    }
}
