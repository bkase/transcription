import Testing
import Foundation
import DesignSystem
import Models
@testable import SessionDetailFeature

@MainActor
struct TranscriptRenderingTests {

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
                machineSpeakerId: "spk_0",
                displayOrder: 1,
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
                machineSpeakerId: "spk_0",
                displayOrder: 1,
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
                machineSpeakerId: "spk_0",
                displayOrder: 1,
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
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: nil
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_1",
                displayOrder: 2,
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
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: "Alice"
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_1",
                displayOrder: 2,
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
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: "Speaker1"  // Should get color at index 0 (sky)
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personName: "Speaker2"  // Should get color at index 1 (lavender)
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_2",
                displayOrder: 3,
                personName: "Speaker3"  // Should get color at index 2 (deep)
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_3",
                displayOrder: 4,
                personName: "Speaker4"  // Should get color at index 3 (dusk)
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_4",
                displayOrder: 5,
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
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: "Alice"
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_1",
                displayOrder: 2,
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
