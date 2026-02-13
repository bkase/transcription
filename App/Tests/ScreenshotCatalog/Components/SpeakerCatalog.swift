import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Speaker Catalog

extension CatalogBase {
    @Suite("Speaker Components")
    @MainActor
    struct SpeakerCatalog {

        @Test func testSpeakerUnsetAndSet() {
            let view = VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Speaker Unset")
                    HStack(spacing: 12) {
                        SpeakerUnset(number: 1)
                        SpeakerUnset(number: 2, color: .lavender)
                        SpeakerUnset(number: 3, color: .deep)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Speaker Set")
                    HStack(spacing: 16) {
                        SpeakerSet(name: "Sarah")
                        SpeakerSet(name: "Marcus", color: .lavender)
                        SpeakerSet(name: "Alex", color: .deep)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Speaker Options")
                    VStack(spacing: 0) {
                        SpeakerOption(name: "Sarah Chen", color: .sky, isSelected: false)
                        SpeakerOption(name: "Marcus Kim", color: .lavender, isSelected: true)
                    }
                    .background(VaporColor.cloud).cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("New Speaker Option")
                    NewSpeakerOption().background(VaporColor.cloud).cornerRadius(8)
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "speaker_unset_and_set",
                                   section: "Components", description: "Speaker labels: unset chips, set names, option rows, and new speaker.")
        }

        @Test func testSpeakerPickerModal() {
            let view = VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Speaker Picker Modal")
                    SpeakerPickerModalPreview(
                        existingSpeakers: [
                            (name: "Sarah Chen", color: .sky, isSelected: false),
                            (name: "Marcus Kim", color: .lavender, isSelected: true)
                        ]
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Person Cards")
                    PersonCard(name: "Sarah Chen", conversationCount: 12)
                    PersonCard(name: "Marcus Kim", conversationCount: 1, color: .lavender)
                    PersonCard(name: "Alex Johnson", conversationCount: 5, color: .deep)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Speaker Name Input")
                    SpeakerNameInputPreview(name: "Sarah")
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "speaker_picker_modal",
                                   section: "Components", description: "Speaker picker modal, person cards, and name input.")
        }

        @Test func testSpeakerColorVariants() {
            let view = VStack(alignment: .leading, spacing: 24) {
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
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Color by Index (cycles)")
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            SpeakerSet(name: "S\(index + 1)", color: SpeakerColor.forIndex(index))
                        }
                    }
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "speaker_color_variants",
                                   section: "Components", description: "All speaker colors and index-based color cycling.")
        }

        @Test func testPersonCardInitials() {
            let view = VStack(alignment: .leading, spacing: 16) {
                CaptionText("Person Card Initials Generation")
                PersonCard(name: "Sarah Chen", conversationCount: 12)
                PersonCard(name: "Marcus", conversationCount: 5, color: .lavender)
                PersonCard(name: "Alex von Johnson", conversationCount: 3, color: .deep)
                PersonCard(name: "Unknown Speaker", initials: "?", conversationCount: 0, color: .dusk)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "person_card_initials",
                                   section: "Components", description: "Person cards with auto-generated and custom initials.")
        }

        @Test func testPersonCardInitialsWithParentheses() {
            let view = VStack(alignment: .leading, spacing: 16) {
                CaptionText("Initials with Parenthetical Content")
                PersonCard(name: "Alice (Work)", conversationCount: 5)
                PersonCard(name: "You (John Smith)", conversationCount: 2, color: .lavender)
                PersonCard(name: "Mary Jane (Personal)", conversationCount: 8, color: .deep)
                PersonCard(name: "Bob", conversationCount: 1, color: .dusk)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "person_card_initials_with_parentheses",
                                   section: "Components", description: "Initials correctly strip parenthetical content from names.")
        }

        @Test func testSpeakerAvatarStack() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("1 Avatar")
                    SpeakerAvatarStack(speakers: [
                        SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky)
                    ])
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("2 Avatars")
                    SpeakerAvatarStack(speakers: [
                        SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky),
                        SpeakerAvatarInfo(id: "2", initials: "MK", color: .lavender)
                    ])
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("3 Avatars")
                    SpeakerAvatarStack(speakers: [
                        SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky),
                        SpeakerAvatarInfo(id: "2", initials: "MK", color: .lavender),
                        SpeakerAvatarInfo(id: "3", initials: "AR", color: .deep)
                    ])
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "speaker_avatar_stack",
                                   section: "Components", description: "Speaker avatar stacks with 1, 2, and 3 overlapping avatars.")
        }

        @Test func testCurrentUserOption() {
            let view = VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Unselected")
                    CurrentUserOptionPreview(name: "Jane Doe", isSelected: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Selected")
                    CurrentUserOptionPreview(name: "Jane Doe", isSelected: true)
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "current_user_option",
                                   section: "Components", description: "Current user (You) option in selected and unselected states.")
        }
    }
}
