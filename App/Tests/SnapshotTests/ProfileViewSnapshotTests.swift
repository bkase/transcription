import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import ProfileFeature

// MARK: - Profile View Snapshot Tests

@Suite("Profile View Snapshots", .snapshots(record: SnapshotConfig.recordMode))
@MainActor
struct ProfileViewSnapshotTests {

    @Test func testProfileViewDefault() {
        // Default state: user with name and initials (populated)
        let view = ProfileViewPreview(
            name: "Brandon Kase",
            initials: "BK"
        )

        SnapshotHarness.assertSnapshot(of: view, named: "profile_default")
    }

    @Test func testProfileViewEmpty() {
        // Empty state: new user with no name set
        let view = ProfileViewPreview(
            name: "",
            initials: "",
            displayMode: .empty
        )

        SnapshotHarness.assertSnapshot(of: view, named: "profile_empty")
    }

    @Test func testProfileViewEditingName() {
        // Editing name mode: edit sheet shown with text field
        let view = ProfileViewPreview(
            name: "Brandon Kase",
            initials: "BK",
            displayMode: .editingName,
            editingNameText: "Brandon K"
        )

        SnapshotHarness.assertSnapshot(of: view, named: "profile_editing_name")
    }

    @Test func testProfileViewError() {
        // Error state: editing name with validation error
        let view = ProfileViewPreview(
            name: "Brandon Kase",
            initials: "BK",
            displayMode: .editingNameWithError,
            editingNameText: "",
            errorMessage: "Name cannot be empty"
        )

        SnapshotHarness.assertSnapshot(of: view, named: "profile_error")
    }
}
