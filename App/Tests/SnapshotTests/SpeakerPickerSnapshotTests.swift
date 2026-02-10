import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import SpeakerPickerFeature

// MARK: - Speaker Picker View Snapshot Tests

@Suite("Speaker Picker View Snapshots", .snapshots(record: SnapshotConfig.recordMode))
@MainActor
struct SpeakerPickerSnapshotTests {

    @Test func testSpeakerPickerFeatureModal() {
        // Full feature picker modal with existing speakers and selection
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

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_picker_feature_modal")
    }

    @Test func testSpeakerPickerModalEmpty() {
        // Picker modal with no existing speakers (only new option)
        let view = SpeakerPickerViewPreview(
            displayOrder: 1,
            displayMode: .picker(
                people: [],
                showNewOption: true
            )
        )
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_picker_modal_empty")
    }

    @Test func testSpeakerPickerNewPersonForm() {
        // New person form state
        let view = SpeakerPickerViewPreview(
            displayOrder: 2,
            displayMode: .newPersonForm(name: "John Doe")
        )
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_picker_new_person_form")
    }

    @Test func testSpeakerPickerLoading() {
        // Loading state
        let view = SpeakerPickerViewPreview(
            displayOrder: 1,
            displayMode: .loading
        )
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_picker_loading")
    }

    @Test func testSpeakerPickerWithCurrentUser() {
        // Picker modal showing "You" option at the top
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

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_picker_with_current_user")
    }

    @Test func testSpeakerPickerWithCurrentUserSelected() {
        // Picker modal with "You" option selected
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

        SnapshotHarness.assertSnapshot(of: view, named: "speaker_picker_current_user_selected")
    }
}
