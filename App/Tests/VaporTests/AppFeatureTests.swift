import Testing
import ComposableArchitecture
@testable import Vapor

@MainActor
struct AppFeatureTests {
    @Test
    func testAppStartsOnTimeline() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
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
}
