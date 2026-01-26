import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import SessionDetailFeature

@MainActor
struct SessionActionsMenuTests {

    // MARK: - testActionsMenuOptions

    @Test
    func testActionsMenuOptions() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        }

        // Verify initial state
        #expect(store.state.isShowingActionsMenu == false)

        // Tap more button to show actions menu
        await store.send(.moreButtonTapped) {
            $0.isShowingActionsMenu = true
        }

        // Dismiss menu
        await store.send(.actionsMenuDismissed) {
            $0.isShowingActionsMenu = false
        }
    }

    // MARK: - testShareActionFromMenu

    @Test
    func testShareActionFromMenu() async {
        let sessionID = SessionID("session-123")
        let exportURL = URL(fileURLWithPath: "/tmp/export.zip")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                isShowingActionsMenu: true
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.exportClient.exportBundle = { _ in exportURL }
        }

        // Tap share in menu - dismisses menu and starts export
        await store.send(.shareTapped) {
            $0.isShowingActionsMenu = false
            $0.isExporting = true
        }

        // Export completes
        await store.receive(\.exportCompleted) {
            $0.isExporting = false
            $0.shareURL = exportURL
        }
    }

    // MARK: - testExportActionFromMenu

    @Test
    func testExportActionFromMenu() async {
        let sessionID = SessionID("session-123")
        let exportURL = URL(fileURLWithPath: "/tmp/export.zip")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                isShowingActionsMenu: true
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.exportClient.exportBundle = { _ in exportURL }
        }

        // Tap export in menu - dismisses menu and starts export
        await store.send(.exportTapped) {
            $0.isShowingActionsMenu = false
            $0.isExporting = true
        }

        // Export completes
        await store.receive(\.exportCompleted) {
            $0.isExporting = false
            $0.shareURL = exportURL
        }
    }

    // MARK: - testDeleteActionFromMenu

    @Test
    func testDeleteActionFromMenu() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                isShowingActionsMenu: true
            )
        ) {
            SessionDetailFeature()
        }

        // Tap delete in menu - dismisses menu and shows delete confirmation
        await store.send(.deleteTapped) {
            $0.isShowingActionsMenu = false
            $0.isShowingDeleteConfirmation = true
        }
    }
}
