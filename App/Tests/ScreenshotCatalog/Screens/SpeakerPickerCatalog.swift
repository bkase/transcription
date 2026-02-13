import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import SpeakerPickerFeature

// MARK: - Speaker Picker Catalog

extension CatalogBase {
    @Suite("Speaker Picker")
    @MainActor
    struct SpeakerPickerCatalog {

        @Test func testSpeakerPickerLoading() {
            let view = SpeakerPickerViewPreview(displayOrder: 1, displayMode: .loading)
                .background(VaporColor.mist)
            CatalogHarness.capture(of: view, named: "speaker_picker_loading",
                                   section: "Speaker Picker", description: "Loading state.")
        }

        @Test func testSpeakerPickerWithPeople() {
            let view = SpeakerPickerViewPreview(
                displayOrder: 1,
                displayMode: .picker(
                    people: [
                        .init(name: "Sarah Chen", color: .sky, isSelected: false),
                        .init(name: "Marcus Kim", color: .lavender, isSelected: true),
                        .init(name: "Alex Rivera", color: .deep, isSelected: false)
                    ],
                    showNewOption: true
                )
            )
            .background(VaporColor.mist)
            CatalogHarness.capture(of: view, named: "speaker_picker_with_people",
                                   section: "Speaker Picker", description: "Picker with people list, one selected.")
        }

        @Test func testSpeakerPickerEmpty() {
            let view = SpeakerPickerViewPreview(
                displayOrder: 1,
                displayMode: .picker(people: [], showNewOption: true)
            )
            .background(VaporColor.mist)
            CatalogHarness.capture(of: view, named: "speaker_picker_empty",
                                   section: "Speaker Picker", description: "Picker with no existing speakers.")
        }

        @Test func testSpeakerPickerWithCurrentUser() {
            let view = SpeakerPickerViewPreview(
                displayOrder: 1,
                displayMode: .picker(
                    people: [
                        .init(name: "Sarah Chen", color: .sky, isSelected: false),
                        .init(name: "Marcus Kim", color: .lavender, isSelected: false)
                    ],
                    showNewOption: true,
                    currentUser: .init(name: "Jane Doe", isSelected: false)
                )
            )
            .background(VaporColor.mist)
            CatalogHarness.capture(of: view, named: "speaker_picker_with_current_user",
                                   section: "Speaker Picker", description: "Picker showing 'You' option at top.")
        }

        @Test func testSpeakerPickerCurrentUserSelected() {
            let view = SpeakerPickerViewPreview(
                displayOrder: 1,
                displayMode: .picker(
                    people: [
                        .init(name: "Sarah Chen", color: .sky, isSelected: false),
                        .init(name: "Marcus Kim", color: .lavender, isSelected: false)
                    ],
                    showNewOption: true,
                    currentUser: .init(name: "Jane Doe", isSelected: true)
                )
            )
            .background(VaporColor.mist)
            CatalogHarness.capture(of: view, named: "speaker_picker_current_user_selected",
                                   section: "Speaker Picker", description: "Picker with 'You' option selected.")
        }

        @Test func testSpeakerPickerNewPersonForm() {
            let view = SpeakerPickerViewPreview(
                displayOrder: 2,
                displayMode: .newPersonForm(name: "John Doe")
            )
            .background(VaporColor.mist)
            CatalogHarness.capture(of: view, named: "speaker_picker_new_person_form",
                                   section: "Speaker Picker", description: "New person form with name entered.")
        }
    }
}
