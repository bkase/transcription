import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Headers Catalog

extension CatalogBase {
    @Suite("Header Components")
    @MainActor
    struct HeadersCatalog {

        @Test func testPageHeader() {
            let view = VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Archive Screen")
                    PageHeader(kicker: "Archive", title: "Timeline")
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Recording Screen")
                    PageHeader(kicker: "Recording", title: "Architecture Review")
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("People Screen")
                    PageHeader(kicker: "People", title: "Directory")
                }
            }
            .padding(32).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "page_header",
                                   section: "Components", description: "Page headers for Archive, Recording, and People screens.")
        }

        @Test func testDateHeader() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) { CaptionText("Today"); DateHeader.today }
                VStack(alignment: .leading, spacing: 8) { CaptionText("Yesterday"); DateHeader.yesterday }
                VStack(alignment: .leading, spacing: 8) { CaptionText("Custom Date"); DateHeader("JANUARY 12") }
                VStack(alignment: .leading, spacing: 8) { CaptionText("Another Custom Date"); DateHeader("DECEMBER 25") }
            }
            .padding(32).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "date_header",
                                   section: "Components", description: "Date headers: Today, Yesterday, and custom dates.")
        }

        @Test func testAvatar() {
            let view = VStack(spacing: 24) {
                VStack(spacing: 8) {
                    CaptionText("Sizes")
                    HStack(spacing: 16) {
                        VStack(spacing: 4) { Avatar(size: .small); Text("24pt").font(.system(size: 10)).foregroundColor(VaporColor.textTertiary) }
                        VStack(spacing: 4) { Avatar(size: .medium); Text("32pt").font(.system(size: 10)).foregroundColor(VaporColor.textTertiary) }
                        VStack(spacing: 4) { Avatar(size: .large); Text("44pt").font(.system(size: 10)).foregroundColor(VaporColor.textTertiary) }
                    }
                }
                VStack(spacing: 8) {
                    CaptionText("With Initials")
                    HStack(spacing: 16) {
                        Avatar(initials: "JD", size: .small)
                        Avatar(initials: "JD", size: .medium)
                        Avatar(initials: "JD", size: .large)
                    }
                }
                VStack(spacing: 8) {
                    CaptionText("Default Placeholder")
                    HStack(spacing: 16) {
                        Avatar(size: .small)
                        Avatar(size: .medium)
                        Avatar(size: .large)
                    }
                }
            }
            .padding(32).frame(maxWidth: .infinity).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "avatar",
                                   section: "Components", description: "Avatars at small/medium/large sizes, with initials and placeholder.")
        }

        @Test func testBadges() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Speaker Badges")
                    HStack(spacing: 12) {
                        SpeakerBadge(count: 1); SpeakerBadge(count: 2)
                        SpeakerBadge(count: 3); SpeakerBadge(count: 4)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Duration Badges")
                    HStack(spacing: 12) {
                        DurationBadge(durationText: "5:30")
                        DurationBadge(durationText: "42:10")
                        DurationBadge(durationText: "1:30:45")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Session Badges")
                    SessionBadges(speakerCount: 2, durationText: "42:10")
                }
            }
            .padding(32).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "badges",
                                   section: "Components", description: "Speaker count badges, duration badges, and combined session badges.")
        }

        @Test func testHeaderInContext() {
            let view = VStack(spacing: 0) {
                HStack(alignment: .top) {
                    PageHeader(kicker: "Archive", title: "Timeline")
                    Spacer()
                    Avatar(initials: "JD", size: .medium)
                }
                .padding(.horizontal, 24).padding(.top, 24)
                Spacer().frame(height: 24)
                VStack(alignment: .leading, spacing: 16) {
                    DateHeader.today
                    RoundedRectangle(cornerRadius: 12).fill(VaporColor.cloud).frame(height: 80)
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 300).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "header_in_context",
                                   section: "Components", description: "Full page header with avatar and date section.")
        }
    }
}
