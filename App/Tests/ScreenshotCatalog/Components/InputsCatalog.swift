import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Inputs Catalog

extension CatalogBase {
    @Suite("Input Components")
    @MainActor
    struct InputsCatalog {

        @Test func testSearchFieldStates() {
            let view = VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Idle State")
                    SearchFieldPreview()
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Focused State")
                    SearchFieldPreview(text: "morning ref", isFocused: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Custom Placeholder")
                    SearchFieldPreview(placeholder: "Search people...")
                }
            }
            .padding(32).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "search_field_states",
                                   section: "Components", description: "Search field: idle, focused with text, and custom placeholder.")
        }

        @Test func testSearchFieldInContext() {
            let view = VStack(spacing: 0) {
                HStack(alignment: .top) {
                    PageHeader(kicker: "Archive", title: "Timeline")
                    Spacer()
                    Avatar(initials: "JD", size: .medium)
                }
                .padding(.horizontal, 24).padding(.top, 24)
                SearchFieldPreview()
                    .padding(.horizontal, 24).padding(.top, 16)
                Spacer()
            }
            .frame(height: 200).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "search_field_in_context",
                                   section: "Components", description: "Search field below timeline header.")
        }

        @Test func testFocusBlurEffect() {
            let cardContent = HStack {
                Circle().fill(VaporColor.sky).frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Title").font(.system(size: 14, weight: .medium)).foregroundColor(VaporColor.textPrimary)
                    Text("Preview text content here...").font(.system(size: 12, weight: .light)).foregroundColor(VaporColor.textSecondary)
                }
                Spacer()
            }
            .padding().background(VaporColor.cloud).cornerRadius(12)

            let view = VStack(spacing: 24) {
                VStack(spacing: 8) {
                    CaptionText("Unfocused (sharp)")
                    VStack(spacing: 8) { cardContent }.vaporFocusBlur(isFocused: false)
                }
                VStack(spacing: 8) {
                    CaptionText("Focused (2px blur)")
                    VStack(spacing: 8) { cardContent }.vaporFocusBlur(isFocused: true)
                }
            }
            .padding(32).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "focus_blur_effect",
                                   section: "Components", description: "Focus blur effect: sharp vs blurred background content.")
        }
    }
}
