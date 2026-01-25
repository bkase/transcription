import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import RecordingFeature
@testable import SessionDetailFeature

// MARK: - Speaker Label Integration Snapshot Tests

/// Tests that verify speaker labels are properly wired in transcript views.
/// These tests ensure the integration between speaker track data and the
/// visual representation of speakers in both recording and session detail contexts.
@Suite("Speaker Label Integration Snapshots")
@MainActor
struct SpeakerLabelIntegrationSnapshotTests {

    // MARK: - testSpeakerLabelsInTranscript

    /// Tests that transcript segments display correct speaker labels based on
    /// speaker track data and person assignments.
    @Test func testSpeakerLabelsInTranscript() {
        // Test transcript with mixed speaker types:
        // - User (displayOrder 1, no personName)
        // - Guest (displayOrder 2, no personName)
        // - Named speaker with assigned person
        let segments: [LiveSegmentData] = [
            LiveSegmentData(
                speaker: .user,
                timestamp: "00:02",
                text: "Let's review the design decisions we made yesterday."
            ),
            LiveSegmentData(
                speaker: .guest,
                timestamp: "00:08",
                text: "Sure. I think the vapor aesthetic is working well."
            ),
            LiveSegmentData(
                speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                timestamp: "00:15",
                text: "The transcript formatting looks clean. I like the script-like feel."
            ),
            LiveSegmentData(
                speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                timestamp: "00:22",
                text: "Agreed. The speaker labels are subtle but clear."
            )
        ]

        let view = RecordingViewPreview(
            elapsedTime: "00:22",
            isRecording: true,
            contentState: .liveSegments(segments)
        )

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_labels_in_transcript")
    }

    // MARK: - testUnassignedSpeakersInRecording

    /// Tests that unassigned speakers (without person names) display correctly
    /// using the default user/guest labels based on display order.
    @Test func testUnassignedSpeakersInRecording() {
        // All speakers are unassigned (no personName)
        // displayOrder 1 -> user
        // displayOrder > 1 -> guest
        let segments: [LiveSegmentData] = [
            LiveSegmentData(
                speaker: .user,
                timestamp: "00:00",
                text: "This is the primary speaker, shown as YOU."
            ),
            LiveSegmentData(
                speaker: .guest,
                timestamp: "00:05",
                text: "This is a secondary speaker, shown as GUEST."
            ),
            LiveSegmentData(
                speaker: .user,
                timestamp: "00:10",
                text: "Back to the primary speaker."
            ),
            LiveSegmentData(
                speaker: .guest,
                timestamp: "00:15",
                text: "And the guest responds."
            )
        ]

        let view = RecordingViewPreview(
            elapsedTime: "00:15",
            isRecording: true,
            contentState: .liveSegments(segments)
        )

        SnapshotHarness.assertSnapshot(of: view, named: "unassigned_speakers_recording")
    }

    // MARK: - testNamedSpeakersInSessionDetail

    /// Tests that named speakers in session detail view display with their
    /// assigned names and colors.
    @Test func testNamedSpeakersInSessionDetail() {
        let segments: [SessionDetailViewPreview.SegmentData] = [
            .init(
                speaker: .speaker(name: "Emily", color: VaporColor.sky),
                timestamp: "00:00",
                text: "Welcome to today's planning session."
            ),
            .init(
                speaker: .speaker(name: "Jake", color: VaporColor.lavender),
                timestamp: "00:12",
                text: "Thanks Emily. Let's start with the roadmap."
            ),
            .init(
                speaker: .speaker(name: "Emily", color: VaporColor.sky),
                timestamp: "00:25",
                text: "I've prepared a few slides on our Q2 priorities."
            ),
            .init(
                speaker: .speaker(name: "Riley", color: VaporColor.deep),
                timestamp: "00:38",
                text: "Quick question - are we including the mobile app in this quarter?"
            ),
            .init(
                speaker: .speaker(name: "Emily", color: VaporColor.sky),
                timestamp: "00:52",
                text: "Yes, mobile is a key priority. Jake will share more details."
            )
        ]

        let view = SessionDetailViewPreview(
            title: "Q2 Planning",
            time: "10:30 AM",
            duration: "45:18",
            segments: segments,
            audioProgress: 0.2,
            audioTime: "9:03",
            isPlaying: false
        )

        SnapshotHarness.assertSnapshot(of: view, named: "named_speakers_session_detail")
    }

    // MARK: - testSpeakerColorCycling

    /// Tests that speaker colors cycle correctly when there are more than 4 speakers.
    @Test func testSpeakerColorCycling() {
        // Create segments with 5 different speakers to test color cycling
        let segments: [SessionDetailViewPreview.SegmentData] = [
            .init(
                speaker: .speaker(name: "Speaker 1", color: SpeakerColor.forIndex(0).color),
                timestamp: "00:00",
                text: "First speaker - should be sky color."
            ),
            .init(
                speaker: .speaker(name: "Speaker 2", color: SpeakerColor.forIndex(1).color),
                timestamp: "00:10",
                text: "Second speaker - should be lavender color."
            ),
            .init(
                speaker: .speaker(name: "Speaker 3", color: SpeakerColor.forIndex(2).color),
                timestamp: "00:20",
                text: "Third speaker - should be deep color."
            ),
            .init(
                speaker: .speaker(name: "Speaker 4", color: SpeakerColor.forIndex(3).color),
                timestamp: "00:30",
                text: "Fourth speaker - should be dusk color."
            ),
            .init(
                speaker: .speaker(name: "Speaker 5", color: SpeakerColor.forIndex(4).color),
                timestamp: "00:40",
                text: "Fifth speaker - should cycle back to sky color."
            )
        ]

        let view = SessionDetailViewPreview(
            title: "Team Meeting",
            time: "2:00 PM",
            duration: "10:00",
            segments: segments,
            audioProgress: 0.5,
            audioTime: "5:00",
            isPlaying: false
        )

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_color_cycling")
    }
}
