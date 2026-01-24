import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Recording Header Snapshot Tests

@Suite("Recording Header Component Snapshots")
@MainActor
struct RecordingHeaderSnapshotTests {

    @Test func testRecordingHeader() {
        let view = VStack(alignment: .leading, spacing: 32) {
            // Short time
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Just Started")
                RecordingHeaderPreview(elapsedTime: "00:02")
            }

            // Few minutes
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Few Minutes In")
                RecordingHeaderPreview(elapsedTime: "05:32")
            }

            // Longer duration
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Longer Recording")
                RecordingHeaderPreview(elapsedTime: "32:15")
            }

            // Hour+ recording
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Extended Session")
                RecordingHeaderPreview(elapsedTime: "1:23:45")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "recording_header")
    }

    @Test func testRecordingHeaderInContext() {
        // Recording header at top of a mock recording screen
        let view = VStack(spacing: 0) {
            RecordingHeaderPreview(elapsedTime: "00:42")

            // Mock content area with live transcript
            VStack(alignment: .leading, spacing: 16) {
                Text("YOU")
                    .font(.system(size: 11, weight: .light))
                    .tracking(1)
                    .foregroundColor(VaporColor.sky)

                BodyText("So we're looking at the Vapor direction...")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(height: 300)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "recording_header_in_context")
    }
}
