import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import TimelineFeature

// MARK: - Timeline View Snapshot Tests

@Suite("Timeline View Snapshots")
@MainActor
struct TimelineViewSnapshotTests {

    @Test func testTimelineDefault() {
        // Default state: sessions displayed without hover metadata
        let view = TimelineViewPreview(
            sections: [
                .init(
                    header: "TODAY",
                    sessions: [
                        .init(
                            title: "Architecture Review",
                            time: "9:41 AM",
                            previewText: "So we're looking at the Vapor direction..."
                        ),
                        .init(
                            title: "Morning Reflection",
                            time: "7:30 AM",
                            previewText: "The light in the studio was particularly interesting this morning..."
                        )
                    ]
                ),
                .init(
                    header: "YESTERDAY",
                    sessions: [
                        .init(
                            title: "Product Strategy",
                            time: "4:20 PM",
                            previewText: "If we pivot to a local-first model, the database sync..."
                        )
                    ]
                )
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_default")
    }

    @Test func testTimelineHoverState() {
        // Hover state: first card shows metadata badges
        let view = TimelineViewPreview(
            sections: [
                .init(
                    header: "TODAY",
                    sessions: [
                        .init(
                            title: "Architecture Review",
                            time: "9:41 AM",
                            previewText: "So we're looking at the Vapor direction...",
                            speakerCount: 2,
                            duration: "42:10",
                            showMetadata: true
                        ),
                        .init(
                            title: "Morning Reflection",
                            time: "7:30 AM",
                            previewText: "The light in the studio was particularly interesting this morning..."
                        )
                    ]
                ),
                .init(
                    header: "YESTERDAY",
                    sessions: [
                        .init(
                            title: "Product Strategy",
                            time: "4:20 PM",
                            previewText: "If we pivot to a local-first model, the database sync..."
                        )
                    ]
                )
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_hover_state")
    }

    @Test func testTimelineEmptyDownloading() {
        // Empty state: downloading models
        let view = TimelineViewPreview(displayMode: .emptyDownloading)

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_empty_downloading")
    }

    @Test func testTimelineEmptyError() {
        // Empty state: error downloading models
        let view = TimelineViewPreview(displayMode: .emptyError)

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_empty_error")
    }

    @Test func testTimelineEmptyReady() {
        // Empty state: ready to record
        let view = TimelineViewPreview(displayMode: .emptyReady)

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_empty_ready")
    }

    @Test func testTimelineSearchResults() {
        // Search results: matching sessions displayed under RESULTS header
        let view = TimelineViewPreview(
            displayMode: .searchResults(results: [
                .init(
                    title: "Morning Reflection",
                    time: "7:30 AM",
                    previewText: "The light in the studio was particularly interesting this morning..."
                ),
                .init(
                    title: "Evening Thoughts",
                    time: "6:45 PM",
                    previewText: "Reflecting on the day's progress and tomorrow's goals..."
                )
            ]),
            searchText: "morning"
        )

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_search_results")
    }
}
