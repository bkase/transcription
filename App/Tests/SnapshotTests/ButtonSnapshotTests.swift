import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Button Snapshot Tests

@Suite("Button Component Snapshots", .snapshots(record: SnapshotConfig.recordMode))
@MainActor
struct ButtonSnapshotTests {

    @Test func testRecordButtonStates() {
        let view = VStack(spacing: 32) {
            // Idle state
            VStack(spacing: 8) {
                CaptionText("Idle")
                RecordButton(isRecording: false) {}
            }

            // Recording state (static, no animation for snapshot)
            VStack(spacing: 8) {
                CaptionText("Recording")
                RecordButton(isRecording: true) {}
            }

            // Large recording state
            VStack(spacing: 8) {
                CaptionText("Recording (Large)")
                RecordButton(isRecording: true, size: .large) {}
            }

            // Disabled state
            VStack(spacing: 8) {
                CaptionText("Disabled")
                RecordButton(isRecording: false, isEnabled: false) {}
            }

            // Disabled large state
            VStack(spacing: 8) {
                CaptionText("Disabled (Large)")
                RecordButton(isRecording: false, isEnabled: false, size: .large) {}
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "record_button_states")
    }

    @Test func testIconButtonStates() {
        let view = VStack(spacing: 24) {
            // Transparent style (default)
            VStack(spacing: 8) {
                CaptionText("Transparent")
                HStack(spacing: 16) {
                    IconButton(systemName: "pause") {}
                    IconButton(systemName: "play.fill") {}
                    IconButton(systemName: "mic") {}
                }
            }

            // Filled style (hover/active state)
            VStack(spacing: 8) {
                CaptionText("Filled")
                HStack(spacing: 16) {
                    IconButton(systemName: "ellipsis", style: .filled, iconColor: VaporColor.textSecondary) {}
                    IconButton(systemName: "square.and.arrow.up", style: .filled, iconColor: VaporColor.textSecondary) {}
                    IconButton(systemName: "trash", style: .filled, iconColor: VaporColor.recording) {}
                }
            }

            // Different icon colors
            VStack(spacing: 8) {
                CaptionText("Icon Colors")
                HStack(spacing: 16) {
                    IconButton(systemName: "pause", iconColor: VaporColor.sky) {}
                    IconButton(systemName: "pause", iconColor: VaporColor.deep) {}
                    IconButton(systemName: "pause", iconColor: VaporColor.textSecondary) {}
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "icon_button_states")
    }

    @Test func testNavButton() {
        let view = VStack(alignment: .leading, spacing: 24) {
            // Default back button
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Default")
                NavButton(label: "Back") {}
            }

            // Custom label
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Custom Label")
                NavButton(label: "Sessions") {}
            }

            // In context (simulating header)
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("In Header Context")
                HStack {
                    NavButton(label: "Back") {}
                    Spacer()
                    Circle()
                        .fill(VaporColor.haze)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "nav_button")
    }

    @Test func testButtonsInContext() {
        // Test buttons in a realistic recording controls layout
        let view = VStack(spacing: 0) {
            Spacer()

            // Recording controls bar
            HStack {
                IconButton(systemName: "pause", iconColor: VaporColor.sky) {}

                Spacer()

                RecordButton(isRecording: true, size: .large) {}

                Spacer()

                IconButton(systemName: "ellipsis", style: .filled, iconColor: VaporColor.textSecondary) {}
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .frame(height: 200)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [VaporColor.mist.opacity(0), VaporColor.mist]),
                startPoint: .top,
                endPoint: .bottom
            )
        )

        SnapshotHarness.assertSnapshot(of: view, named: "buttons_in_context")
    }

    @Test func testRecordButtonSizes() {
        let view = HStack(spacing: 32) {
            VStack(spacing: 8) {
                CaptionText("Regular (72pt)")
                RecordButton(isRecording: false) {}
            }

            VStack(spacing: 8) {
                CaptionText("Large (112pt)")
                RecordButton(isRecording: false, size: .large) {}
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "record_button_sizes")
    }

    @Test func testRecordButtonDisabled() {
        let view = HStack(spacing: 32) {
            VStack(spacing: 8) {
                CaptionText("Disabled Regular")
                RecordButton(isRecording: false, isEnabled: false) {}
            }

            VStack(spacing: 8) {
                CaptionText("Disabled Large")
                RecordButton(isRecording: false, isEnabled: false, size: .large) {}
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "record_button_disabled")
    }
}
