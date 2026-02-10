import Testing
import CustomDump
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
        let longText = String(repeating: "a", count: 350)

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
                text: longText // Combined would be 701 chars (350 + space + 350)
            )
        ]

        // New default is 600, so this should split
        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 2)
        #expect(result[0].text == longText)
        #expect(result[1].text == longText)
    }

    @Test
    func testMergeConsecutiveSegments_defaultMaxCharactersIs600() {
        // Verify default max characters is 600
        #expect(TranscriptRendering.defaultMaxCharacters == 600)
    }

    @Test
    func testMergeConsecutiveSegments_largeTextWithin600Limit() {
        // Test that segments up to 600 chars merge correctly with default limit
        let text400 = String(repeating: "a", count: 400)

        let segments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: text400
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_0",
                startMs: 5000,
                endMs: 10000,
                text: "short" // 400 + 1 (space) + 5 = 406 chars, under 600
            )
        ]

        let result = TranscriptRendering.mergeConsecutiveSegments(segments)

        #expect(result.count == 1)
        #expect(result[0].text.count == 406) // 400 + space + 5
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
    func testSpeakerType_noMachineSpeakerId_returnsUnassigned() {
        let segment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil,
            startMs: 0,
            endMs: 5000,
            text: "Hello"
        )
        let tracks: [DetailSpeakerTrack] = []

        let result = TranscriptRendering.speakerType(for: segment, speakerTracks: tracks)

        // Should return unassigned with displayOrder 1 and sky color
        if case let .unassigned(displayOrder, _) = result {
            #expect(displayOrder == 1)
        } else {
            Issue.record("Expected .unassigned but got \(result)")
        }
    }

    @Test
    func testSpeakerType_noMatchingTrack_returnsUnassigned() {
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

        // Should return unassigned with displayOrder 1 (default)
        if case let .unassigned(displayOrder, _) = result {
            #expect(displayOrder == 1)
        } else {
            Issue.record("Expected .unassigned but got \(result)")
        }
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
    func testSpeakerType_trackWithoutPersonName_displayOrder1_returnsUnassigned() {
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

        // Should return unassigned with displayOrder 1 and sky color
        if case let .unassigned(displayOrder, _) = result {
            #expect(displayOrder == 1)
        } else {
            Issue.record("Expected .unassigned but got \(result)")
        }
    }

    @Test
    func testSpeakerType_trackWithoutPersonName_displayOrder2_returnsUnassigned() {
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

        // Should return unassigned with displayOrder 2 and lavender color
        if case let .unassigned(displayOrder, _) = result {
            #expect(displayOrder == 2)
        } else {
            Issue.record("Expected .unassigned but got \(result)")
        }
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

        // Unassigned displayOrder 2 should be .unassigned with displayOrder 2
        if case let .unassigned(displayOrder, _) = result2 {
            #expect(displayOrder == 2)
        } else {
            Issue.record("Expected .unassigned for unassigned speaker but got \(result2)")
        }
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

        // Segment 2: Unassigned (displayOrder 2) at 00:18
        let speaker2 = TranscriptRendering.speakerType(for: segments[1], speakerTracks: tracks)
        let timestamp2 = TranscriptRendering.formatTimestamp(segments[1].startMs)
        if case let .unassigned(displayOrder, _) = speaker2 {
            #expect(displayOrder == 2)
        } else {
            Issue.record("Expected .unassigned for segment 2 but got \(speaker2)")
        }
        #expect(timestamp2 == "00:18")

        // Segment 3: Unassigned (no machine speaker ID, default to displayOrder 1) at 00:35
        let speaker3 = TranscriptRendering.speakerType(for: segments[2], speakerTracks: tracks)
        let timestamp3 = TranscriptRendering.formatTimestamp(segments[2].startMs)
        if case let .unassigned(displayOrder, _) = speaker3 {
            #expect(displayOrder == 1)
        } else {
            Issue.record("Expected .unassigned for segment 3 but got \(speaker3)")
        }
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

    // MARK: - Resolve Segment Speaker Types Tests

    @Test
    func testResolveSegmentSpeakerTypes_emptySegments() {
        let result = TranscriptRendering.resolveSegmentSpeakerTypes([], speakerTracks: [])
        #expect(result.isEmpty)
    }

    @Test
    func testResolveSegmentSpeakerTypes_appliesSpeakerTypesToAllSegments() {
        // This is the key test for the bd-1z6l fix
        // Ensures ALL segments get their speakerType populated based on tracks

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

        // 5 segments: spk_0, spk_1, spk_0, spk_1, spk_0
        // All spk_0 segments should get Alice as speaker type
        // All spk_1 segments should get unassigned displayOrder 2
        let segments = [
            DetailSegment(id: TranscriptSegmentID("seg-1"), machineSpeakerId: "spk_0", startMs: 0, endMs: 5000, text: "First"),
            DetailSegment(id: TranscriptSegmentID("seg-2"), machineSpeakerId: "spk_1", startMs: 5000, endMs: 10000, text: "Second"),
            DetailSegment(id: TranscriptSegmentID("seg-3"), machineSpeakerId: "spk_0", startMs: 10000, endMs: 15000, text: "Third (middle)"),
            DetailSegment(id: TranscriptSegmentID("seg-4"), machineSpeakerId: "spk_1", startMs: 15000, endMs: 20000, text: "Fourth"),
            DetailSegment(id: TranscriptSegmentID("seg-5"), machineSpeakerId: "spk_0", startMs: 20000, endMs: 25000, text: "Fifth (last)"),
        ]

        let result = TranscriptRendering.resolveSegmentSpeakerTypes(segments, speakerTracks: tracks)

        // Verify count preserved
        #expect(result.count == 5)

        // Verify ALL spk_0 segments have Alice as speaker (including middle segment - the bug)
        let aliceSpeakerType = SpeakerType.speaker(name: "Alice", color: SpeakerColor.forIndex(0).color)
        expectNoDifference(result[0].speakerType, aliceSpeakerType)
        expectNoDifference(result[2].speakerType, aliceSpeakerType)
        expectNoDifference(result[4].speakerType, aliceSpeakerType)

        // Verify spk_1 segments are unassigned displayOrder 2
        let unassignedSpeaker2 = SpeakerType.unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color)
        expectNoDifference(result[1].speakerType, unassignedSpeaker2)
        expectNoDifference(result[3].speakerType, unassignedSpeaker2)
    }

    @Test
    func testResolveSegmentSpeakerTypes_preservesOtherFields() {
        let segments = [
            DetailSegment(id: TranscriptSegmentID("seg-1"), machineSpeakerId: "spk_0", startMs: 100, endMs: 500, text: "Original text"),
        ]
        let tracks = [
            DetailSpeakerTrack(id: "track-1", machineSpeakerId: "spk_0", displayOrder: 1, personId: "p1", personName: "Bob")
        ]

        let result = TranscriptRendering.resolveSegmentSpeakerTypes(segments, speakerTracks: tracks)

        #expect(result.count == 1)
        let resolvedSegment = result[0]

        // Verify all original fields are preserved
        #expect(resolvedSegment.id == TranscriptSegmentID("seg-1"))
        #expect(resolvedSegment.machineSpeakerId == "spk_0")
        #expect(resolvedSegment.startMs == 100)
        #expect(resolvedSegment.endMs == 500)
        #expect(resolvedSegment.text == "Original text")

        // And speakerType is set correctly
        if case let .speaker(name, _) = resolvedSegment.speakerType {
            #expect(name == "Bob")
        } else {
            Issue.record("Expected .speaker but got \(resolvedSegment.speakerType)")
        }
    }

    @Test
    func testResolveSegmentSpeakerTypes_noMatchingTrack_defaultsToUnassigned() {
        let segments = [
            DetailSegment(id: TranscriptSegmentID("seg-1"), machineSpeakerId: "unknown_speaker", startMs: 0, endMs: 5000, text: "Text"),
        ]
        let tracks: [DetailSpeakerTrack] = []

        let result = TranscriptRendering.resolveSegmentSpeakerTypes(segments, speakerTracks: tracks)

        #expect(result.count == 1)
        if case let .unassigned(displayOrder, _) = result[0].speakerType {
            #expect(displayOrder == 1, "Should default to displayOrder 1 when no matching track")
        } else {
            Issue.record("Expected .unassigned but got \(result[0].speakerType)")
        }
    }

    // MARK: - bd-2w89: Speaker Diarization Display Order Tests

    @Test
    func testResolveSegmentSpeakerTypes_multipleSpeakers_showCorrectDisplayOrders() {
        // This test specifically validates the bd-2w89 fix:
        // Speaker diarization should show "Speaker 1", "Speaker 2", etc. - not "Speaker 1" for all
        let tracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,  // First speaker detected
                personId: nil,
                personName: nil
            ),
            DetailSpeakerTrack(
                id: "track-2",
                machineSpeakerId: "spk_1",
                displayOrder: 2,  // Second speaker detected
                personId: nil,
                personName: nil
            ),
            DetailSpeakerTrack(
                id: "track-3",
                machineSpeakerId: "spk_2",
                displayOrder: 3,  // Third speaker detected
                personId: nil,
                personName: nil
            )
        ]

        // Simulate a conversation with 3 speakers
        let segments = [
            DetailSegment(id: TranscriptSegmentID("seg-1"), machineSpeakerId: "spk_0", startMs: 0, endMs: 5000, text: "First speaker talking"),
            DetailSegment(id: TranscriptSegmentID("seg-2"), machineSpeakerId: "spk_1", startMs: 5000, endMs: 10000, text: "Second speaker responds"),
            DetailSegment(id: TranscriptSegmentID("seg-3"), machineSpeakerId: "spk_2", startMs: 10000, endMs: 15000, text: "Third speaker joins"),
            DetailSegment(id: TranscriptSegmentID("seg-4"), machineSpeakerId: "spk_0", startMs: 15000, endMs: 20000, text: "First speaker again"),
            DetailSegment(id: TranscriptSegmentID("seg-5"), machineSpeakerId: "spk_1", startMs: 20000, endMs: 25000, text: "Second speaker again"),
        ]

        let result = TranscriptRendering.resolveSegmentSpeakerTypes(segments, speakerTracks: tracks)

        // Verify each segment has the correct speaker display order
        #expect(result.count == 5)

        // seg-1: spk_0 -> Speaker 1
        if case let .unassigned(displayOrder, _) = result[0].speakerType {
            #expect(displayOrder == 1, "spk_0 should be Speaker 1")
        } else {
            Issue.record("Expected .unassigned for seg-1")
        }

        // seg-2: spk_1 -> Speaker 2
        if case let .unassigned(displayOrder, _) = result[1].speakerType {
            #expect(displayOrder == 2, "spk_1 should be Speaker 2")
        } else {
            Issue.record("Expected .unassigned for seg-2")
        }

        // seg-3: spk_2 -> Speaker 3
        if case let .unassigned(displayOrder, _) = result[2].speakerType {
            #expect(displayOrder == 3, "spk_2 should be Speaker 3")
        } else {
            Issue.record("Expected .unassigned for seg-3")
        }

        // seg-4: spk_0 -> Speaker 1 (same speaker returns)
        if case let .unassigned(displayOrder, _) = result[3].speakerType {
            #expect(displayOrder == 1, "spk_0 returning should still be Speaker 1")
        } else {
            Issue.record("Expected .unassigned for seg-4")
        }

        // seg-5: spk_1 -> Speaker 2 (same speaker returns)
        if case let .unassigned(displayOrder, _) = result[4].speakerType {
            #expect(displayOrder == 2, "spk_1 returning should still be Speaker 2")
        } else {
            Issue.record("Expected .unassigned for seg-5")
        }

        // Verify all display labels are unique using the SpeakerType.label property
        let labels = result.map { $0.speakerType.label }
        let expectedLabels = ["Speaker 1", "Speaker 2", "Speaker 3", "Speaker 1", "Speaker 2"]
        #expect(labels == expectedLabels, "Speaker labels should correctly reflect display orders: \(labels)")
    }

    @Test
    func testSpeakerLabel_unassigned_showsCorrectDisplayOrder() {
        // Verify that the SpeakerType.label property shows the correct speaker number
        let speaker1 = SpeakerType.unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
        let speaker2 = SpeakerType.unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color)
        let speaker3 = SpeakerType.unassigned(displayOrder: 3, color: SpeakerColor.forIndex(2).color)

        #expect(speaker1.label == "Speaker 1")
        #expect(speaker2.label == "Speaker 2")
        #expect(speaker3.label == "Speaker 3")
    }
}
