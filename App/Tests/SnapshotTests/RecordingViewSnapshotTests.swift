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

    @Test func testPausedState() {
        // Paused state: recording paused by user
        let view = RecordingViewPreview(
            elapsedTime: "01:23",
            isRecording: true,
            isPaused: true,
            contentState: .paused
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_paused_state")
    }

    @Test func testPermissionDeniedState() {
        // Permission denied state: microphone access not granted
        let view = RecordingViewPreview(
            elapsedTime: "00:00",
            isRecording: false,
            contentState: .permissionDenied("Microphone access is required to record. Please enable it in Settings.")
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_permission_denied_state")
    }

    @Test func testTranscriptionUnavailableState() {
        // Transcription unavailable: recording audio but live transcription failed
        let view = RecordingViewPreview(
            elapsedTime: "00:15",
            isRecording: true,
            contentState: .transcriptionUnavailable(message: "Transcription will run when recording stops")
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_transcription_unavailable_state")
    }

    @Test func testTranscriptionUnavailableWithCustomMessage() {
        // Transcription unavailable with custom error message
        let view = RecordingViewPreview(
            elapsedTime: "00:30",
            isRecording: true,
            contentState: .transcriptionUnavailable(message: "Models failed to load. Offline transcription will be attempted.")
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_transcription_unavailable_custom")
    }

    @Test func testProcessingErrorState() {
        // Processing error: recording finished but transcription failed
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
            )
        ]

        let view = RecordingViewPreview(
            elapsedTime: "01:24",
            isRecording: false,
            contentState: .processingError(segments: segments)
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_processing_error_state")
    }

    @Test func testProcessingErrorWithNoSegments() {
        // Processing error with no live segments captured
        let view = RecordingViewPreview(
            elapsedTime: "00:45",
            isRecording: false,
            contentState: .processingError(segments: [])
        )

        SnapshotHarness.assertSnapshot(of: view, named: "recording_processing_error_no_segments")
    }
}
