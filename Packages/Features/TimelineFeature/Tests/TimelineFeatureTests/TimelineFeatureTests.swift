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
            SessionRecord(
                id: "session-1",
                startedAt: mockDate,
                endedAt: nil,
                title: "Swift Talk",
                previewText: "Discussing swift programming",
                durationMs: 30000,
                audioPath: nil,
                processingState: .processed,
                speakerCount: 1,
                updatedAt: mockDate
            ),
            SessionRecord(
                id: "session-2",
                startedAt: mockDate.addingTimeInterval(-3600),
                endedAt: nil,
                title: "More Swift",
                previewText: "Swift is great",
                durationMs: 45000,
                audioPath: nil,
                processingState: .processed,
                speakerCount: 2,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.searchSessionsWithDetails = { query in
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

    // MARK: - testSearchFiltersSessions

    @Test
    func testSearchFiltersSessions() async {
        // This test verifies that FTS search filters sessions to only show matches.
        // When a user types "swift", only sessions with "swift" in transcripts are shown.
        let mockDate = Date(timeIntervalSince1970: 1000000)

        // Full timeline has 3 sessions
        let allSessions = [
            SessionRecord(
                id: "session-swift-1",
                startedAt: mockDate,
                title: "Swift Discussion",
                previewText: "Learning swift programming",
                processingState: .processed,
                speakerCount: 2,
                updatedAt: mockDate
            ),
            SessionRecord(
                id: "session-python",
                startedAt: mockDate.addingTimeInterval(-3600),
                title: "Python Tutorial",
                previewText: "Python basics",
                processingState: .processed,
                speakerCount: 1,
                updatedAt: mockDate
            ),
            SessionRecord(
                id: "session-swift-2",
                startedAt: mockDate.addingTimeInterval(-7200),
                title: "More Swift",
                previewText: "Swift advanced topics",
                processingState: .processed,
                speakerCount: 1,
                updatedAt: mockDate
            )
        ]

        let allGroups = [
            SessionGroup(bucket: .today, sessions: allSessions)
        ]

        // Search for "swift" returns only matching sessions (filtered)
        let swiftSearchResults = [
            allSessions[0], // session-swift-1
            allSessions[2]  // session-swift-2
        ]

        let store = TestStore(
            initialState: TimelineFeature.State(sessionGroups: allGroups)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.searchSessionsWithDetails = { query in
                #expect(query == "swift")
                // Return only sessions that match "swift"
                return swiftSearchResults
            }
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in allGroups }
        }

        // Verify initial state has all sessions
        #expect(store.state.sessionGroups.flatMap(\.sessions).count == 3)
        #expect(!store.state.isSearching)

        // User searches for "swift"
        await store.send(.searchQueryChanged("swift")) {
            $0.searchQuery = "swift"
        }

        // Search returns filtered results
        await store.receive(\.searchPerformed) {
            $0.searchResults = swiftSearchResults
        }

        // Verify search state - only 2 sessions in results
        #expect(store.state.isSearching)
        #expect(store.state.searchResults.count == 2)
        #expect(store.state.searchResults.allSatisfy { $0.id.contains("swift") })

        // Session groups are still available but view would display searchResults
        #expect(store.state.sessionGroups.flatMap(\.sessions).count == 3)
    }

    // MARK: - testSearchClearReloadsSessions

    @Test
    func testSearchClearReloadsSessions() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockGroups: [SessionGroup] = []
        let existingSearchResults = [
            SessionRecord(
                id: "session-1",
                startedAt: mockDate,
                endedAt: nil,
                title: "Test Session",
                previewText: "Test content",
                durationMs: 60000,
                audioPath: nil,
                processingState: .processed,
                speakerCount: 1,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(
            initialState: TimelineFeature.State(
                searchQuery: "existing",
                searchResults: existingSearchResults
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
            $0.uuid = .constant(testUUID)
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
