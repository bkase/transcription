import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import PersonTimelineFeature

// MARK: - Person Timeline Catalog

extension CatalogBase {
    @Suite("Person Timeline")
    @MainActor
    struct PersonTimelineCatalog {

        @Test func testPersonTimelineDefault() {
            let view = PersonTimelineViewPreview(
                personName: "Sarah Chen",
                sessions: [
                    .init(title: "Architecture Review", time: "9:41 AM",
                          previewText: "So we're looking at the Vapor direction...",
                          speakerCount: 2, duration: "42:10"),
                    .init(title: "Morning Standup", time: "9:00 AM",
                          previewText: "Quick sync on sprint progress..."),
                    .init(title: "Product Strategy", time: "4:20 PM",
                          previewText: "If we pivot to a local-first model, the database sync...")
                ]
            )
            CatalogHarness.capture(of: view, named: "person_timeline_default",
                                   section: "Person Timeline", description: "Sessions filtered for a specific person.")
        }

        @Test func testPersonTimelineSingleSession() {
            let view = PersonTimelineViewPreview(
                personName: "Brandon Kase",
                sessions: [
                    .init(title: "Project Kickoff", time: "2:30 PM",
                          previewText: "Let's discuss the new feature implementation...",
                          speakerCount: 3, duration: "1:23:45")
                ]
            )
            CatalogHarness.capture(of: view, named: "person_timeline_single_session",
                                   section: "Person Timeline", description: "Single session for a person.")
        }

        @Test func testPersonTimelineEmpty() {
            let view = PersonTimelineViewPreview(personName: "New Contact", displayMode: .empty)
            CatalogHarness.capture(of: view, named: "person_timeline_empty",
                                   section: "Person Timeline", description: "Empty state, no sessions for this person.")
        }

        @Test func testPersonTimelineStatusPills() {
            let view = PersonTimelineViewPreview(
                personName: "Sarah Chen",
                sessions: [
                    .init(title: "Morning Call", time: "10:00 AM",
                          previewText: "Discussing project updates...",
                          statusPillType: .transcribing),
                    .init(title: "Afternoon Sync", time: "3:00 PM",
                          previewText: "Follow up on action items...",
                          statusPillType: .partial),
                    .init(title: "Evening Review", time: "6:00 PM",
                          previewText: "Final review of the day...",
                          statusPillType: .failed)
                ]
            )
            CatalogHarness.capture(of: view, named: "person_timeline_status_pills",
                                   section: "Person Timeline", description: "Sessions with transcribing, partial, and failed pills.")
        }
    }
}
