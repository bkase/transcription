import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Status Catalog

extension CatalogBase {
    @Suite("Status Components")
    @MainActor
    struct StatusCatalog {

        // MARK: - Banners

        @Test func testStatusBannerAllVariants() {
            let view = VStack(spacing: 16) {
                StatusBanner(type: .downloadError, onRetry: {})
                StatusBanner(type: .connectionError, onRetry: {})
                StatusBanner(type: .processingError, onRetry: {})
                StatusBanner(type: .downloadError)
            }
            .padding(24).frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "status_banner_all_variants",
                                   section: "Components", description: "All status banner types: download error, connection error, processing error, and no-retry.")
        }

        @Test func testStatusBannerCustom() {
            let view = VStack(spacing: 0) {
                StatusBanner(
                    type: .custom(icon: "exclamationmark.octagon", title: "Storage Full",
                                 description: "Cannot save recording"),
                    onRetry: {}
                )
            }
            .frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "status_banner_custom",
                                   section: "Components", description: "Custom status banner with icon, title, and description.")
        }

        @Test func testStatusBannerInTimeline() {
            let view = VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ARCHIVE").font(.system(size: 11, weight: .light)).tracking(2)
                            .foregroundColor(VaporColor.textTertiary)
                        Text("Timeline").font(.system(size: 28, weight: .ultraLight)).tracking(-0.5)
                            .foregroundColor(VaporColor.textPrimary)
                    }
                    Spacer()
                    Circle().fill(VaporColor.haze).frame(width: 32, height: 32)
                        .overlay(Circle().stroke(VaporColor.fog, lineWidth: 1))
                }
                .padding(.horizontal, 24).padding(.top, 56).padding(.bottom, 16)
                StatusBanner(type: .downloadError, onRetry: {})
                Spacer()
            }
            .frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "status_banner_in_timeline",
                                   section: "Components", description: "Status banner in timeline header context.")
        }

        // MARK: - Pills

        @Test func testStatusPillAllVariants() {
            let view = HStack(spacing: 12) {
                StatusPill(type: .downloading)
                StatusPill(type: .transcribing)
                StatusPill(type: .partial)
                StatusPill(type: .failed)
                StatusPill(type: .ready)
            }
            .padding(24).frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "status_pill_all_variants",
                                   section: "Components", description: "All status pill types side by side.")
        }

        @Test func testStatusPillIndividual() {
            let view = VStack(spacing: 16) {
                HStack(spacing: 8) { CaptionText("Downloading"); StatusPill(type: .downloading) }
                HStack(spacing: 8) { CaptionText("Transcribing"); StatusPill(type: .transcribing) }
                HStack(spacing: 8) { CaptionText("Partial"); StatusPill(type: .partial) }
                HStack(spacing: 8) { CaptionText("Failed"); StatusPill(type: .failed) }
                HStack(spacing: 8) { CaptionText("Ready"); StatusPill(type: .ready) }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "status_pill_individual",
                                   section: "Components", description: "Each status pill type with label.")
        }

        // MARK: - Error States

        @Test func testErrorStateTranscriptionFailed() {
            let view = VStack {
                Spacer()
                ErrorStateView(
                    type: .transcriptionFailed,
                    primaryLabel: "Retry Processing", primaryAction: {},
                    secondaryLabel: "Save Without Transcript", secondaryAction: {}
                )
                Spacer()
            }
            .frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "error_state_transcription_failed",
                                   section: "Components", description: "Transcription failed error with retry and save options.")
        }

        @Test func testErrorStateTranscriptionUnavailable() {
            let view = VStack {
                Spacer()
                ErrorStateView(type: .transcriptionUnavailable,
                               primaryLabel: "Retry Transcription", primaryAction: {})
                Spacer()
            }
            .frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "error_state_transcription_unavailable",
                                   section: "Components", description: "Transcription unavailable error with retry option.")
        }

        @Test func testErrorStateCustom() {
            let view = VStack {
                Spacer()
                ErrorStateView(
                    type: .custom(icon: "exclamationmark.triangle", title: "Audio Not Found",
                                 description: "The original audio file could not be located."),
                    primaryLabel: "Browse Files", primaryAction: {}
                )
                Spacer()
            }
            .frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "error_state_custom",
                                   section: "Components", description: "Custom error state with icon, title, and action.")
        }

        @Test func testErrorStateNoButtons() {
            let view = VStack {
                Spacer()
                ErrorStateView(type: .processingFailed)
                Spacer()
            }
            .frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "error_state_no_buttons",
                                   section: "Components", description: "Processing failed error with no action buttons.")
        }

        // MARK: - Processing Indicators

        @Test func testProcessingStatusAllVariants() {
            let view = VStack(alignment: .leading, spacing: 16) {
                ProcessingStatusIndicator(status: .recording)
                ProcessingStatusIndicator(status: .processing)
                ProcessingStatusIndicator(status: .processingFailed)
                ProcessingStatusIndicator(status: .partial)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "processing_status_all_variants",
                                   section: "Components", description: "All processing status indicator states.")
        }

        @Test func testStatusPillInSessionCard() {
            let view = VStack(spacing: 8) {
                Text("Conversations are like breath\u{2014}ephemeral unless captured.")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    StatusPill(type: .partial)
                    Spacer()
                    Text("2:30").font(.system(size: 11, weight: .light)).foregroundColor(VaporColor.textSecondary)
                }
            }
            .padding(20).background(Color.white.opacity(0.5)).cornerRadius(12)
            .padding(24).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "status_pill_in_session_card",
                                   section: "Components", description: "Status pill integrated in a session card preview.")
        }
    }
}
