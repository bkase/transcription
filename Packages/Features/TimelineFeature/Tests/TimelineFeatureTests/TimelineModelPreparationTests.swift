import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
import Processing
@testable import TimelineFeature

// Test UUID for deterministic IDs
private let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let testDate = Date(timeIntervalSince1970: 1000000)

@MainActor
struct TimelineModelPreparationTests {

    // MARK: - Model Preparation: downloading -> ready

    @Test
    func testModelPreparationSuccess() async {
        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(testDate)
            $0.uuid = .constant(testUUID)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            $0.fluidAudioClient.prepareModels = { }
            $0.fluidAudioClient.modelStatus = { .ready }
        }

        // onAppear triggers both prepareModels and loadSessions
        await store.send(.onAppear)

        // Receive prepareModels action - state transitions to downloading
        await store.receive(\.prepareModels) {
            $0.modelPreparationState = .downloading
        }

        // Receive loadSessions action
        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        // Model preparation succeeds
        await store.receive(\.modelPreparationSucceeded) {
            $0.modelPreparationState = .ready
        }

        // Sessions loaded
        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessionGroups = []
        }

        // Verify isRecordEnabled is now true
        #expect(store.state.isRecordEnabled)
    }

    // MARK: - Model Preparation: downloading -> failed

    @Test
    func testModelPreparationFailure() async {
        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(testDate)
            $0.uuid = .constant(testUUID)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            $0.fluidAudioClient.prepareModels = { }
            $0.fluidAudioClient.modelStatus = { .failed("Download failed") }
        }

        // onAppear triggers both prepareModels and loadSessions
        await store.send(.onAppear)

        // Receive prepareModels action - state transitions to downloading
        await store.receive(\.prepareModels) {
            $0.modelPreparationState = .downloading
        }

        // Receive loadSessions action
        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        // The following actions can arrive in any order due to async effects
        // Sessions loaded
        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessionGroups = []
        }

        // Model preparation fails
        await store.receive(\.modelPreparationFailed) {
            $0.modelPreparationState = .failed("Download failed")
        }

        // Verify isRecordEnabled is still false
        #expect(!store.state.isRecordEnabled)
    }

    // MARK: - Recording tap ignored when not ready

    @Test
    func testNewRecordingTappedIgnoredWhenNotReady() async {
        // State: models are downloading (not ready)
        let store = TestStore(
            initialState: TimelineFeature.State(modelPreparationState: .downloading)
        ) {
            TimelineFeature()
        }

        // Tapping new recording should be a no-op (no state change, no effect)
        await store.send(.newRecordingTapped)

        // Verify state unchanged
        #expect(store.state.modelPreparationState == .downloading)
        #expect(!store.state.isRecordEnabled)
    }

    @Test
    func testNewRecordingTappedIgnoredWhenFailed() async {
        // State: model preparation failed
        let store = TestStore(
            initialState: TimelineFeature.State(modelPreparationState: .failed("Error"))
        ) {
            TimelineFeature()
        }

        // Tapping new recording should be a no-op
        await store.send(.newRecordingTapped)

        // Verify state unchanged
        #expect(store.state.modelPreparationState == .failed("Error"))
        #expect(!store.state.isRecordEnabled)
    }

    @Test
    func testNewRecordingTappedIgnoredWhenIdle() async {
        // State: models in idle state (not yet prepared)
        let store = TestStore(
            initialState: TimelineFeature.State(modelPreparationState: .idle)
        ) {
            TimelineFeature()
        }

        // Tapping new recording should be a no-op
        await store.send(.newRecordingTapped)

        // Verify state unchanged
        #expect(store.state.modelPreparationState == .idle)
        #expect(!store.state.isRecordEnabled)
    }

    @Test
    func testNewRecordingTappedAllowedWhenReady() async {
        // State: models are ready
        let store = TestStore(
            initialState: TimelineFeature.State(modelPreparationState: .ready)
        ) {
            TimelineFeature()
        }

        // Verify isRecordEnabled is true
        #expect(store.state.isRecordEnabled)

        // Tapping new recording is allowed (navigation intent, no state change)
        await store.send(.newRecordingTapped)
    }

    // MARK: - onAppear skips model preparation if already downloading

    @Test
    func testOnAppearSkipsModelPrepIfAlreadyDownloading() async {
        let store = TestStore(
            initialState: TimelineFeature.State(modelPreparationState: .downloading)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(testDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            // prepareModels should not be called
            $0.fluidAudioClient.prepareModels = {
                Issue.record("prepareModels should not be called when already downloading")
            }
        }

        // onAppear only triggers loadSessions (not prepareModels since already downloading)
        await store.send(.onAppear)

        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessionGroups = []
        }
    }

    @Test
    func testOnAppearSkipsModelPrepIfAlreadyReady() async {
        let store = TestStore(
            initialState: TimelineFeature.State(modelPreparationState: .ready)
        ) {
            TimelineFeature()
        } withDependencies: {
            $0.date = .constant(testDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            // prepareModels should not be called
            $0.fluidAudioClient.prepareModels = {
                Issue.record("prepareModels should not be called when already ready")
            }
        }

        // onAppear only triggers loadSessions
        await store.send(.onAppear)

        await store.receive(\.loadSessions) {
            $0.isLoading = true
        }

        await store.receive(\.sessionsLoaded) {
            $0.isLoading = false
            $0.sessionGroups = []
        }
    }

    // MARK: - isRecordEnabled computed property

    @Test
    func testIsRecordEnabledComputedProperty() {
        // Only .ready state enables recording
        #expect(TimelineFeature.State(modelPreparationState: .ready).isRecordEnabled == true)
        #expect(TimelineFeature.State(modelPreparationState: .idle).isRecordEnabled == false)
        #expect(TimelineFeature.State(modelPreparationState: .downloading).isRecordEnabled == false)
        #expect(TimelineFeature.State(modelPreparationState: .failed("Error")).isRecordEnabled == false)
    }
}
