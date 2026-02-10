import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import TimelineFeature

// MARK: - Timeline View Snapshot Tests

@Suite("Timeline View Snapshots", .snapshots(record: SnapshotConfig.recordMode))
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

    // MARK: - Sessions with Error Banner Tests

    @Test func testTimelineSessionsWithDownloadError() {
        // Sessions displayed with download error banner at top
        let view = TimelineViewPreview(
            displayMode: .sessionsWithDownloadError(sections: [
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
            ])
        )

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_sessions_download_error")
    }

    @Test func testTimelineSessionsWithConnectionError() {
        // Sessions displayed with connection error banner at top
        let view = TimelineViewPreview(
            displayMode: .sessionsWithConnectionError(sections: [
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
            ])
        )

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_sessions_connection_error")
    }

    // MARK: - Session Card with Status Pill Tests

    @Test func testTimelineSessionsWithStatusPills() {
        // Sessions with various processing status pills
        let view = TimelineViewPreview(
            sections: [
                .init(
                    header: "TODAY",
                    sessions: [
                        .init(
                            title: "Architecture Review",
                            time: "9:41 AM",
                            previewText: "So we're looking at the Vapor direction...",
                            statusPillType: .transcribing
                        ),
                        .init(
                            title: "Morning Reflection",
                            time: "7:30 AM",
                            previewText: "The light in the studio was particularly interesting this morning...",
                            statusPillType: .partial
                        )
                    ]
                ),
                .init(
                    header: "YESTERDAY",
                    sessions: [
                        .init(
                            title: "Product Strategy",
                            time: "4:20 PM",
                            previewText: "If we pivot to a local-first model, the database sync...",
                            statusPillType: .failed
                        ),
                        .init(
                            title: "Evening Notes",
                            time: "8:15 PM",
                            previewText: "Completed recordings display without status pill..."
                        )
                    ]
                )
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_sessions_status_pills")
    }

    @Test func testTimelineSessionsWithSpeakerAvatars() {
        // Sessions with speaker avatars on the right side near time
        let view = TimelineViewPreview(
            sections: [
                .init(
                    header: "TODAY",
                    sessions: [
                        .init(
                            title: "Architecture Review",
                            time: "9:41 AM",
                            previewText: "So we're looking at the Vapor direction...",
                            speakerAvatars: [
                                SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky),
                                SpeakerAvatarInfo(id: "2", initials: "MK", color: .lavender)
                            ]
                        ),
                        .init(
                            title: "Morning Reflection",
                            time: "7:30 AM",
                            previewText: "The light in the studio was particularly interesting this morning...",
                            speakerAvatars: [
                                SpeakerAvatarInfo(id: "3", initials: "JS", color: .deep)
                            ]
                        )
                    ]
                ),
                .init(
                    header: "YESTERDAY",
                    sessions: [
                        .init(
                            title: "Product Strategy",
                            time: "4:20 PM",
                            previewText: "If we pivot to a local-first model, the database sync...",
                            statusPillType: .partial,
                            speakerAvatars: [
                                SpeakerAvatarInfo(id: "4", initials: "AL", color: .dusk),
                                SpeakerAvatarInfo(id: "5", initials: "BK", color: .sky)
                            ]
                        )
                    ]
                )
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "timeline_sessions_speaker_avatars")
    }
}
