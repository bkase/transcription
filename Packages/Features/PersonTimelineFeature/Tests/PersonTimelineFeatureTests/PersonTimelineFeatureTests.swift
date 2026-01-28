import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import PersonTimelineFeature

@MainActor
struct PersonTimelineFeatureTests {

    // MARK: - testLoadSessions

    @Test
    func testLoadSessions() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockSessions = [
            SessionRecord(
                id: "session-1",
                startedAt: mockDate,
                endedAt: mockDate,
                title: "Meeting with Sarah",
                previewText: "Discussing the project...",
                durationMs: 3600000,
                processingState: .processed,
                speakerCount: 2,
                updatedAt: mockDate
            ),
            SessionRecord(
                id: "session-2",
                startedAt: mockDate,
                endedAt: mockDate,
                title: "Follow-up",
                previewText: "Quick sync...",
                durationMs: 1800000,
                processingState: .processed,
                speakerCount: 2,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: PersonTimelineFeature.State(
                personId: PersonID("person-1"),
                personName: "Sarah Chen"
            )
        ) {
            PersonTimelineFeature()
        } withDependencies: {
            $0.databaseClient.fetchSessionsForPerson = { _ in mockSessions }
        }

        // onAppear triggers loadSessions
        await store.send(.onAppear)

        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessions = mockSessions
        }
    }

    // MARK: - testLoadSessionsError

    @Test
    func testLoadSessionsError() async {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database error" }
        }

        let store = TestStore(
            initialState: PersonTimelineFeature.State(
                personId: PersonID("person-1"),
                personName: "Sarah Chen"
            )
        ) {
            PersonTimelineFeature()
        } withDependencies: {
            $0.databaseClient.fetchSessionsForPerson = { _ in
                throw TestError()
            }
        }

        await store.send(.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.loadFailed) {
            $0.isLoading = false
            $0.error = "Database error"
        }
    }

    // MARK: - testOnAppearDoesNotReloadIfAlreadyLoaded

    @Test
    func testOnAppearDoesNotReloadIfAlreadyLoaded() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let existingSessions = [
            SessionRecord(
                id: "session-1",
                startedAt: mockDate,
                endedAt: mockDate,
                title: "Meeting",
                processingState: .processed,
                speakerCount: 2,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: PersonTimelineFeature.State(
                personId: PersonID("person-1"),
                personName: "Sarah Chen",
                sessions: existingSessions
            )
        ) {
            PersonTimelineFeature()
        } withDependencies: {
            $0.databaseClient.fetchSessionsForPerson = { _ in
                Issue.record("Should not reload when sessions already exist")
                return []
            }
        }

        // onAppear should not trigger reload when sessions already exist
        await store.send(.onAppear)
    }

    // MARK: - testSessionTappedIsNavigationIntent

    @Test
    func testSessionTappedIsNavigationIntent() async {
        let store = TestStore(
            initialState: PersonTimelineFeature.State(
                personId: PersonID("person-1"),
                personName: "Sarah Chen"
            )
        ) {
            PersonTimelineFeature()
        }

        // sessionTapped is a navigation intent - no state change expected
        await store.send(.sessionTapped(SessionID("session-1")))
    }

    // MARK: - testBackTappedIsNavigationIntent

    @Test
    func testBackTappedIsNavigationIntent() async {
        let store = TestStore(
            initialState: PersonTimelineFeature.State(
                personId: PersonID("person-1"),
                personName: "Sarah Chen"
            )
        ) {
            PersonTimelineFeature()
        }

        // backTapped is a navigation intent - no state change expected
        await store.send(.backTapped)
    }

    // MARK: - testAvatarTappedIsNavigationIntent

    @Test
    func testAvatarTappedIsNavigationIntent() async {
        let store = TestStore(
            initialState: PersonTimelineFeature.State(
                personId: PersonID("person-1"),
                personName: "Sarah Chen"
            )
        ) {
            PersonTimelineFeature()
        }

        // avatarTapped is a navigation intent - no state change expected
        await store.send(.avatarTapped)
    }
}
