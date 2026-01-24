import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Header Snapshot Tests

@Suite("Header Component Snapshots")
@MainActor
struct HeaderSnapshotTests {

    @Test func testPageHeader() {
        let view = VStack(alignment: .leading, spacing: 32) {
            // Archive/Timeline header
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Archive Screen")
                PageHeader(kicker: "Archive", title: "Timeline")
            }

            // Recording header
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Recording Screen")
                PageHeader(kicker: "Recording", title: "Architecture Review")
            }

            // People directory header
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("People Screen")
                PageHeader(kicker: "People", title: "Directory")
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "page_header")
    }

    @Test func testDateHeader() {
        let view = VStack(alignment: .leading, spacing: 24) {
            // Common date headers
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Today")
                DateHeader.today
            }

            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Yesterday")
                DateHeader.yesterday
            }

            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Custom Date")
                DateHeader("JANUARY 12")
            }

            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Another Custom Date")
                DateHeader("DECEMBER 25")
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "date_header")
    }

    @Test func testAvatar() {
        let view = VStack(spacing: 24) {
            // Size variants
            VStack(spacing: 8) {
                CaptionText("Sizes")
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Avatar(size: .small)
                        Text("24pt").font(.system(size: 10)).foregroundColor(VaporColor.textTertiary)
                    }
                    VStack(spacing: 4) {
                        Avatar(size: .medium)
                        Text("32pt").font(.system(size: 10)).foregroundColor(VaporColor.textTertiary)
                    }
                    VStack(spacing: 4) {
                        Avatar(size: .large)
                        Text("44pt").font(.system(size: 10)).foregroundColor(VaporColor.textTertiary)
                    }
                }
            }

            // With initials
            VStack(spacing: 8) {
                CaptionText("With Initials")
                HStack(spacing: 16) {
                    Avatar(initials: "JD", size: .small)
                    Avatar(initials: "JD", size: .medium)
                    Avatar(initials: "JD", size: .large)
                }
            }

            // Empty (default placeholder)
            VStack(spacing: 8) {
                CaptionText("Default Placeholder")
                HStack(spacing: 16) {
                    Avatar(size: .small)
                    Avatar(size: .medium)
                    Avatar(size: .large)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "avatar")
    }

    @Test func testBadges() {
        let view = VStack(alignment: .leading, spacing: 24) {
            // Speaker badges with different counts
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Speaker Badges")
                HStack(spacing: 12) {
                    SpeakerBadge(count: 1)
                    SpeakerBadge(count: 2)
                    SpeakerBadge(count: 3)
                    SpeakerBadge(count: 4)
                }
            }

            // Duration badges
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Duration Badges")
                HStack(spacing: 12) {
                    DurationBadge(durationText: "5:30")
                    DurationBadge(durationText: "42:10")
                    DurationBadge(durationText: "1:30:45")
                }
            }

            // Combined session badges
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Session Badges")
                SessionBadges(speakerCount: 2, durationText: "42:10")
            }

            // From milliseconds
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("From Milliseconds")
                SessionBadges(speakerCount: 3, durationMilliseconds: 5430000)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "badges")
    }

    @Test func testHeaderInContext() {
        // Simulate a full page header with avatar
        let view = VStack(spacing: 0) {
            HStack(alignment: .top) {
                PageHeader(kicker: "Archive", title: "Timeline")
                Spacer()
                Avatar(initials: "JD", size: .medium)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()
                .frame(height: 24)

            // Section with date header
            VStack(alignment: .leading, spacing: 16) {
                DateHeader.today

                // Simulated session card placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(VaporColor.cloud)
                    .frame(height: 80)
                    .overlay(
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Architecture Review")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(VaporColor.textPrimary)
                                Text("So we're looking at the Vapor direction...")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(VaporColor.textTertiary)
                            }
                            Spacer()
                            SessionBadges(speakerCount: 2, durationText: "42:10")
                        }
                        .padding(16)
                    )
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 300)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "header_in_context")
    }
}
