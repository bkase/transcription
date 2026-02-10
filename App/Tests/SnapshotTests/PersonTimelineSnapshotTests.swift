import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import PersonTimelineFeature

// MARK: - Person Timeline View Snapshot Tests

@Suite("Person Timeline View Snapshots", .snapshots(record: SnapshotConfig.recordMode))
@MainActor
struct PersonTimelineSnapshotTests {

    @Test func testPersonTimelineDefault() {
        // Default state: sessions for a person displayed
        let view = PersonTimelineViewPreview(
            personName: "Sarah Chen",
            sessions: [
                .init(
                    title: "Architecture Review",
                    time: "9:41 AM",
                    previewText: "So we're looking at the Vapor direction...",
                    speakerCount: 2,
                    duration: "42:10"
                ),
                .init(
                    title: "Morning Standup",
                    time: "9:00 AM",
                    previewText: "Quick sync on sprint progress..."
                ),
                .init(
                    title: "Product Strategy",
                    time: "4:20 PM",
                    previewText: "If we pivot to a local-first model, the database sync..."
                )
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "person_timeline_default")
    }

    @Test func testPersonTimelineSingleSession() {
        // Single session for a person
        let view = PersonTimelineViewPreview(
            personName: "Brandon Kase",
            sessions: [
                .init(
                    title: "Project Kickoff",
                    time: "2:30 PM",
                    previewText: "Let's discuss the new feature implementation...",
                    speakerCount: 3,
                    duration: "1:23:45"
                )
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "person_timeline_single_session")
    }

    @Test func testPersonTimelineEmpty() {
        // Empty state: no sessions for this person yet
        let view = PersonTimelineViewPreview(
            personName: "New Contact",
            displayMode: .empty
        )

        SnapshotHarness.assertSnapshot(of: view, named: "person_timeline_empty")
    }

    @Test func testPersonTimelineWithStatusPills() {
        // Sessions with various processing status pills
        let view = PersonTimelineViewPreview(
            personName: "Sarah Chen",
            sessions: [
                .init(
                    title: "Morning Call",
                    time: "10:00 AM",
                    previewText: "Discussing project updates...",
                    statusPillType: .transcribing
                ),
                .init(
                    title: "Afternoon Sync",
                    time: "3:00 PM",
                    previewText: "Follow up on action items...",
                    statusPillType: .partial
                ),
                .init(
                    title: "Evening Review",
                    time: "6:00 PM",
                    previewText: "Final review of the day...",
                    statusPillType: .failed
                )
            ]
        )

        SnapshotHarness.assertSnapshot(of: view, named: "person_timeline_status_pills")
    }
}
