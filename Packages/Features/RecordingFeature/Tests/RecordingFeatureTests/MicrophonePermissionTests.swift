import Testing
import Foundation
import ComposableArchitecture
import Models
@testable import RecordingFeature
@testable import Processing
@testable import Audio

@MainActor
struct MicrophonePermissionTests {

    // MARK: - testDeniedShowsPermissionCta

    @Test
    func testDeniedShowsPermissionCta() async {
        let audioDirectory = FileManager.default.temporaryDirectory

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            // Permission is denied
            $0.microphonePermissionClient.getStatus = { .denied }
        }

        // Initially not recording and no permission denied state
        #expect(store.state.isRecording == false)
        #expect(store.state.isPermissionDenied == false)
        #expect(store.state.error == nil)

        // Attempt to start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        // Should receive permission denied
        await store.receive(\.permissionDenied) {
            $0.isPermissionDenied = true
            $0.error = "Microphone access is required to record. Please enable it in Settings."
        }

        // Recording should NOT have started
        #expect(store.state.isRecording == false)
        #expect(store.state.isPermissionDenied == true)
    }

    // MARK: - testAuthorizedStartsRecording

    @Test
    func testAuthorizedStartsRecording() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-auth")

        // Create a continuation we can control
        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            // Permission is already authorized
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in
                return eventStream
            }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Initially not recording
        #expect(store.state.isRecording == false)
        #expect(store.state.isPermissionDenied == false)

        // Start recording - should immediately proceed since authorized
        await store.send(.startRecording(audioDirectory: audioDirectory))

        // Should receive permissionGranted action
        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Emit didStart event from processor
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Emit listeningChanged event
        eventContinuation?.yield(.listeningChanged(true))
        await store.receive(\.processorEvent) {
            $0.isListening = true
        }

        // Recording is now active
        #expect(store.state.isRecording == true)
        #expect(store.state.isListening == true)
        #expect(store.state.isPermissionDenied == false)

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testUndeterminedRequestsPermission

    @Test
    func testUndeterminedRequestsPermissionAndGranted() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-undetermined")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            // Permission is undetermined, will be granted when requested
            $0.microphonePermissionClient.getStatus = { .undetermined }
            $0.microphonePermissionClient.requestPermission = { true }
            $0.recordingProcessorClient.startRecording = { _ in
                return eventStream
            }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Start recording - should request permission first
        await store.send(.startRecording(audioDirectory: audioDirectory))

        // Should receive permissionGranted after request succeeds
        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Emit didStart event from processor
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Recording started successfully after permission granted
        #expect(store.state.isRecording == true)
        #expect(store.state.isPermissionDenied == false)

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testUndeterminedRequestsPermissionAndDenied

    @Test
    func testUndeterminedRequestsPermissionAndDenied() async {
        let audioDirectory = FileManager.default.temporaryDirectory

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            // Permission is undetermined, will be denied when requested
            $0.microphonePermissionClient.getStatus = { .undetermined }
            $0.microphonePermissionClient.requestPermission = { false }
        }

        // Start recording - should request permission first
        await store.send(.startRecording(audioDirectory: audioDirectory))

        // Should receive permissionDenied after request fails
        await store.receive(\.permissionDenied) {
            $0.isPermissionDenied = true
            $0.error = "Microphone access is required to record. Please enable it in Settings."
        }

        // Recording should NOT have started
        #expect(store.state.isRecording == false)
        #expect(store.state.isPermissionDenied == true)
    }

    // MARK: - testRestrictedShowsPermissionCta

    @Test
    func testRestrictedShowsPermissionCta() async {
        let audioDirectory = FileManager.default.temporaryDirectory

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            // Permission is restricted (e.g., parental controls)
            $0.microphonePermissionClient.getStatus = { .restricted }
        }

        // Attempt to start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        // Should receive permission denied (restricted is treated like denied)
        await store.receive(\.permissionDenied) {
            $0.isPermissionDenied = true
            $0.error = "Microphone access is required to record. Please enable it in Settings."
        }

        // Recording should NOT have started
        #expect(store.state.isRecording == false)
        #expect(store.state.isPermissionDenied == true)
    }

    // MARK: - testOpenSettingsTapped

    @Test
    func testOpenSettingsTapped() async {
        var openSettingsCalled = false

        let store = TestStore(
            initialState: RecordingFeature.State(error: "Test error", isPermissionDenied: true)
        ) {
            RecordingFeature()
        } withDependencies: {
            $0.microphonePermissionClient.openSettings = {
                openSettingsCalled = true
            }
        }

        // Tap open settings
        await store.send(RecordingFeature.Action.openSettingsTapped)

        // Should have called openSettings
        #expect(openSettingsCalled == true)
    }
}
