import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import PeopleFeature

// MARK: - People View Snapshot Tests

@Suite("People View Snapshots")
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
