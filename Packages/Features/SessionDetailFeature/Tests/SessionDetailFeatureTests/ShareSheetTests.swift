import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import SessionDetailFeature

@MainActor
struct ShareSheetTests {

    // MARK: - testShareSheetPresented

    @Test
    func testShareSheetPresented() async {
        let sessionID = SessionID("session-123")
        let expectedBundleURL = URL(fileURLWithPath: "/tmp/export-bundle.zip")

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        } withDependencies: {
            $0.exportClient.exportBundle = { id in
                #expect(id == sessionID)
                return expectedBundleURL
            }
        }

        // User taps share button
        await store.send(.shareTapped) {
            $0.isExporting = true
        }

        // Export completes successfully
        await store.receive(\.exportCompleted) {
            $0.isExporting = false
            $0.shareURL = expectedBundleURL
        }

        // Verify share sheet would be presented
        #expect(store.state.shareURL != nil)

        // User dismisses share sheet
        await store.send(.shareSheetDismissed) {
            $0.shareURL = nil
        }
    }

    // MARK: - testShareExportFailure

    @Test
    func testShareExportFailure() async {
        let sessionID = SessionID("session-123")

        struct ExportError: Error, LocalizedError {
            var errorDescription: String? { "Export failed" }
        }

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        } withDependencies: {
            $0.exportClient.exportBundle = { _ in
                throw ExportError()
            }
        }

        // User taps share button
        await store.send(.shareTapped) {
            $0.isExporting = true
        }

        // Export fails
        await store.receive(\.exportFailed) {
            $0.isExporting = false
            $0.error = "Export failed"
        }

        // Verify share sheet is not shown
        #expect(store.state.shareURL == nil)
    }

    // MARK: - testShareTappedWhileExporting

    @Test
    func testShareTappedWhileExporting() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                isExporting: true
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            // Should never be called since already exporting
            $0.exportClient.exportBundle = { _ in
                Issue.record("Should not export when already exporting")
                return URL(fileURLWithPath: "/tmp/test.zip")
            }
        }

        // Tapping share while already exporting should be ignored
        await store.send(.shareTapped)
    }
}
