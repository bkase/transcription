import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import TimelineFeature

@MainActor
struct TimelineFeatureTests {

    // MARK: - testLoadSessions

    @Test
    func testLoadSessions() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockSessions = [
            SessionRecord(
                id: "session-1",
                startedAt: mockDate,
                endedAt: nil,
                title: "Test Session",
                previewText: "Hello world",
                durationMs: 60000,
                audioPath: nil,
                processingState: .processed,
                speakerCount: 2,
                updatedAt: mockDate
            )
        ]
        let mockGroups = [
            SessionGroup(bucket: .today, sessions: mockSessions)
        ]

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in mockGroups }
        }

        // onAppear should trigger loadSessions (no immediate state change)
        await store.send(.onAppear)

        // loadSessions is sent next
        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        // Receive the loaded sessions
        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessionGroups = mockGroups
        }
    }

    // MARK: - testSearchUpdatesQuery

    @Test
    func testSearchUpdatesQuery() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockSearchResults = [
            SessionSearchResult(sessionId: SessionID("session-1"), rank: 5.0),
            SessionSearchResult(sessionId: SessionID("session-2"), rank: 3.0)
        ]

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.searchSessions = { query in
                #expect(query == "hello")
                return mockSearchResults
            }
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
        }

        // Change search query to non-empty value
        await store.send(.searchQueryChanged("hello")) {
            $0.searchQuery = "hello"
        }

        // Receive search results
        await store.receive(\.searchPerformed) {
            $0.searchResults = mockSearchResults
        }
    }

    // MARK: - testSearchClearReloadsSessions

    @Test
    func testSearchClearReloadsSessions() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockGroups: [SessionGroup] = []

        let store = TestStore(
            initialState: TimelineFeature.State(
                searchQuery: "existing",
                searchResults: [
                    SessionSearchResult(sessionId: SessionID("session-1"), rank: 1.0)
                ]
            )
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in mockGroups }
        }

        // Clear search query
        await store.send(.searchQueryChanged("")) {
            $0.searchQuery = ""
            $0.searchResults = []
        }

        // Should trigger loadSessions
        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessionGroups = mockGroups
        }
    }

    // MARK: - testSessionsLoadError

    @Test
    func testSessionsLoadError() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database connection failed" }
        }

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in
                throw TestError()
            }
        }

        await store.send(.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.sessionsFailed) {
            $0.isLoading = false
            $0.error = "Database connection failed"
        }
    }

    // MARK: - testNavigationIntents

    @Test
    func testSessionTappedIsNavigationIntent() async {
        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        }

        // sessionTapped is a navigation intent - no state change expected
        await store.send(.sessionTapped(SessionID("session-1")))
    }

    @Test
    func testNewRecordingTappedIsNavigationIntent() async {
        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        }

        // newRecordingTapped is a navigation intent - no state change expected
        await store.send(.newRecordingTapped)
    }

    // MARK: - testOnAppearDoesNotReloadIfAlreadyLoaded

    @Test
    func testOnAppearDoesNotReloadIfAlreadyLoaded() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let existingGroups = [
            SessionGroup(bucket: .today, sessions: [
                SessionRecord(
                    id: "session-1",
                    startedAt: mockDate,
                    endedAt: nil,
                    title: nil,
                    previewText: nil,
                    durationMs: nil,
                    audioPath: nil,
                    processingState: .recording,
                    speakerCount: 0,
                    updatedAt: mockDate
                )
            ])
        ]

        let store = TestStore(
            initialState: TimelineFeature.State(sessionGroups: existingGroups)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            // Should never be called since sessions already loaded
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in
                Issue.record("Should not reload when sessions already exist")
                return []
            }
        }

        // onAppear should not trigger reload when sessions already exist
        await store.send(.onAppear)
    }
}
