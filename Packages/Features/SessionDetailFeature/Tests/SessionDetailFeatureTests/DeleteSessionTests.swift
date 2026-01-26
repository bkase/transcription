import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
import Observability
import Export
@testable import SessionDetailFeature

private let testUUID = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000001")!

@MainActor
struct DeleteSessionTests {

    // MARK: - testDeleteRemovesSession

    @Test
    func testDeleteRemovesSession() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")
        let audioPath = "/audio/session-123.caf"

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Team Meeting",
            previewText: "Let's discuss the project",
            durationMs: 300000,
            audioPath: audioPath,
            processingState: .processed,
            speakerCount: 2,
            updatedAt: mockDate
        )

        var deletedSessionId: SessionID?
        var deletedFileURL: URL?

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.uuid = .constant(testUUID)
            $0.databaseClient.deleteSession = { id in
                deletedSessionId = id
            }
            $0.fileClient.exists = { url in
                return url.path == audioPath
            }
            $0.fileClient.delete = { url in
                deletedFileURL = url
            }
        }

        // Tap delete shows confirmation
        await store.send(.deleteTapped) {
            $0.isShowingDeleteConfirmation = true
        }

        // Confirm delete
        await store.send(.deleteConfirmed) {
            $0.isShowingDeleteConfirmation = false
            $0.isDeleting = true
        }

        // Receive completion
        await store.receive(\.deleteCompleted) {
            $0.isDeleting = false
        }

        // Verify database delete was called
        #expect(deletedSessionId == sessionID)

        // Verify audio file was deleted
        #expect(deletedFileURL?.path == audioPath)
    }

    // MARK: - testDeleteWithNoAudioFile

    @Test
    func testDeleteWithNoAudioFile() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-456")

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Quick Note",
            previewText: nil,
            durationMs: 60000,
            audioPath: nil, // No audio file
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        var deletedSessionId: SessionID?
        var fileDeleteCalled = false

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.uuid = .constant(testUUID)
            $0.databaseClient.deleteSession = { id in
                deletedSessionId = id
            }
            $0.fileClient.exists = { _ in
                false
            }
            $0.fileClient.delete = { _ in
                fileDeleteCalled = true
            }
        }

        // Tap delete shows confirmation
        await store.send(.deleteTapped) {
            $0.isShowingDeleteConfirmation = true
        }

        // Confirm delete
        await store.send(.deleteConfirmed) {
            $0.isShowingDeleteConfirmation = false
            $0.isDeleting = true
        }

        // Receive completion
        await store.receive(\.deleteCompleted) {
            $0.isDeleting = false
        }

        // Verify database delete was called
        #expect(deletedSessionId == sessionID)

        // File delete should not have been called since no audio path
        #expect(!fileDeleteCalled)
    }

    // MARK: - testDeleteCancelled

    @Test
    func testDeleteCancelled() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-789")

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Meeting",
            processingState: .processed,
            updatedAt: mockDate
        )

        var deleteWasCalled = false

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.deleteSession = { _ in
                deleteWasCalled = true
            }
        }

        // Tap delete shows confirmation
        await store.send(.deleteTapped) {
            $0.isShowingDeleteConfirmation = true
        }

        // Cancel delete
        await store.send(.deleteCancelled) {
            $0.isShowingDeleteConfirmation = false
        }

        // Verify delete was NOT called
        #expect(!deleteWasCalled)
    }

    // MARK: - testDeleteFailed

    @Test
    func testDeleteFailed() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-fail")

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Failing Session",
            processingState: .processed,
            updatedAt: mockDate
        )

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database error during delete" }
        }

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.uuid = .constant(testUUID)
            $0.databaseClient.deleteSession = { _ in
                throw TestError()
            }
            $0.fileClient.exists = { _ in false }
        }

        // Tap delete shows confirmation
        await store.send(.deleteTapped) {
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
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Data Error",
                message: "Database error during delete",
                primaryButton: AlertInfo.AlertButton(title: "Retry", action: .retry, isDestructive: false),
                secondaryButton: AlertInfo.AlertButton(title: "Cancel", action: .dismiss, isDestructive: false)
            )
        }
    }

    // MARK: - testDeleteAlertRetry

    @Test
    func testDeleteAlertRetry() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-retry")

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            processingState: .processed,
            updatedAt: mockDate
        )

        var deleteAttempts = 0

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession,
                alertInfo: AlertInfo(
                    id: testUUID.uuidString,
                    title: "Database Error",
                    message: "Failed",
                    primaryButton: AlertInfo.AlertButton(title: "Try Again", action: .retry, isDestructive: false),
                    secondaryButton: nil
                )
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.uuid = .constant(testUUID)
            $0.databaseClient.deleteSession = { _ in
                deleteAttempts += 1
            }
            $0.fileClient.exists = { _ in false }
        }

        // Tap retry clears alert and triggers deleteConfirmed
        await store.send(.alertActionTapped(.retry)) {
            $0.alertInfo = nil
        }

        // Should receive deleteConfirmed
        await store.receive(\.deleteConfirmed) {
            $0.isDeleting = true
        }

        // Should receive deleteCompleted
        await store.receive(\.deleteCompleted) {
            $0.isDeleting = false
        }

        #expect(deleteAttempts == 1)
    }

    // MARK: - testDeleteAlertDismiss

    @Test
    func testDeleteAlertDismiss() async {
        let sessionID = SessionID("session-dismiss")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                alertInfo: AlertInfo(
                    id: testUUID.uuidString,
                    title: "Error",
                    message: "Failed",
                    primaryButton: AlertInfo.AlertButton(title: "Dismiss", action: .dismiss, isDestructive: false),
                    secondaryButton: nil
                )
            )
        ) {
            SessionDetailFeature()
        }

        // Dismiss clears alert with no side effects
        await store.send(.alertActionTapped(.dismiss)) {
            $0.alertInfo = nil
        }
    }

    // MARK: - testAlertDismissed

    @Test
    func testAlertDismissed() async {
        let sessionID = SessionID("session-alert-dismiss")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                alertInfo: AlertInfo(
                    id: testUUID.uuidString,
                    title: "Error",
                    message: "Something went wrong",
                    primaryButton: AlertInfo.AlertButton(title: "OK", action: .dismiss, isDestructive: false),
                    secondaryButton: nil
                )
            )
        ) {
            SessionDetailFeature()
        }

        // Dismissing alert clears it
        await store.send(.alertDismissed) {
            $0.alertInfo = nil
        }
    }
}
