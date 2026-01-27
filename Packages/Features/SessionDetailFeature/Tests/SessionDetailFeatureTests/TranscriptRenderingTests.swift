import Testing
import Foundation
import DesignSystem
import Models
@testable import SessionDetailFeature

@MainActor
struct TranscriptRenderingTests {

    // MARK: - Segment Merging Tests

    @Test
    func testMergeConsecutiveSegments_empty() {
        let result = TranscriptRendering.mergeConsecutiveSegments([])
        #expect(result.isEmpty)
    }

    @Test
    func testMergeConsecutiveSegments_singleSegment() {
        let segment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0",
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )

        let result = TranscriptRendering.mergeConsecutiveSegments([segment])

        #expect(result.count == 1)
        #expect(result[0].id == segment.id)
        #expect(result[0].text == "Hello")
    }

    @Test
    func testMergeConsecutiveSegments_noMergeWhenSpeakersDiffer() {
        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_1",
                startMs: 5000,
                endMs: 10000,
                text: "Hi there"
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 2)
        #expect(result[0].text == "Hello")
        #expect(result[1].text == "Hi there")
    }

    @Test
    func testMergeConsecutiveSegments_basicMerge() {
        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "world"
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 1)
        #expect(result[0].id == TranscriptSegmentID("seg-1")) // Uses first segment's ID
        #expect(result[0].text == "Hello world")
        #expect(result[0].startMs == 0) // Earliest startMs
        #expect(result[0].endMs == 10000) // Latest endMs
        #expect(result[0].machineSpeakerId == "spk_0")
    }

    @Test
    func testMergeConsecutiveSegments_maxCharSplit() {
        // Test that segments split when combined text exceeds maxCharacters
        let longText = String(repeating: "a", count: 100)

        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: longText
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: longText // Combined would be 201 chars (100 + space + 100)
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments, maxCharacters: 180)

        #expect(result.count == 2)
        #expect(result[0].text == longText)
        #expect(result[1].text == longText)
    }

    @Test
    func testMergeConsecutiveSegments_nilSpeakersNeverMerge() {
        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: nil,
                startMs: 0,
                endMs: 5000,
                text: "Unknown 1"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: nil,
                startMs: 5000,
                endMs: 10000,
                text: "Unknown 2"
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 2)
        #expect(result[0].text == "Unknown 1")
        #expect(result[1].text == "Unknown 2")
    }

    @Test
    func testMergeConsecutiveSegments_nilSpeakerBreaksMerge() {
        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: nil,
                startMs: 5000,
                endMs: 10000,
                text: "Unknown"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_0",
                startMs: 10000,
                endMs: 15000,
                text: "Goodbye"
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 3)
        #expect(result[0].text == "Hello")
        #expect(result[1].text == "Unknown")
        #expect(result[2].text == "Goodbye")
    }

    @Test
    func testMergeConsecutiveSegments_multipleConsecutiveSameSpeaker() {
        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "One"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "two"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_0",
                startMs: 10000,
                endMs: 15000,
                text: "three"
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 1)
        #expect(result[0].id == TranscriptSegmentID("seg-1"))
        #expect(result[0].text == "One two three")
        #expect(result[0].startMs == 0)
        #expect(result[0].endMs == 15000)
    }

    @Test
    func testMergeConsecutiveSegments_complexConversation() {
        // Realistic conversation: A-A-B-A-A-A-B
        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 3000,
                text: "Hello"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 3000,
                endMs: 6000,
                text: "how are you?"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_1",
                startMs: 6000,
                endMs: 9000,
                text: "I'm good thanks"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-4"),
                machineSpeakerId: "spk_0",
                startMs: 9000,
                endMs: 12000,
                text: "That's great"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-5"),
                machineSpeakerId: "spk_0",
                startMs: 12000,
                endMs: 15000,
                text: "to hear"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-6"),
                machineSpeakerId: "spk_0",
                startMs: 15000,
                endMs: 18000,
                text: "really"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-7"),
                machineSpeakerId: "spk_1",
                startMs: 18000,
                endMs: 21000,
                text: "Thanks"
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

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
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "world"
            )
        ]

        // "Hello world" is 11 chars, set max to 10
        let result = TranscriptRendering.mergeConsecutiveSegments(segments, maxCharacters: 10)

        #expect(result.count == 2)
        #expect(result[0].text == "Hello")
        #expect(result[1].text == "world")
    }

    // MARK: - Timestamp Formatting Tests

    @Test
    func testFormatTimestamp_zero() {
        let result = TranscriptRendering.formatTimestamp(0)
        #expect(result == "00:00")
    }

    @Test
    func testFormatTimestamp_seconds() {
        // 12 seconds = 12000 ms
        let result = TranscriptRendering.formatTimestamp(12000)
        #expect(result == "00:12")
    }

    @Test
    func testFormatTimestamp_minutesAndSeconds() {
        // 5 minutes 30 seconds = 330000 ms
        let result = TranscriptRendering.formatTimestamp(330000)
        #expect(result == "05:30")
    }

    @Test
    func testFormatTimestamp_overOneHour() {
        // 65 minutes 15 seconds = 3915000 ms
        // Should show 65:15 (minutes continue past 60)
        let result = TranscriptRendering.formatTimestamp(3915000)
        #expect(result == "65:15")
    }

    @Test
    func testFormatTimestamp_padsZeros() {
        // 1 minute 5 seconds = 65000 ms
        let result = TranscriptRendering.formatTimestamp(65000)
        #expect(result == "01:05")
    }

    // MARK: - Speaker Type Resolution Tests

    @Test
    func testSpeakerType_noMachineSpeakerId_returnsGuest() {
        let segment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil,
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )
        let tracks: [DetailSpeakerTrack] = []

        let result = TranscriptRendering.speakerType(for: segment, speakerTracks: tracks)

        #expect(result == .guest)
    }

    @Test
    func testSpeakerType_noMatchingTrack_returnsGuest() {
        let segment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_unknown",
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )
        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: nil,
                personName: nil
            )
        ]

        let result = TranscriptRendering.speakerType(for: segment, speakerTracks: tracks)

        #expect(result == .guest)
    }

    @Test
    func testSpeakerType_trackWithPersonName_returnsSpeaker() {
        let segment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0",
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )
        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: "person-alice",
                personName: "Alice"
            )
        ]

        let result = TranscriptRendering.speakerType(for: segment, speakerTracks: tracks)

        // Should be .speaker with name and color from displayOrder 0 (sky)
        if case let .speaker(name, _) = result {
            #expect(name == "Alice")
        } else {
            Issue.record("Expected .speaker but got \(result)")
        }
    }

    @Test
    func testSpeakerType_trackWithoutPersonName_displayOrder1_returnsUser() {
        let segment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0",
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )
        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: nil,
                personName: nil
            )
        ]

        let result = TranscriptRendering.speakerType(for: segment, speakerTracks: tracks)

        #expect(result == .user)
    }

    @Test
    func testSpeakerType_trackWithoutPersonName_displayOrder2_returnsGuest() {
        let segment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_1",
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )
        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: nil,
                personName: nil
            ),
            DetailSpeakerTrack(
                id: "track-2",
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personId: nil,
                personName: nil
            )
        ]

        let result = TranscriptRendering.speakerType(for: segment, speakerTracks: tracks)

        #expect(result == .guest)
    }

    @Test
    func testSpeakerType_mixedTracks_correctResolution() {
        // Multiple tracks: one with person name, one without
        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: "person-alice",
                personName: "Alice"
            ),
            DetailSpeakerTrack(
                id: "track-2",
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personId: nil,
                personName: nil
            )
        ]

        // Segment from Alice
        let segment1 = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0",
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )

        // Segment from unassigned speaker
        let segment2 = DetailSegment(
            id: TranscriptSegmentID("seg-2"),
            machineSpeakerId: "spk_1",
            startMs: 5000,
            endMs: 10000,
            text: "Hi there"
        )

        let result1 = TranscriptRendering.speakerType(for: segment1, speakerTracks: tracks)
        let result2 = TranscriptRendering.speakerType(for: segment2, speakerTracks: tracks)

        // Alice should be .speaker
        if case let .speaker(name, _) = result1 {
            #expect(name == "Alice")
        } else {
            Issue.record("Expected .speaker for Alice but got \(result1)")
        }

        // Unassigned displayOrder 2 should be .guest
        #expect(result2 == .guest)
    }

    @Test
    func testSpeakerType_colorAssignment() {
        // Test that colors are assigned based on displayOrder
        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: "p1",
                personName: "Speaker1"  // Should get color at index 0 (sky)
            ),
            DetailSpeakerTrack(
                id: "track-2",
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personId: "p2",
                personName: "Speaker2"  // Should get color at index 1 (lavender)
            ),
            DetailSpeakerTrack(
                id: "track-3",
                machineSpeakerId: "spk_2",
                displayOrder: 3,
                personId: "p3",
                personName: "Speaker3"  // Should get color at index 2 (deep)
            ),
            DetailSpeakerTrack(
                id: "track-4",
                machineSpeakerId: "spk_3",
                displayOrder: 4,
                personId: "p4",
                personName: "Speaker4"  // Should get color at index 3 (dusk)
            ),
            DetailSpeakerTrack(
                id: "track-5",
                machineSpeakerId: "spk_4",
                displayOrder: 5,
                personId: "p5",
                personName: "Speaker5"  // Should cycle back to index 0 (sky)
            )
        ]

        let expectedColors = [
            SpeakerColor.forIndex(0).color, // sky
            SpeakerColor.forIndex(1).color, // lavender
            SpeakerColor.forIndex(2).color, // deep
            SpeakerColor.forIndex(3).color, // dusk
            SpeakerColor.forIndex(4).color, // sky (cycles)
        ]

        for (index, track) in tracks.enumerated() {
            let segment = DetailSegment(
                id: TranscriptSegmentID("seg-\(index)"),
                machineSpeakerId: track.machineSpeakerId,
                startMs: index * 5000,
                endMs: (index + 1) * 5000,
                text: "Text \(index)"
            )

            let result = TranscriptRendering.speakerType(for: segment, speakerTracks: tracks)

            if case let .speaker(_, color) = result {
                #expect(color == expectedColors[index], "Speaker \(index + 1) should have correct color")
            } else {
                Issue.record("Expected .speaker for track \(index) but got \(result)")
            }
        }
    }

    // MARK: - Integration: Speaker and Timestamp Formatting

    @Test
    func testSpeakerAndTimestampFormatting() {
        // Test that the combined formatting produces expected results
        // This is the main acceptance criteria test

        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: "person-alice",
                personName: "Alice"
            ),
            DetailSpeakerTrack(
                id: "track-2",
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personId: nil,
                personName: nil
            )
        ]

        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 12000,  // 00:12
                endMs: 18000,
                text: "Hello everyone"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_1",
                startMs: 18000,  // 00:18
                endMs: 35000,
                text: "Hi there"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: nil,
                startMs: 35000,  // 00:35
                endMs: 52000,
                text: "Unknown speaker"
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-4"),
                machineSpeakerId: "spk_0",
                startMs: 75000,  // 01:15
                endMs: 90000,
                text: "Back to Alice"
            )
        ]

        // Segment 1: Alice at 00:12
        let speaker1 = TranscriptRendering.speakerType(for: segments[0], speakerTracks: tracks)
        let timestamp1 = TranscriptRendering.formatTimestamp(segments[0].startMs)
        if case let .speaker(name, _) = speaker1 {
            #expect(name == "Alice")
        } else {
            Issue.record("Expected .speaker for segment 1")
        }
        #expect(timestamp1 == "00:12")

        // Segment 2: Guest (unassigned displayOrder 2) at 00:18
        let speaker2 = TranscriptRendering.speakerType(for: segments[1], speakerTracks: tracks)
        let timestamp2 = TranscriptRendering.formatTimestamp(segments[1].startMs)
        #expect(speaker2 == .guest)
        #expect(timestamp2 == "00:18")

        // Segment 3: Guest (no machine speaker ID) at 00:35
        let speaker3 = TranscriptRendering.speakerType(for: segments[2], speakerTracks: tracks)
        let timestamp3 = TranscriptRendering.formatTimestamp(segments[2].startMs)
        #expect(speaker3 == .guest)
        #expect(timestamp3 == "00:35")

        // Segment 4: Alice at 01:15
        let speaker4 = TranscriptRendering.speakerType(for: segments[3], speakerTracks: tracks)
        let timestamp4 = TranscriptRendering.formatTimestamp(segments[3].startMs)
        if case let .speaker(name, _) = speaker4 {
            #expect(name == "Alice")
        } else {
            Issue.record("Expected .speaker for segment 4")
        }
        #expect(timestamp4 == "01:15")
    }
}
