import Testing
import Foundation
import CoreGraphics
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

        // Tap more button to show actions menu (with anchor point)
        let testAnchorPoint = CGPoint(x: 350, y: 150)
        await store.send(.moreButtonTapped(anchorPoint: testAnchorPoint)) {
            $0.destination = .actionsMenu(anchorPoint: testAnchorPoint)
        }

        // Dismiss menu
        await store.send(.actionsMenuDismissed) {
            $0.destination = nil
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
                destination: .actionsMenu(anchorPoint: .zero)
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.exportClient.exportBundle = { _ in exportURL }
        }

        // Tap share in menu - dismisses menu and starts export
        await store.send(.shareTapped) {
            $0.destination = nil
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
                destination: .actionsMenu(anchorPoint: .zero)
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.exportClient.exportBundle = { _ in exportURL }
        }

        // Tap export in menu - dismisses menu and starts export
        await store.send(.exportTapped) {
            $0.destination = nil
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
                destination: .actionsMenu(anchorPoint: .zero)
            )
        ) {
            SessionDetailFeature()
        }

        // Tap delete in menu - dismisses menu and shows delete confirmation
        await store.send(.deleteTapped) {
            $0.destination = .deleteConfirmation
        }
    }

    // MARK: - testMenuAnchorPointStored

    @Test
    func testMenuAnchorPointStored() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        }

        // Verify initial anchor point is zero
        #expect(store.state.menuAnchorPoint == .zero)

        // Tap at a specific point
        let tapPoint = CGPoint(x: 320, y: 180)
        await store.send(.moreButtonTapped(anchorPoint: tapPoint)) {
            $0.destination = .actionsMenu(anchorPoint: tapPoint)
        }

        // Verify anchor point is stored in destination
        #expect(store.state.menuAnchorPoint == tapPoint)

        // Dismiss menu - anchor point resets with destination
        await store.send(.actionsMenuDismissed) {
            $0.destination = nil
        }

        // Anchor point returns to zero when destination is nil
        #expect(store.state.menuAnchorPoint == .zero)
    }

    // MARK: - testMenuWithDifferentAnchorPoints

    @Test
    func testMenuWithDifferentAnchorPoints() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        }

        // First tap at top-right corner area
        let firstTapPoint = CGPoint(x: 350, y: 150)
        await store.send(.moreButtonTapped(anchorPoint: firstTapPoint)) {
            $0.destination = .actionsMenu(anchorPoint: firstTapPoint)
        }

        await store.send(.actionsMenuDismissed) {
            $0.destination = nil
        }

        // Second tap at a different point (simulating scroll position change)
        let secondTapPoint = CGPoint(x: 350, y: 250)
        await store.send(.moreButtonTapped(anchorPoint: secondTapPoint)) {
            $0.destination = .actionsMenu(anchorPoint: secondTapPoint)
        }

        // Verify anchor point was updated
        #expect(store.state.menuAnchorPoint == secondTapPoint)
    }
}
