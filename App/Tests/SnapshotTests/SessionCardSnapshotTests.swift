import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Session Card Snapshot Tests

@Suite("Session Card Component Snapshots")
@MainActor
struct SessionCardSnapshotTests {

    @Test func testSessionCardStates() {
        let view = VStack(alignment: .leading, spacing: 32) {
            // Default state (no metadata)
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Default State")
                SessionCard(
                    title: "Architecture Review",
                    time: "9:41 AM",
                    previewText: "So we're looking at the Vapor direction..."
                )
            }

            // Hover state with metadata badges
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Hover State (with metadata)")
                SessionCard(
                    title: "Architecture Review",
                    time: "9:41 AM",
                    previewText: "So we're looking at the Vapor direction...",
                    speakerCount: 2,
                    duration: "42:10",
                    showMetadata: true
                )
            }

            // Default state with longer preview
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Longer Preview")
                SessionCard(
                    title: "Morning Reflection",
                    time: "7:30 AM",
                    previewText: "The light in the studio was particularly interesting this morning..."
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "session_card_states")
    }

    @Test func testSessionCardMetadataVariants() {
        let view = VStack(alignment: .leading, spacing: 24) {
            // Single speaker
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("1 Speaker")
                SessionCard(
                    title: "Solo Recording",
                    time: "2:30 PM",
                    previewText: "Just me talking to myself about ideas...",
                    speakerCount: 1,
                    duration: "15:30",
                    showMetadata: true
                )
            }

            // Multiple speakers
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("3 Speakers")
                SessionCard(
                    title: "Team Standup",
                    time: "9:00 AM",
                    previewText: "Let's go around and share updates...",
                    speakerCount: 3,
                    duration: "28:45",
                    showMetadata: true
                )
            }

            // Long duration
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Long Duration")
                SessionCard(
                    title: "Product Strategy",
                    time: "4:20 PM",
                    previewText: "If we pivot to a local-first model, the database sync...",
                    speakerCount: 4,
                    duration: "1:42:10",
                    showMetadata: true
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "session_card_metadata_variants")
    }

    @Test func testSessionCardInTimeline() {
        // Simulate cards in a timeline context
        let view = VStack(alignment: .leading, spacing: 24) {
            // Date header
            DateHeader.today

            // Cards
            VStack(spacing: 16) {
                SessionCard(
                    title: "Architecture Review",
                    time: "9:41 AM",
                    previewText: "So we're looking at the Vapor direction...",
                    speakerCount: 2,
                    duration: "42:10",
                    showMetadata: true
                )

                SessionCard(
                    title: "Morning Reflection",
                    time: "7:30 AM",
                    previewText: "The light in the studio was particularly interesting this morning..."
                )
            }

            // Another date section
            DateHeader.yesterday

            SessionCard(
                title: "Product Strategy",
                time: "4:20 PM",
                previewText: "If we pivot to a local-first model, the database sync..."
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "session_card_in_timeline")
    }

    @Test func testSessionCardWithSpeakerAvatars() {
        // Test speaker avatars on the right side near time
        let view = VStack(alignment: .leading, spacing: 24) {
            // Single avatar
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("1 Avatar (right side)")
                SessionCard(
                    title: "Solo Recording",
                    time: "2:30 PM",
                    previewText: "Just me talking to myself about ideas...",
                    speakerAvatars: [
                        SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky)
                    ]
                )
            }

            // Two overlapping avatars
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("2 Avatars (overlapping)")
                SessionCard(
                    title: "Architecture Review",
                    time: "9:41 AM",
                    previewText: "So we're looking at the Vapor direction...",
                    speakerAvatars: [
                        SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky),
                        SpeakerAvatarInfo(id: "2", initials: "MK", color: .lavender)
                    ]
                )
            }

            // With status pill + avatars
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Status Pill + Avatars")
                SessionCard(
                    title: "Team Standup",
                    time: "9:00 AM",
                    previewText: "Let's go around and share updates...",
                    statusPillType: .transcribing,
                    speakerAvatars: [
                        SpeakerAvatarInfo(id: "1", initials: "AL", color: .deep),
                        SpeakerAvatarInfo(id: "2", initials: "JS", color: .dusk)
                    ]
                )
            }

            // Without avatars (fallback)
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("No Avatars")
                SessionCard(
                    title: "Morning Reflection",
                    time: "7:30 AM",
                    previewText: "The light in the studio was particularly interesting this morning...",
                    speakerAvatars: []
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "session_card_speaker_avatars")
    }
}
