import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Input Snapshot Tests

@Suite("Input Component Snapshots")
@MainActor
struct InputSnapshotTests {

    @Test func testSearchField() {
        let view = VStack(spacing: 24) {
            // Idle state (empty)
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Idle State")
                SearchFieldPreview()
            }

            // Focused state with text
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Focused State")
                SearchFieldPreview(text: "morning ref", isFocused: true)
            }

            // Custom placeholder
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Custom Placeholder")
                SearchFieldPreview(placeholder: "Search people...")
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "search_field")
    }

    @Test func testSearchFieldInContext() {
        // Simulate search field in timeline header
        let view = VStack(spacing: 0) {
            // Header area
            HStack(alignment: .top) {
                PageHeader(kicker: "Archive", title: "Timeline")
                Spacer()
                Avatar(initials: "JD", size: .medium)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // Search field
            SearchFieldPreview()
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Spacer()
        }
        .frame(height: 200)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "search_field_in_context")
    }

    @Test func testSearchFieldStates() {
        // Side-by-side comparison of states
        let view = HStack(spacing: 24) {
            VStack(spacing: 8) {
                CaptionText("Idle")
                SearchFieldPreview()
                    .frame(width: 160)
            }

            VStack(spacing: 8) {
                CaptionText("Focused")
                SearchFieldPreview(text: "morning", isFocused: true)
                    .frame(width: 160)
            }
        }
        .padding(32)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "search_field_states")
    }
}
