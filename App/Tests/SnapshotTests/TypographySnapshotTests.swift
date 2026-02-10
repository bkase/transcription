import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Typography Snapshot Tests

@Suite("Typography Component Snapshots", .snapshots(record: SnapshotConfig.recordMode))
@MainActor
struct TypographySnapshotTests {

    @Test func testAllTextStyles() {
        let view = VStack(alignment: .leading, spacing: 24) {
            DisplayText("Display Text")
            TitleText("Title Text")
            HeadlineText("Headline Text")
            BodyText("Body text for paragraphs and regular content.")
            CaptionText("Caption text for supplementary info")
            TimestampText("12:34:56")
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "all_text_styles")
    }

    @Test func testTypographyHierarchy() {
        // Tests a realistic usage scenario with proper visual hierarchy
        let view = VStack(alignment: .leading, spacing: 16) {
            DisplayText("Welcome Back")

            VStack(alignment: .leading, spacing: 8) {
                TitleText("Recent Sessions")
                HeadlineText("Today")

                VStack(alignment: .leading, spacing: 4) {
                    BodyText("Morning standup with the team")
                    HStack {
                        CaptionText("45 min")
                        TimestampText("09:30")
                    }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "typography_hierarchy")
    }
}
