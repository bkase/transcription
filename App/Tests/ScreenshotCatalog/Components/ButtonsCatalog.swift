import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Buttons Catalog

extension CatalogBase {
    @Suite("Button Components")
    @MainActor
    struct ButtonsCatalog {

        @Test func testRecordButtonStates() {
            let view = VStack(spacing: 32) {
                VStack(spacing: 8) { CaptionText("Idle"); RecordButton(isRecording: false) {} }
                VStack(spacing: 8) { CaptionText("Recording"); RecordButton(isRecording: true) {} }
                VStack(spacing: 8) { CaptionText("Recording (Large)"); RecordButton(isRecording: true, size: .large) {} }
                VStack(spacing: 8) { CaptionText("Disabled"); RecordButton(isRecording: false, isEnabled: false) {} }
                VStack(spacing: 8) { CaptionText("Disabled (Large)"); RecordButton(isRecording: false, isEnabled: false, size: .large) {} }
            }
            .padding(32).frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "record_button_states",
                                   section: "Components", description: "Record button in idle, recording, and disabled states at both sizes.")
        }

        @Test func testRecordButtonSizes() {
            let view = HStack(spacing: 32) {
                VStack(spacing: 8) { CaptionText("Regular (72pt)"); RecordButton(isRecording: false) {} }
                VStack(spacing: 8) { CaptionText("Large (112pt)"); RecordButton(isRecording: false, size: .large) {} }
            }
            .padding(32).frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "record_button_sizes",
                                   section: "Components", description: "Record button size comparison.")
        }

        @Test func testIconButtonStyles() {
            let view = VStack(spacing: 24) {
                VStack(spacing: 8) {
                    CaptionText("Transparent")
                    HStack(spacing: 16) {
                        IconButton(systemName: "pause") {}
                        IconButton(systemName: "play.fill") {}
                        IconButton(systemName: "mic") {}
                    }
                }
                VStack(spacing: 8) {
                    CaptionText("Filled")
                    HStack(spacing: 16) {
                        IconButton(systemName: "ellipsis", style: .filled, iconColor: VaporColor.textSecondary) {}
                        IconButton(systemName: "square.and.arrow.up", style: .filled, iconColor: VaporColor.textSecondary) {}
                        IconButton(systemName: "trash", style: .filled, iconColor: VaporColor.recording) {}
                    }
                }
                VStack(spacing: 8) {
                    CaptionText("Icon Colors")
                    HStack(spacing: 16) {
                        IconButton(systemName: "pause", iconColor: VaporColor.sky) {}
                        IconButton(systemName: "pause", iconColor: VaporColor.deep) {}
                        IconButton(systemName: "pause", iconColor: VaporColor.textSecondary) {}
                    }
                }
            }
            .padding(32).frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "icon_button_styles",
                                   section: "Components", description: "Icon buttons: transparent, filled, and color variants.")
        }

        @Test func testNavButton() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Default")
                    NavButton(label: "Back") {}
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Custom Label")
                    NavButton(label: "Sessions") {}
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("In Header Context")
                    HStack {
                        NavButton(label: "Back") {}
                        Spacer()
                        Circle().fill(VaporColor.haze).frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(32).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "nav_button",
                                   section: "Components", description: "Navigation back button variants.")
        }

        @Test func testButtonsInContext() {
            let view = VStack(spacing: 0) {
                Spacer()
                HStack {
                    IconButton(systemName: "pause", iconColor: VaporColor.sky) {}
                    Spacer()
                    RecordButton(isRecording: true, size: .large) {}
                    Spacer()
                    IconButton(systemName: "ellipsis", style: .filled, iconColor: VaporColor.textSecondary) {}
                }
                .padding(.horizontal, 40).padding(.bottom, 60)
            }
            .frame(height: 200)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [VaporColor.mist.opacity(0), VaporColor.mist]),
                    startPoint: .top, endPoint: .bottom
                )
            )

            CatalogHarness.capture(of: view, named: "buttons_in_context",
                                   section: "Components", description: "Recording controls bar layout.")
        }

        @Test func testRecordButtonDisabled() {
            let view = HStack(spacing: 32) {
                VStack(spacing: 8) { CaptionText("Disabled Regular"); RecordButton(isRecording: false, isEnabled: false) {} }
                VStack(spacing: 8) { CaptionText("Disabled Large"); RecordButton(isRecording: false, isEnabled: false, size: .large) {} }
            }
            .padding(32).frame(maxWidth: .infinity).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "record_button_disabled",
                                   section: "Components", description: "Disabled record buttons at both sizes.")
        }
    }
}
