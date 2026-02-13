import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Cards Catalog

extension CatalogBase {
    @Suite("Card Components")
    @MainActor
    struct CardsCatalog {

        @Test func testSessionCardStates() {
            let view = VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Default State")
                    SessionCard(title: "Architecture Review", time: "9:41 AM",
                                previewText: "So we're looking at the Vapor direction...")
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Hover State (with metadata)")
                    SessionCard(title: "Architecture Review", time: "9:41 AM",
                                previewText: "So we're looking at the Vapor direction...",
                                speakerCount: 2, duration: "42:10", showMetadata: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Longer Preview")
                    SessionCard(title: "Morning Reflection", time: "7:30 AM",
                                previewText: "The light in the studio was particularly interesting this morning...")
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "session_card_states",
                                   section: "Components", description: "Session card in default, hover with metadata, and long preview states.")
        }

        @Test func testSessionCardMetadataVariants() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("1 Speaker")
                    SessionCard(title: "Solo Recording", time: "2:30 PM",
                                previewText: "Just me talking to myself about ideas...",
                                speakerCount: 1, duration: "15:30", showMetadata: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("3 Speakers")
                    SessionCard(title: "Team Standup", time: "9:00 AM",
                                previewText: "Let's go around and share updates...",
                                speakerCount: 3, duration: "28:45", showMetadata: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Long Duration")
                    SessionCard(title: "Product Strategy", time: "4:20 PM",
                                previewText: "If we pivot to a local-first model, the database sync...",
                                speakerCount: 4, duration: "1:42:10", showMetadata: true)
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "session_card_metadata_variants",
                                   section: "Components", description: "Session cards with varying speaker counts and durations.")
        }

        @Test func testSessionCardInTimeline() {
            let view = VStack(alignment: .leading, spacing: 24) {
                DateHeader.today
                VStack(spacing: 16) {
                    SessionCard(title: "Architecture Review", time: "9:41 AM",
                                previewText: "So we're looking at the Vapor direction...",
                                speakerCount: 2, duration: "42:10", showMetadata: true)
                    SessionCard(title: "Morning Reflection", time: "7:30 AM",
                                previewText: "The light in the studio was particularly interesting this morning...")
                }
                DateHeader.yesterday
                SessionCard(title: "Product Strategy", time: "4:20 PM",
                            previewText: "If we pivot to a local-first model, the database sync...")
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "session_card_in_timeline",
                                   section: "Components", description: "Session cards in timeline context with date headers.")
        }

        @Test func testSessionCardWithSpeakerAvatars() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("1 Avatar")
                    SessionCard(title: "Solo Recording", time: "2:30 PM",
                                previewText: "Just me talking to myself about ideas...",
                                speakerAvatars: [SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky)])
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("2 Avatars (overlapping)")
                    SessionCard(title: "Architecture Review", time: "9:41 AM",
                                previewText: "So we're looking at the Vapor direction...",
                                speakerAvatars: [
                                    SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky),
                                    SpeakerAvatarInfo(id: "2", initials: "MK", color: .lavender)
                                ])
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Status Pill + Avatars")
                    SessionCard(title: "Team Standup", time: "9:00 AM",
                                previewText: "Let's go around and share updates...",
                                statusPillType: .transcribing,
                                speakerAvatars: [
                                    SpeakerAvatarInfo(id: "1", initials: "AL", color: .deep),
                                    SpeakerAvatarInfo(id: "2", initials: "JS", color: .dusk)
                                ])
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("No Avatars")
                    SessionCard(title: "Morning Reflection", time: "7:30 AM",
                                previewText: "The light in the studio was particularly interesting this morning...",
                                speakerAvatars: [])
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "session_card_speaker_avatars",
                                   section: "Components", description: "Session cards with speaker avatar circles.")
        }

        @Test func testSessionCardStatusPills() {
            let view = VStack(alignment: .leading, spacing: 16) {
                SessionCard(title: "Transcribing", time: "10:00 AM",
                            previewText: "Processing audio...", statusPillType: .transcribing)
                SessionCard(title: "Partial", time: "11:00 AM",
                            previewText: "Some segments available...", statusPillType: .partial)
                SessionCard(title: "Failed", time: "12:00 PM",
                            previewText: "Could not process...", statusPillType: .failed)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "session_card_status_pills",
                                   section: "Components", description: "Session cards with transcribing, partial, and failed status pills.")
        }

        @Test func testSessionCardTimestampAlignment() {
            let view = VStack(alignment: .leading, spacing: 8) {
                SessionCard(title: "Morning Standup", time: "9:00 AM",
                            previewText: "Quick sync on what we're working on...",
                            speakerAvatars: [SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky)])
                SessionCard(title: "Architecture Review", time: "10:30 AM",
                            previewText: "So we're looking at the Vapor direction...",
                            speakerAvatars: [SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky)])
                SessionCard(title: "Product Strategy", time: "12:59 PM",
                            previewText: "If we pivot to a local-first model...",
                            speakerAvatars: [SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky)])
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "session_card_timestamp_alignment",
                                   section: "Components", description: "Timestamp alignment verification across varying widths.")
        }
    }
}
