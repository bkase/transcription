import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
import Processing
@testable import TimelineFeature

@MainActor
struct TimelineFabTests {

    // MARK: - testFabStartsRecording

    @Test
    func testFabStartsRecording() async {
        // Models must be ready for FAB to trigger recording
        let store = TestStore(initialState: TimelineFeature.State(modelPreparationState: .ready)) {
            TimelineFeature()
        }

        // Tapping the FAB sends newRecordingTapped action
        // This is a navigation intent - no state change, handled by parent
        await store.send(.newRecordingTapped)
    }
}
