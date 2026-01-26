import Testing
import Foundation
import ComposableArchitecture
import Models
import Observability
import Persistence
import Export
import Processing
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

        // Start with models already ready to isolate session loading behavior
        let store = TestStore(initialState: TimelineFeature.State(modelPreparationState: .ready)) {
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
        // Models must be ready for newRecordingTapped to work
        let store = TestStore(initialState: TimelineFeature.State(modelPreparationState: .ready)) {
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

        // Start with sessions AND models ready to ensure onAppear is a no-op
        let store = TestStore(
            initialState: TimelineFeature.State(
                sessionGroups: existingGroups,
                modelPreparationState: .ready
            )
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

    // MARK: - Delete Tests

    @Test
    func testDeleteSessionFromTimeline() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let session1 = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            title: "Session 1",
            previewText: "First session",
            durationMs: 60000,
            audioPath: "/audio/session-1.caf",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let session2 = SessionRecord(
            id: "session-2",
            startedAt: mockDate.addingTimeInterval(-3600),
            title: "Session 2",
            previewText: "Second session",
            durationMs: 45000,
            processingState: .processed,
            speakerCount: 2,
            updatedAt: mockDate
        )

        let mockGroups = [
            SessionGroup(bucket: .today, sessions: [session1, session2])
        ]

        var deletedSessionId: SessionID?

        let store = TestStore(
            initialState: TimelineFeature.State(sessionGroups: mockGroups)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.uuid = .constant(testUUID)
            $0.databaseClient.deleteSession = { id in
                deletedSessionId = id
            }
            $0.fileClient.exists = { url in
                return url.path == "/audio/session-1.caf"
            }
            $0.fileClient.delete = { _ in }
        }

        // Tap delete on session 1
        await store.send(.deleteSessionTapped(session1)) {
            $0.sessionToDelete = session1
            $0.isShowingDeleteConfirmation = true
        }

        // Confirm delete
        await store.send(.deleteConfirmed) {
            $0.isShowingDeleteConfirmation = false
            $0.isDeleting = true
        }

        // Receive completion - session removed from groups
        await store.receive(\.deleteCompleted) {
            $0.isDeleting = false
            $0.sessionToDelete = nil
            // Session 1 should be removed from the group
            $0.sessionGroups = [
                SessionGroup(bucket: .today, sessions: [session2])
            ]
        }

        #expect(deletedSessionId == SessionID("session-1"))
    }

    @Test
    func testDeleteLastSessionRemovesGroup() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let session = SessionRecord(
            id: "session-only",
            startedAt: mockDate,
            title: "Only Session",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let mockGroups = [
            SessionGroup(bucket: .today, sessions: [session])
        ]

        let store = TestStore(
            initialState: TimelineFeature.State(sessionGroups: mockGroups)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.deleteSession = { _ in }
            $0.fileClient.exists = { _ in false }
        }

        // Tap delete
        await store.send(.deleteSessionTapped(session)) {
            $0.sessionToDelete = session
            $0.isShowingDeleteConfirmation = true
        }

        // Confirm delete
        await store.send(.deleteConfirmed) {
            $0.isShowingDeleteConfirmation = false
            $0.isDeleting = true
        }

        // Receive completion - group should be removed since it's now empty
        await store.receive(\.deleteCompleted) {
            $0.isDeleting = false
            $0.sessionToDelete = nil
            $0.sessionGroups = [] // Group removed because it's empty
        }
    }

    @Test
    func testDeleteCancelledDoesNotRemoveSession() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            title: "Test Session",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let mockGroups = [
            SessionGroup(bucket: .today, sessions: [session])
        ]

        var deleteWasCalled = false

        let store = TestStore(
            initialState: TimelineFeature.State(sessionGroups: mockGroups)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.databaseClient.deleteSession = { _ in
                deleteWasCalled = true
            }
        }

        // Tap delete
        await store.send(.deleteSessionTapped(session)) {
            $0.sessionToDelete = session
            $0.isShowingDeleteConfirmation = true
        }

        // Cancel delete
        await store.send(.deleteCancelled) {
            $0.isShowingDeleteConfirmation = false
            $0.sessionToDelete = nil
        }

        // Verify delete was NOT called and sessions are unchanged
        #expect(!deleteWasCalled)
        #expect(store.state.sessionGroups.count == 1)
        #expect(store.state.sessionGroups[0].sessions.count == 1)
    }

    @Test
    func testDeleteFailedShowsAlert() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            title: "Test Session",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let mockGroups = [
            SessionGroup(bucket: .today, sessions: [session])
        ]

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Delete failed" }
        }

        let store = TestStore(
            initialState: TimelineFeature.State(sessionGroups: mockGroups)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.uuid = .constant(testUUID)
            $0.databaseClient.deleteSession = { _ in
                throw TestError()
            }
            $0.fileClient.exists = { _ in false }
        }

        // Tap delete
        await store.send(.deleteSessionTapped(session)) {
            $0.sessionToDelete = session
            $0.isShowingDeleteConfirmation = true
        }

        // Confirm delete
        await store.send(.deleteConfirmed) {
            $0.isShowingDeleteConfirmation = false
            $0.isDeleting = true
        }

        // Receive failure with alert
        await store.receive(\.deleteFailed) {
            $0.isDeleting = false
            $0.sessionToDelete = nil
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Data Error",
                message: "Delete failed",
                primaryButton: AlertInfo.AlertButton(title: "Retry", action: .retry, isDestructive: false),
                secondaryButton: AlertInfo.AlertButton(title: "Cancel", action: .dismiss, isDestructive: false)
            )
        }

        // Session should still be in groups
        #expect(store.state.sessionGroups[0].sessions.count == 1)
    }

    @Test
    func testDeleteRemovesFromSearchResults() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            title: "Test Session",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let store = TestStore(
            initialState: TimelineFeature.State(
                searchQuery: "test",
                sessionGroups: [SessionGroup(bucket: .today, sessions: [session])],
                searchResults: [session]
            )
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(mockDate)
            $0.databaseClient.deleteSession = { _ in }
            $0.fileClient.exists = { _ in false }
        }

        // Tap delete
        await store.send(.deleteSessionTapped(session)) {
            $0.sessionToDelete = session
            $0.isShowingDeleteConfirmation = true
        }

        // Confirm delete
        await store.send(.deleteConfirmed) {
            $0.isShowingDeleteConfirmation = false
            $0.isDeleting = true
        }

        // Receive completion - removed from both groups and search results
        await store.receive(\.deleteCompleted) {
            $0.isDeleting = false
            $0.sessionToDelete = nil
            $0.sessionGroups = []
            $0.searchResults = []
        }
    }
}
