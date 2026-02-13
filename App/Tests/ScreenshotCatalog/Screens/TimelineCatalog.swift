import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import TimelineFeature

// MARK: - Timeline Catalog

extension CatalogBase {
    @Suite("Timeline")
    @MainActor
    struct TimelineCatalog {

        @Test func testTimelineGrouped() {
            let view = TimelineViewPreview(
                sections: [
                    .init(header: "TODAY", sessions: [
                        .init(title: "Architecture Review", time: "9:41 AM",
                              previewText: "So we're looking at the Vapor direction..."),
                        .init(title: "Morning Reflection", time: "7:30 AM",
                              previewText: "The light in the studio was particularly interesting this morning...")
                    ]),
                    .init(header: "YESTERDAY", sessions: [
                        .init(title: "Product Strategy", time: "4:20 PM",
                              previewText: "If we pivot to a local-first model, the database sync...")
                    ])
                ]
            )
            CatalogHarness.capture(of: view, named: "timeline_grouped",
                                   section: "Timeline", description: "Default grouped view with TODAY and YESTERDAY sections.")
        }

        @Test func testTimelineHoverState() {
            let view = TimelineViewPreview(
                sections: [
                    .init(header: "TODAY", sessions: [
                        .init(title: "Architecture Review", time: "9:41 AM",
                              previewText: "So we're looking at the Vapor direction...",
                              speakerCount: 2, duration: "42:10", showMetadata: true),
                        .init(title: "Morning Reflection", time: "7:30 AM",
                              previewText: "The light in the studio was particularly interesting this morning...")
                    ]),
                    .init(header: "YESTERDAY", sessions: [
                        .init(title: "Product Strategy", time: "4:20 PM",
                              previewText: "If we pivot to a local-first model, the database sync...")
                    ])
                ]
            )
            CatalogHarness.capture(of: view, named: "timeline_hover_state",
                                   section: "Timeline", description: "Card with metadata badges (speaker count, duration).")
        }

        @Test func testTimelineEmptyDownloading() {
            let view = TimelineViewPreview(displayMode: .emptyDownloading)
            CatalogHarness.capture(of: view, named: "timeline_empty_downloading",
                                   section: "Timeline", description: "Empty state while models are downloading.")
        }

        @Test func testTimelineEmptyError() {
            let view = TimelineViewPreview(displayMode: .emptyError)
            CatalogHarness.capture(of: view, named: "timeline_empty_error",
                                   section: "Timeline", description: "Empty state with download error.")
        }

        @Test func testTimelineEmptyReady() {
            let view = TimelineViewPreview(displayMode: .emptyReady)
            CatalogHarness.capture(of: view, named: "timeline_empty_ready",
                                   section: "Timeline", description: "Empty state ready to record.")
        }

        @Test func testTimelineSearchResults() {
            let view = TimelineViewPreview(
                displayMode: .searchResults(results: [
                    .init(title: "Morning Reflection", time: "7:30 AM",
                          previewText: "The light in the studio was particularly interesting this morning..."),
                    .init(title: "Evening Thoughts", time: "6:45 PM",
                          previewText: "Reflecting on the day's progress and tomorrow's goals...")
                ]),
                searchText: "morning"
            )
            CatalogHarness.capture(of: view, named: "timeline_search_results",
                                   section: "Timeline", description: "Search results matching query.")
        }

        @Test func testTimelineSearchNoResults() {
            let view = TimelineViewPreview(
                displayMode: .searchResults(results: []),
                searchText: "xyznonexistent"
            )
            CatalogHarness.capture(of: view, named: "timeline_search_no_results",
                                   section: "Timeline", description: "Search with no matching results.")
        }

        @Test func testTimelineSessionsDownloadError() {
            let view = TimelineViewPreview(
                displayMode: .sessionsWithDownloadError(sections: [
                    .init(header: "TODAY", sessions: [
                        .init(title: "Architecture Review", time: "9:41 AM",
                              previewText: "So we're looking at the Vapor direction..."),
                        .init(title: "Morning Reflection", time: "7:30 AM",
                              previewText: "The light in the studio was particularly interesting this morning...")
                    ])
                ])
            )
            CatalogHarness.capture(of: view, named: "timeline_sessions_download_error",
                                   section: "Timeline", description: "Sessions displayed with download error banner.")
        }

        @Test func testTimelineSessionsConnectionError() {
            let view = TimelineViewPreview(
                displayMode: .sessionsWithConnectionError(sections: [
                    .init(header: "TODAY", sessions: [
                        .init(title: "Architecture Review", time: "9:41 AM",
                              previewText: "So we're looking at the Vapor direction..."),
                        .init(title: "Morning Reflection", time: "7:30 AM",
                              previewText: "The light in the studio was particularly interesting this morning...")
                    ])
                ])
            )
            CatalogHarness.capture(of: view, named: "timeline_sessions_connection_error",
                                   section: "Timeline", description: "Sessions displayed with connection error banner.")
        }

        @Test func testTimelineSessionsStatusPills() {
            let view = TimelineViewPreview(
                sections: [
                    .init(header: "TODAY", sessions: [
                        .init(title: "Architecture Review", time: "9:41 AM",
                              previewText: "So we're looking at the Vapor direction...",
                              statusPillType: .transcribing),
                        .init(title: "Morning Reflection", time: "7:30 AM",
                              previewText: "The light in the studio was particularly interesting this morning...",
                              statusPillType: .partial)
                    ]),
                    .init(header: "YESTERDAY", sessions: [
                        .init(title: "Product Strategy", time: "4:20 PM",
                              previewText: "If we pivot to a local-first model, the database sync...",
                              statusPillType: .failed),
                        .init(title: "Evening Notes", time: "8:15 PM",
                              previewText: "Completed recordings display without status pill...")
                    ])
                ]
            )
            CatalogHarness.capture(of: view, named: "timeline_sessions_status_pills",
                                   section: "Timeline", description: "Sessions with transcribing, partial, and failed status pills.")
        }

        @Test func testTimelineSessionsSpeakerAvatars() {
            let view = TimelineViewPreview(
                sections: [
                    .init(header: "TODAY", sessions: [
                        .init(title: "Architecture Review", time: "9:41 AM",
                              previewText: "So we're looking at the Vapor direction...",
                              speakerAvatars: [
                                  SpeakerAvatarInfo(id: "1", initials: "SC", color: .sky),
                                  SpeakerAvatarInfo(id: "2", initials: "MK", color: .lavender)
                              ])
                    ])
                ]
            )
            CatalogHarness.capture(of: view, named: "timeline_sessions_speaker_avatars",
                                   section: "Timeline", description: "Sessions with speaker avatar circles.")
        }
    }
}
