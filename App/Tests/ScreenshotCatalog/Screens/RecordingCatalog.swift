import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import RecordingFeature

// MARK: - Recording Catalog

extension CatalogBase {
    @Suite("Recording")
    @MainActor
    struct RecordingCatalog {

        @Test func testRecordingStarting() {
            let view = RecordingViewPreview(
                elapsedTime: "00:00", isRecording: true, contentState: .starting
            )
            CatalogHarness.capture(of: view, named: "recording_starting",
                                   section: "Recording", description: "Recording initiated, not yet listening.")
        }

        @Test func testRecordingListening() {
            let view = RecordingViewPreview(
                elapsedTime: "00:02", isRecording: true, contentState: .listening
            )
            CatalogHarness.capture(of: view, named: "recording_listening",
                                   section: "Recording", description: "Actively listening for speech.")
        }

        @Test func testRecordingPaused() {
            let view = RecordingViewPreview(
                elapsedTime: "01:23", isRecording: true, isPaused: true, contentState: .paused
            )
            CatalogHarness.capture(of: view, named: "recording_paused",
                                   section: "Recording", description: "Recording paused by user.")
        }

        @Test func testRecordingError() {
            let view = RecordingViewPreview(
                elapsedTime: "00:00", isRecording: false,
                contentState: .error("Microphone access denied")
            )
            CatalogHarness.capture(of: view, named: "recording_error",
                                   section: "Recording", description: "Recording error state.")
        }

        @Test func testRecordingPermissionDenied() {
            let view = RecordingViewPreview(
                elapsedTime: "00:00", isRecording: false,
                contentState: .permissionDenied("Microphone access is required to record. Please enable it in Settings.")
            )
            CatalogHarness.capture(of: view, named: "recording_permission_denied",
                                   section: "Recording", description: "Microphone permission denied.")
        }

        @Test func testRecordingLiveSegmentsUnassigned() {
            let segments: [LiveSegmentData] = [
                LiveSegmentData(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:02",
                    text: "Conversations are like breath\u{2014}ephemeral unless captured."
                ),
                LiveSegmentData(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:04",
                    text: "The Vapor brand treats speech as something delicate."
                ),
                LiveSegmentData(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:06",
                    text: "It preserves without intruding. It's barely there."
                )
            ]
            let view = RecordingViewPreview(
                elapsedTime: "00:06", isRecording: true, contentState: .liveSegments(segments)
            )
            CatalogHarness.capture(of: view, named: "recording_live_segments_unassigned",
                                   section: "Recording", description: "Live transcript with unassigned speakers.")
        }

        @Test func testRecordingLiveSegmentsNamed() {
            let segments: [LiveSegmentData] = [
                LiveSegmentData(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "00:02",
                    text: "Let's review the design decisions we made yesterday."
                ),
                LiveSegmentData(
                    speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                    timestamp: "00:08",
                    text: "Sure. I think the vapor aesthetic is working well."
                ),
                LiveSegmentData(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "00:15",
                    text: "The transcript formatting looks clean."
                )
            ]
            let view = RecordingViewPreview(
                elapsedTime: "00:15", isRecording: true, contentState: .liveSegments(segments)
            )
            CatalogHarness.capture(of: view, named: "recording_live_segments_named",
                                   section: "Recording", description: "Live transcript with named speakers.")
        }

        @Test func testRecordingTranscriptionUnavailable() {
            let view = RecordingViewPreview(
                elapsedTime: "00:15", isRecording: true,
                contentState: .transcriptionUnavailable(message: "Transcription will run when recording stops")
            )
            CatalogHarness.capture(of: view, named: "recording_transcription_unavailable",
                                   section: "Recording", description: "Transcription unavailable with default message.")
        }

        @Test func testRecordingTranscriptionUnavailableCustom() {
            let view = RecordingViewPreview(
                elapsedTime: "00:30", isRecording: true,
                contentState: .transcriptionUnavailable(message: "Models failed to load. Offline transcription will be attempted.")
            )
            CatalogHarness.capture(of: view, named: "recording_transcription_unavailable_custom",
                                   section: "Recording", description: "Transcription unavailable with custom error message.")
        }

        @Test func testRecordingProcessingError() {
            let segments: [LiveSegmentData] = [
                LiveSegmentData(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:02",
                    text: "Conversations are like breath\u{2014}ephemeral unless captured."
                ),
                LiveSegmentData(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:04",
                    text: "The Vapor brand treats speech as something delicate."
                )
            ]
            let view = RecordingViewPreview(
                elapsedTime: "01:24", isRecording: false,
                contentState: .processingError(segments: segments)
            )
            CatalogHarness.capture(of: view, named: "recording_processing_error",
                                   section: "Recording", description: "Processing error with partial segments.")
        }
    }
}
