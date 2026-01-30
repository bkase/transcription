import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Speaker Components Snapshot Tests

@Suite("Speaker Component Snapshots")
@MainActor
struct SpeakerComponentsSnapshotTests {

    @Test func testSpeakerUnsetAndSet() {
        let view = VStack(alignment: .leading, spacing: 32) {
            // Speaker Unset variants
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Speaker Unset")
                HStack(spacing: 12) {
                    SpeakerUnset(number: 1)
                    SpeakerUnset(number: 2, color: .lavender)
                    SpeakerUnset(number: 3, color: .deep)
                }
            }

            // Speaker Set variants
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Speaker Set")
                HStack(spacing: 16) {
                    SpeakerSet(name: "Sarah")
                    SpeakerSet(name: "Marcus", color: .lavender)
                    SpeakerSet(name: "Alex", color: .deep)
                }
            }

            // Speaker Options
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Speaker Options")
                VStack(spacing: 0) {
                    SpeakerOption(name: "Sarah Chen", color: .sky, isSelected: false)
                    SpeakerOption(name: "Marcus Kim", color: .lavender, isSelected: true)
                }
                .background(VaporColor.cloud)
                .cornerRadius(8)
            }

            // New Speaker Option
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("New Speaker Option")
                NewSpeakerOption()
                    .background(VaporColor.cloud)
                    .cornerRadius(8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_unset_and_set")
    }

    @Test func testSpeakerPickerModal() {
        let view = VStack(alignment: .leading, spacing: 32) {
            // Full modal with existing speakers
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Speaker Picker Modal")
                SpeakerPickerModalPreview(
                    existingSpeakers: [
                        (name: "Sarah Chen", color: .sky, isSelected: false),
                        (name: "Marcus Kim", color: .lavender, isSelected: true)
                    ]
                )
            }

            // Person cards
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Person Cards")
                PersonCard(name: "Sarah Chen", conversationCount: 12)
                PersonCard(name: "Marcus Kim", conversationCount: 1, color: .lavender)
                PersonCard(name: "Alex Johnson", conversationCount: 5, color: .deep)
            }

            // Speaker Name Input
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Speaker Name Input")
                SpeakerNameInputPreview(name: "Sarah")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_picker_modal")
    }

    @Test func testSpeakerColorVariants() {
        let view = VStack(alignment: .leading, spacing: 24) {
            // All speaker colors
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Speaker Color Variants")
                HStack(spacing: 12) {
                    ForEach(Array(SpeakerColor.allCases.enumerated()), id: \.offset) { index, color in
                        VStack(spacing: 8) {
                            SpeakerUnset(number: index + 1, color: color)
                            SpeakerSet(name: "Speaker", color: color)
                        }
                    }
                }
            }

            // Color by index
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Color by Index (cycles)")
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        SpeakerSet(name: "S\(index + 1)", color: SpeakerColor.forIndex(index))
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_color_variants")
    }

    @Test func testPersonCardInitials() {
        let view = VStack(alignment: .leading, spacing: 16) {
            CaptionText("Person Card Initials Generation")

            // Two-word names
            PersonCard(name: "Sarah Chen", conversationCount: 12)

            // Single name
            PersonCard(name: "Marcus", conversationCount: 5, color: .lavender)

            // Three-word name (uses first and last)
            PersonCard(name: "Alex von Johnson", conversationCount: 3, color: .deep)

            // Custom initials override
            PersonCard(name: "Unknown Speaker", initials: "?", conversationCount: 0, color: .dusk)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "person_card_initials")
    }

    /// Test that names with parentheses strip the parenthetical content for initials.
    /// This verifies the fix for bd-34t4: Initials should not include parentheses.
    @Test func testPersonCardInitialsWithParentheses() {
        let view = VStack(alignment: .leading, spacing: 16) {
            CaptionText("Initials with Parenthetical Content")

            // "Alice (Work)" -> should show "A" not "A("
            PersonCard(name: "Alice (Work)", conversationCount: 5)

            // "You (John Smith)" -> should show "Y" not "Y("
            PersonCard(name: "You (John Smith)", conversationCount: 2, color: .lavender)

            // "Mary Jane (Personal)" -> should show "MJ" not "MJ("
            PersonCard(name: "Mary Jane (Personal)", conversationCount: 8, color: .deep)

            // "Bob" -> no parentheses, should show "B"
            PersonCard(name: "Bob", conversationCount: 1, color: .dusk)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "person_card_initials_with_parentheses")
    }
}
