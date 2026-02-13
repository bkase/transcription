import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import ProfileFeature

// MARK: - Profile Catalog

extension CatalogBase {
    @Suite("Profile")
    @MainActor
    struct ProfileCatalog {

        @Test func testProfileDefault() {
            let view = ProfileViewPreview(name: "Brandon Kase", initials: "BK")
            CatalogHarness.capture(of: view, named: "profile_default",
                                   section: "Profile", description: "Default profile with name and initials.")
        }

        @Test func testProfileEmpty() {
            let view = ProfileViewPreview(name: "", initials: "", displayMode: .empty)
            CatalogHarness.capture(of: view, named: "profile_empty",
                                   section: "Profile", description: "Empty profile for new user.")
        }

        @Test func testProfileEditingName() {
            let view = ProfileViewPreview(
                name: "Brandon Kase", initials: "BK",
                displayMode: .editingName, editingNameText: "Brandon K"
            )
            CatalogHarness.capture(of: view, named: "profile_editing_name",
                                   section: "Profile", description: "Editing name mode with text field.")
        }

        @Test func testProfileEditingNameError() {
            let view = ProfileViewPreview(
                name: "Brandon Kase", initials: "BK",
                displayMode: .editingNameWithError,
                editingNameText: "",
                errorMessage: "Name cannot be empty"
            )
            CatalogHarness.capture(of: view, named: "profile_editing_name_error",
                                   section: "Profile", description: "Editing name with validation error.")
        }
    }
}
