import Testing
import ComposableArchitecture
import Dependencies
import Models
import SessionDetailFeature
import Processing
@testable import Vapor

@MainActor
struct AppFeatureTests {
    @Test
    func testAppStartsOnTimeline() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.recoveryRoutineClient.run = { .empty }
        }

        // Verify initial state is on timeline tab
        #expect(store.state.currentTab == .timeline)

        // Send onAppear and verify state remains on timeline
        await store.send(.onAppear)

        // State should still be on timeline
        #expect(store.state.currentTab == .timeline)
    }

    @Test
    func testTabSelection() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // Start on timeline
        #expect(store.state.currentTab == .timeline)

        // Select people tab
        await store.send(.tabSelected(.people)) {
            $0.currentTab = .people
        }

        // Select timeline tab again
        await store.send(.tabSelected(.timeline)) {
            $0.currentTab = .timeline
        }
    }

    // MARK: - Navigation Stack Tests

    @Test
    func testNavigateToSessionDetail() async {
        let sessionID = SessionID(rawValue: "test-session-123")

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // Initially, path should be empty
        #expect(store.state.path.isEmpty)

        // When a session is tapped in timeline, it should push session detail onto path
        await store.send(.timeline(.sessionTapped(sessionID))) {
            $0.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
        }

        // Verify path contains the session detail
        #expect(store.state.path.count == 1)

        // When back is tapped in session detail, path should pop
        await store.send(.path(.element(id: 0, action: .sessionDetail(.backTapped)))) {
            _ = $0.path.popLast()
        }

        // Path should be empty again
        #expect(store.state.path.isEmpty)
    }

    @Test
    func testPathStartsEmpty() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        #expect(store.state.path.isEmpty)
    }
}
