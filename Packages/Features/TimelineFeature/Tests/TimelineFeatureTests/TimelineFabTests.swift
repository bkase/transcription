import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import TimelineFeature

@MainActor
struct TimelineFabTests {

    // MARK: - testFabStartsRecording

    @Test
    func testFabStartsRecording() async {
        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        }

        // Tapping the FAB sends newRecordingTapped action
        // This is a navigation intent - no state change, handled by parent
        await store.send(.newRecordingTapped)
    }
}
