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
}
