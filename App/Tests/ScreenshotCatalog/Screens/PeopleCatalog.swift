import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import PeopleFeature

// MARK: - People Catalog

extension CatalogBase {
    @Suite("People")
    @MainActor
    struct PeopleCatalog {

        @Test func testPeopleDirectoryDefault() {
            let view = PeopleViewPreview(
                people: [
                    .init(name: "Sarah Chen", conversationCount: 12, color: .sky),
                    .init(name: "Marcus Kim", conversationCount: 8, color: .lavender),
                    .init(name: "Alex Rivera", conversationCount: 3, color: .deep),
                    .init(name: "Jordan Lee", conversationCount: 1, color: .dusk)
                ]
            )
            CatalogHarness.capture(of: view, named: "people_directory_default",
                                   section: "People", description: "People directory with contacts and conversation counts.")
        }

        @Test func testPeopleDirectoryEmpty() {
            let view = PeopleViewPreview(displayMode: .empty)
            CatalogHarness.capture(of: view, named: "people_directory_empty",
                                   section: "People", description: "Empty state with no people added.")
        }

        @Test func testPeopleDirectorySearchNoResults() {
            let view = PeopleViewPreview(displayMode: .emptySearch, searchText: "xyz")
            CatalogHarness.capture(of: view, named: "people_directory_search_no_results",
                                   section: "People", description: "Search with no matching results.")
        }

        @Test func testPersonFormAdd() {
            let view = PersonFormSheetPreview(displayMode: .addPerson)
            CatalogHarness.capture(of: view, named: "person_form_add",
                                   section: "People", description: "Add person form, empty state.")
        }

        @Test func testPersonFormAddWithPhoto() {
            let view = PersonFormSheetPreview(
                displayMode: .addPersonWithPhoto,
                name: "Alice Smith",
                color: .lavender,
                imageData: MockPhotoData.imageData(forIndex: 0)
            )
            CatalogHarness.capture(of: view, named: "person_form_add_with_photo",
                                   section: "People", description: "Add person form with photo selected.")
        }

        @Test func testPersonFormEdit() {
            let view = PersonFormSheetPreview(
                displayMode: .editPerson,
                name: "Bob Johnson",
                color: .deep
            )
            CatalogHarness.capture(of: view, named: "person_form_edit",
                                   section: "People", description: "Edit person form with initials, no photo.")
        }

        @Test func testPersonFormEditWithPhoto() {
            let view = PersonFormSheetPreview(
                displayMode: .editPersonWithPhoto,
                name: "Carol Williams",
                color: .dusk,
                imageData: MockPhotoData.imageData(forIndex: 1)
            )
            CatalogHarness.capture(of: view, named: "person_form_edit_with_photo",
                                   section: "People", description: "Edit person form with existing photo.")
        }
    }
}
