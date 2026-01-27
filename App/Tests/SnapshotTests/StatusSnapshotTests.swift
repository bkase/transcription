import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Status Component Snapshot Tests

@Suite("Status Component Snapshots")
@MainActor
struct StatusSnapshotTests {

    // MARK: - Status Banner Tests

    @Test func testStatusBannerDownloadError() {
        let view = VStack(spacing: 0) {
            StatusBanner(type: .downloadError, onRetry: {})
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_banner_download_error")
    }

    @Test func testStatusBannerConnectionError() {
        let view = VStack(spacing: 0) {
            StatusBanner(type: .connectionError, onRetry: {})
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_banner_connection_error")
    }

    @Test func testStatusBannerProcessingError() {
        let view = VStack(spacing: 0) {
            StatusBanner(type: .processingError, onRetry: {})
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_banner_processing_error")
    }

    @Test func testStatusBannerNoRetryButton() {
        let view = VStack(spacing: 0) {
            StatusBanner(type: .downloadError)
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_banner_no_retry")
    }

    @Test func testStatusBannerCustom() {
        let view = VStack(spacing: 0) {
            StatusBanner(
                type: .custom(
                    icon: "exclamationmark.octagon",
                    title: "Storage Full",
                    description: "Cannot save recording"
                ),
                onRetry: {}
            )
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_banner_custom")
    }

    @Test func testStatusBannerAllVariants() {
        let view = VStack(spacing: 16) {
            StatusBanner(type: .downloadError, onRetry: {})
            StatusBanner(type: .connectionError, onRetry: {})
            StatusBanner(type: .processingError, onRetry: {})
            StatusBanner(type: .downloadError)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_banner_all_variants")
    }

    // MARK: - Status Pill Tests

    @Test func testStatusPillDownloading() {
        let view = VStack(spacing: 16) {
            StatusPill(type: .downloading)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_pill_downloading")
    }

    @Test func testStatusPillTranscribing() {
        let view = VStack(spacing: 16) {
            StatusPill(type: .transcribing)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_pill_transcribing")
    }

    @Test func testStatusPillPartial() {
        let view = VStack(spacing: 16) {
            StatusPill(type: .partial)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_pill_partial")
    }

    @Test func testStatusPillFailed() {
        let view = VStack(spacing: 16) {
            StatusPill(type: .failed)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_pill_failed")
    }

    @Test func testStatusPillReady() {
        let view = VStack(spacing: 16) {
            StatusPill(type: .ready)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_pill_ready")
    }

    @Test func testStatusPillAllVariants() {
        let view = HStack(spacing: 12) {
            StatusPill(type: .downloading)
            StatusPill(type: .transcribing)
            StatusPill(type: .partial)
            StatusPill(type: .failed)
            StatusPill(type: .ready)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_pill_all_variants")
    }

    // MARK: - Error State View Tests

    @Test func testErrorStateTranscriptionFailed() {
        let view = VStack {
            Spacer()
            ErrorStateView(
                type: .transcriptionFailed,
                primaryLabel: "Retry Processing",
                primaryAction: {},
                secondaryLabel: "Save Without Transcript",
                secondaryAction: {}
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "error_state_transcription_failed")
    }

    @Test func testErrorStateTranscriptionUnavailable() {
        let view = VStack {
            Spacer()
            ErrorStateView(
                type: .transcriptionUnavailable,
                primaryLabel: "Retry Transcription",
                primaryAction: {}
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "error_state_transcription_unavailable")
    }

    @Test func testErrorStateProcessingFailed() {
        let view = VStack {
            Spacer()
            ErrorStateView(type: .processingFailed)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "error_state_processing_failed")
    }

    @Test func testErrorStateCustom() {
        let view = VStack {
            Spacer()
            ErrorStateView(
                type: .custom(
                    icon: "exclamationmark.triangle",
                    title: "Audio Not Found",
                    description: "The original audio file could not be located. It may have been moved or deleted."
                ),
                primaryLabel: "Browse Files",
                primaryAction: {}
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "error_state_custom")
    }

    @Test func testErrorStateNoButtons() {
        let view = VStack {
            Spacer()
            ErrorStateView(type: .processingFailed)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "error_state_no_buttons")
    }

    // MARK: - Processing Status Indicator Tests

    @Test func testProcessingStatusIndicatorRecording() {
        let view = VStack(spacing: 16) {
            ProcessingStatusIndicator(status: .recording)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "processing_status_recording")
    }

    @Test func testProcessingStatusIndicatorProcessing() {
        let view = VStack(spacing: 16) {
            ProcessingStatusIndicator(status: .processing)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "processing_status_processing")
    }

    @Test func testProcessingStatusIndicatorFailed() {
        let view = VStack(spacing: 16) {
            ProcessingStatusIndicator(status: .processingFailed)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "processing_status_failed")
    }

    @Test func testProcessingStatusIndicatorPartial() {
        let view = VStack(spacing: 16) {
            ProcessingStatusIndicator(status: .partial)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "processing_status_partial")
    }

    @Test func testProcessingStatusIndicatorAllVariants() {
        let view = VStack(alignment: .leading, spacing: 16) {
            ProcessingStatusIndicator(status: .recording)
            ProcessingStatusIndicator(status: .processing)
            ProcessingStatusIndicator(status: .processingFailed)
            ProcessingStatusIndicator(status: .partial)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "processing_status_all_variants")
    }

    // MARK: - In Context Tests

    @Test func testStatusBannerInTimelineContext() {
        // Simulate banner appearing at top of timeline
        let view = VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ARCHIVE")
                        .font(.system(size: 11, weight: .light))
                        .tracking(2)
                        .foregroundColor(VaporColor.textTertiary)
                    Text("Timeline")
                        .font(.system(size: 28, weight: .ultraLight))
                        .tracking(-0.5)
                        .foregroundColor(VaporColor.textPrimary)
                }
                Spacer()
                Circle()
                    .fill(VaporColor.haze)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(VaporColor.fog, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 16)

            // Error banner
            StatusBanner(type: .downloadError, onRetry: {})

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_banner_in_timeline")
    }

    @Test func testStatusPillInSessionCard() {
        // Simulate pill appearing in session card
        let view = VStack(spacing: 8) {
            // Session preview text
            Text("Conversations are like breath\u{2014}ephemeral unless captured.")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(VaporColor.textPrimary)
                .lineLimit(2)

            // Badges row with status pill
            HStack(spacing: 8) {
                StatusPill(type: .partial)
                Spacer()
                Text("2:30")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.5))
        .cornerRadius(12)
        .padding(24)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "status_pill_in_session_card")
    }
}
