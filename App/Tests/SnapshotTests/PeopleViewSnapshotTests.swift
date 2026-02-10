import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import PeopleFeature

// MARK: - People View Snapshot Tests

@Suite("People View Snapshots", .snapshots(record: SnapshotConfig.recordMode))
@MainActor
struct PeopleViewSnapshotTests {

    @Test func testPeopleDirectoryDefault() {
        // Default state: people displayed with different colors
        let view = PeopleViewPreview(
            people: [
                .init(name: "Sarah Chen", conversationCount: 12, color: .sky),
                .init(name: "Marcus Kim", conversationCount: 8, color: .lavender),
                .init(name: "Alex Rivera", conversationCount: 3, color: .deep),
                .init(name: "Jordan Lee", conversationCount: 1, color: .dusk)
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "people_directory_default")
    }

    @Test func testPeopleDirectoryEmpty() {
        // Empty state: no people yet
        let view = PeopleViewPreview(displayMode: .empty)

        SnapshotHarness.assertSnapshot(of: view, named: "people_directory_empty")
    }

    @Test func testPeopleDirectorySearchNoResults() {
        // Search state: no results found
        let view = PeopleViewPreview(displayMode: .emptySearch, searchText: "xyz")

        SnapshotHarness.assertSnapshot(of: view, named: "people_directory_search_no_results")
    }
}

// MARK: - Person Form Sheet Snapshot Tests

@Suite("Person Form Sheet Snapshots", .snapshots(record: SnapshotConfig.recordMode))
@MainActor
struct PersonFormSheetSnapshotTests {

    @Test func testPersonFormAddPerson() {
        // Add person form - empty state with no name or photo
        let view = PersonFormSheetPreview(displayMode: .addPerson)

        SnapshotHarness.assertSnapshot(of: view, named: "person_form_add_person")
    }

    @Test func testPersonFormAddPersonWithPhoto() {
        // Add person form with photo selected
        // Note: Using mock image data for snapshot consistency
        let view = PersonFormSheetPreview(
            displayMode: .addPersonWithPhoto,
            name: "Alice Smith",
            color: .lavender,
            imageData: MockPhotoData.imageData(forIndex: 0)
        )

        SnapshotHarness.assertSnapshot(of: view, named: "person_form_add_person_with_photo")
    }

    @Test func testPersonFormEditPerson() {
        // Edit person form - shows initials, no photo
        let view = PersonFormSheetPreview(
            displayMode: .editPerson,
            name: "Bob Johnson",
            color: .deep
        )

        SnapshotHarness.assertSnapshot(of: view, named: "person_form_edit_person")
    }

    @Test func testPersonFormEditPersonWithPhoto() {
        // Edit person form with existing photo
        let view = PersonFormSheetPreview(
            displayMode: .editPersonWithPhoto,
            name: "Carol Williams",
            color: .dusk,
            imageData: MockPhotoData.imageData(forIndex: 1)
        )

        SnapshotHarness.assertSnapshot(of: view, named: "person_form_edit_person_with_photo")
    }
}
