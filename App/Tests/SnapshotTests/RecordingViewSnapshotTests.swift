import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import RecordingFeature

// MARK: - Recording View Snapshot Tests

@Suite("Recording View Snapshots")
@MainActor
struct RecordingViewSnapshotTests {

    @Test func testListeningState() {
        // Listening state: recording active, microphone listening
        let view = RecordingViewPreview(
            elapsedTime: "00:02",
            isRecording: true,
            contentState: .listening
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_listening_state")
    }

    @Test func testStartingState() {
        // Starting state: recording initiated but not yet listening
        let view = RecordingViewPreview(
            elapsedTime: "00:00",
            isRecording: true,
            contentState: .starting
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_starting_state")
    }

    @Test func testErrorState() {
        // Error state: recording failed
        let view = RecordingViewPreview(
            elapsedTime: "00:00",
            isRecording: false,
            contentState: .error("Microphone access denied")
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_error_state")
    }

    @Test func testLiveSegmentsState() {
        // Live segments state: recording with live transcript (speakers unset)
        let segments: [LiveSegmentData] = [
            LiveSegmentData(
                speaker: .user,
                timestamp: "00:02",
                text: "Conversations are like breath—ephemeral unless captured."
            ),
            LiveSegmentData(
                speaker: .guest,
                timestamp: "00:04",
                text: "The Vapor brand treats speech as something delicate."
            ),
            LiveSegmentData(
                speaker: .user,
                timestamp: "00:06",
                text: "It preserves without intruding. It's barely there."
            )
        ]

        let view = RecordingViewPreview(
            elapsedTime: "00:06",
            isRecording: true,
            contentState: .liveSegments(segments)
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_live_segments_state")
    }
}
