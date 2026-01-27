import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import SessionDetailFeature

@MainActor
struct SessionDetailTitleEditingTests {

    // MARK: - Test Data

    private let mockDate = Date(timeIntervalSince1970: 1000000)

    private func mockSession(id: String = "session-123", title: String? = "Original Title") -> SessionRecord {
        SessionRecord(
            id: id,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: title,
            previewText: "Some preview text",
            durationMs: 300000,
            audioPath: nil,
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )
    }

    // MARK: - testTitleTappedStartsEditing

    @Test
    func testTitleTappedStartsEditing() async {
        let sessionID = SessionID("session-123")
        let session = mockSession()

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session
            )
        ) {
            SessionDetailFeature()
        }

        #expect(store.state.isEditingTitle == false)
        #expect(store.state.editedTitle == "")

        await store.send(.titleTapped) {
            $0.isEditingTitle = true
            $0.editedTitle = "Original Title"
        }
    }

    // MARK: - testTitleTappedWithNilTitle

    @Test
    func testTitleTappedWithNilTitle() async {
        let sessionID = SessionID("session-123")
        let session = mockSession(title: nil)

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session
            )
        ) {
            SessionDetailFeature()
        }

        await store.send(.titleTapped) {
            $0.isEditingTitle = true
            $0.editedTitle = ""
        }
    }

    // MARK: - testTitleChanged

    @Test
    func testTitleChanged() async {
        let sessionID = SessionID("session-123")
        let session = mockSession()

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session,
                isEditingTitle: true,
                editedTitle: "Original Title"
            )
        ) {
            SessionDetailFeature()
        }

        await store.send(.titleChanged("New Title")) {
            $0.editedTitle = "New Title"
        }
    }

    // MARK: - testSaveTitleUpdatesSessionAndDatabase

    @Test
    func testSaveTitleUpdatesSessionAndDatabase() async {
        let sessionID = SessionID("session-123")
        var session = mockSession()

        var updatedSession: SessionRecord?

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session,
                isEditingTitle: true,
                editedTitle: "New Title"
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.updateSession = { s in
                updatedSession = s
            }
        }

        await store.send(.saveTitle) {
            $0.isEditingTitle = false
            $0.session?.title = "New Title"
        }

        await store.receive(\.titleSaved)

        // Verify database was called with correct data
        #expect(updatedSession != nil)
        #expect(updatedSession?.title == "New Title")
    }

    // MARK: - testSaveTitleWithEmptyStringSetsNil

    @Test
    func testSaveTitleWithEmptyStringSetsNil() async {
        let sessionID = SessionID("session-123")
        let session = mockSession()

        var updatedSession: SessionRecord?

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session,
                isEditingTitle: true,
                editedTitle: ""
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.updateSession = { s in
                updatedSession = s
            }
        }

        await store.send(.saveTitle) {
            $0.isEditingTitle = false
            $0.session?.title = nil
        }

        await store.receive(\.titleSaved)

        #expect(updatedSession?.title == nil)
    }

    // MARK: - testSaveTitleWithWhitespaceSetsNil

    @Test
    func testSaveTitleWithWhitespaceSetsNil() async {
        let sessionID = SessionID("session-123")
        let session = mockSession()

        var updatedSession: SessionRecord?

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session,
                isEditingTitle: true,
                editedTitle: "   "
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.updateSession = { s in
                updatedSession = s
            }
        }

        await store.send(.saveTitle) {
            $0.isEditingTitle = false
            $0.session?.title = nil
        }

        await store.receive(\.titleSaved)

        #expect(updatedSession?.title == nil)
    }

    // MARK: - testCancelTitleEdit

    @Test
    func testCancelTitleEdit() async {
        let sessionID = SessionID("session-123")
        let session = mockSession()

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session,
                isEditingTitle: true,
                editedTitle: "Modified but not saved"
            )
        ) {
            SessionDetailFeature()
        }

        await store.send(.cancelTitleEdit) {
            $0.isEditingTitle = false
            $0.editedTitle = ""
        }

        // Original title should be unchanged
        #expect(store.state.session?.title == "Original Title")
    }

    // MARK: - testTitleSaveFailure

    @Test
    func testTitleSaveFailure() async {
        let sessionID = SessionID("session-123")
        let session = mockSession()

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database write failed" }
        }

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session,
                isEditingTitle: true,
                editedTitle: "New Title"
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.updateSession = { _ in
                throw TestError()
            }
            // Mock for reloading session after failure
            $0.databaseClient.fetchSession = { _ in session }
            $0.databaseClient.fetchTranscriptSegments = { _ in [] }
            $0.databaseClient.fetchSpeakerTracks = { _ in [] }
            $0.databaseClient.fetchPeople = { [] }
        }

        await store.send(.saveTitle) {
            $0.isEditingTitle = false
            $0.session?.title = "New Title"
        }

        // Receive failure, which triggers reload
        await store.receive(\.titleSaveFailed) {
            $0.error = "Database write failed"
        }

        // Receive loadSession from the reload - error gets cleared here
        await store.receive(\.loadSession) {
            $0.isLoading = true
            $0.error = nil  // loadSession clears error
        }

        // Session reloads with original data
        await store.receive(\.sessionLoaded) {
            $0.isLoading = false
            $0.session = session
            $0.segments = []
            $0.speakerTracks = []
        }
    }

    // MARK: - testTitleTappedWhileEditingIsIgnored

    @Test
    func testTitleTappedWhileEditingIsIgnored() async {
        let sessionID = SessionID("session-123")
        let session = mockSession()

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: session,
                isEditingTitle: true,
                editedTitle: "Editing in progress"
            )
        ) {
            SessionDetailFeature()
        }

        // Tapping title while already editing should be ignored
        await store.send(.titleTapped)
    }

    // MARK: - testSaveTitleWithoutSessionIsIgnored

    @Test
    func testSaveTitleWithoutSessionIsIgnored() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: nil,
                isEditingTitle: true,
                editedTitle: "New Title"
            )
        ) {
            SessionDetailFeature()
        }

        // Save without a session should be ignored
        await store.send(.saveTitle)
    }
}
