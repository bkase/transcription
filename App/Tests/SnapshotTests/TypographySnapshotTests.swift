import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Typography Snapshot Tests

@Suite("Typography Component Snapshots")
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

    @Test func testDisplayText() {
        let view = VStack(alignment: .leading, spacing: 16) {
            DisplayText("Default Display")
            DisplayText("Secondary Display", color: VaporColor.textSecondary)
            DisplayText("Accent Display", color: VaporColor.deep)
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "display_text")
    }

    @Test func testTitleText() {
        let view = VStack(alignment: .leading, spacing: 16) {
            TitleText("Default Title")
            TitleText("Secondary Title", color: VaporColor.textSecondary)
            TitleText("Accent Title", color: VaporColor.deep)
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "title_text")
    }

    @Test func testHeadlineText() {
        let view = VStack(alignment: .leading, spacing: 16) {
            HeadlineText("Default Headline")
            HeadlineText("Secondary Headline", color: VaporColor.textSecondary)
            HeadlineText("Accent Headline", color: VaporColor.deep)
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "headline_text")
    }

    @Test func testBodyText() {
        let view = VStack(alignment: .leading, spacing: 16) {
            BodyText("Default body text for regular paragraph content.")
            BodyText("Secondary body text with muted appearance.", color: VaporColor.textSecondary)
            BodyText("Accent body text for emphasis.", color: VaporColor.deep)
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "body_text")
    }

    @Test func testCaptionText() {
        let view = VStack(alignment: .leading, spacing: 16) {
            CaptionText("Default caption (uses secondary color)")
            CaptionText("Primary caption", color: VaporColor.textPrimary)
            CaptionText("Tertiary caption", color: VaporColor.textTertiary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "caption_text")
    }

    @Test func testTimestampText() {
        let view = VStack(alignment: .leading, spacing: 16) {
            TimestampText("00:00:00")
            TimestampText("12:34:56")
            TimestampText("23:59:59", color: VaporColor.textSecondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "timestamp_text")
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
