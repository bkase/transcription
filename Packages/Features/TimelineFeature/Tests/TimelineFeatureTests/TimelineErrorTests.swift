import Testing
import Foundation
import ComposableArchitecture
import Models
import Observability
import Persistence
@testable import TimelineFeature

// Test UUID for deterministic alert IDs
private let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

@MainActor
struct TimelineErrorTests {

    // MARK: - testErrorAlertShown

    @Test
    func testErrorAlertShown() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database connection failed" }
        }

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.uuid = .constant(testUUID)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in
                throw TestError()
            }
        }

        // Initially no alert
        #expect(store.state.alertInfo == nil)

        await store.send(.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.sessionsFailed) {
            $0.isLoading = false
            $0.error = "Database connection failed"
            // Alert should be shown with database read error
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Data Error",
                message: "Database connection failed",
                primaryButton: .init(title: "Retry", action: .retry),
                secondaryButton: .init(title: "Cancel", action: .dismiss)
            )
        }
    }

    // MARK: - testAlertDismissedClearsAlert

    @Test
    func testAlertDismissedClearsAlert() async {
        // Create an alert info
        let alertInfo = AlertInfo(
            id: testUUID.uuidString,
            title: "Test Error",
            message: "Test message",
            primaryButton: .init(title: "OK", action: .dismiss)
        )

        let store = TestStore(
            initialState: TimelineFeature.State(alertInfo: alertInfo)
        ) {
            TimelineFeature()
        }

        // Alert is present
        #expect(store.state.alertInfo != nil)

        // Dismiss the alert
        await store.send(.alertDismissed) {
            $0.alertInfo = nil
        }
    }

    // MARK: - testAlertRetryTriggersReload

    @Test
    func testAlertRetryTriggersReload() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockGroups = [
            SessionGroup(bucket: .today, sessions: [
                SessionRecord(
                    id: "session-1",
                    startedAt: mockDate,
                    title: "Test Session",
                    previewText: "Hello world",
                    processingState: .processed,
                    speakerCount: 2,
                    updatedAt: mockDate
                )
            ])
        ]

        // Start with an alert showing
        let alertInfo = AlertInfo(
            id: testUUID.uuidString,
            title: "Data Error",
            message: "Unable to load data",
            primaryButton: .init(title: "Retry", action: .retry),
            secondaryButton: .init(title: "Cancel", action: .dismiss)
        )

        let store = TestStore(
            initialState: TimelineFeature.State(alertInfo: alertInfo)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in mockGroups }
            $0.databaseClient.fetchSpeakerInfoForSessions = { _ in [:] }
        }

        // Tap retry
        await store.send(.alertActionTapped(.retry)) {
            $0.alertInfo = nil
        }

        // Should trigger loadSessions
        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessionGroups = mockGroups
            $0.speakerInfoBySession = [:]
        }
    }

    // MARK: - testSearchErrorShowsAlert

    @Test
    func testSearchErrorShowsAlert() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Search index corrupted" }
        }

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.uuid = .constant(testUUID)
            $0.databaseClient.searchSessionsWithDetails = { _ in
                throw TestError()
            }
        }

        // Initially no alert
        #expect(store.state.alertInfo == nil)

        await store.send(.searchQueryChanged("test")) {
            $0.searchQuery = "test"
        }

        await store.receive(\.sessionsFailed) {
            $0.error = "Search index corrupted"
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Data Error",
                message: "Search index corrupted",
                primaryButton: .init(title: "Retry", action: .retry),
                secondaryButton: .init(title: "Cancel", action: .dismiss)
            )
        }
    }
}
