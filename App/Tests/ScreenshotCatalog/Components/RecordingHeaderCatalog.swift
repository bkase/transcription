import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Recording Header Catalog

extension CatalogBase {
    @Suite("Recording Header Components")
    @MainActor
    struct RecordingHeaderCatalog {

        @Test func testRecordingHeaderDurations() {
            let view = VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Just Started")
                    RecordingHeaderPreview(elapsedTime: "00:02")
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Few Minutes In")
                    RecordingHeaderPreview(elapsedTime: "05:32")
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Longer Recording")
                    RecordingHeaderPreview(elapsedTime: "32:15")
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Extended Session")
                    RecordingHeaderPreview(elapsedTime: "1:23:45")
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "recording_header_durations",
                                   section: "Components", description: "Recording header at various elapsed times.")
        }

        @Test func testRecordingHeaderInContext() {
            let view = VStack(spacing: 0) {
                RecordingHeaderPreview(elapsedTime: "00:42")
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOU").font(.system(size: 11, weight: .light)).tracking(1).foregroundColor(VaporColor.sky)
                    BodyText("So we're looking at the Vapor direction...")
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .frame(height: 300).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "recording_header_in_context",
                                   section: "Components", description: "Recording header at top of a mock recording screen.")
        }
    }
}
