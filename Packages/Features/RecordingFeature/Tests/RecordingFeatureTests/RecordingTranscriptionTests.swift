import Testing
import Foundation
import ComposableArchitecture
import Models
import Observability
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

@MainActor
struct RecordingTranscriptionTests {

    // MARK: - testTranscriptionStartedEvent

    /// Tests that when transcription starts successfully, it clears any previous unavailable state
    @Test
    func testTranscriptionStartedEvent() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-transcription")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        // Start with transcription unavailable to test the transition
        let store = TestStore(initialState: RecordingFeature.State(
            isTranscriptionAvailable: false,
            transcriptionUnavailableMessage: "Previous error"
        )) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { _ in }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
        }

        // Verify initial state shows transcription unavailable
        #expect(store.state.isTranscriptionAvailable == false)
        #expect(store.state.transcriptionUnavailableMessage == "Previous error")

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Emit transcription started event - should clear unavailable state
        eventContinuation?.yield(.transcriptionStarted)
        await store.receive(\.processorEvent) {
            $0.isTranscriptionAvailable = true
            $0.transcriptionUnavailableMessage = nil
        }

        // Verify transcription is now available
        #expect(store.state.isTranscriptionAvailable == true)
        #expect(store.state.transcriptionUnavailableMessage == nil)

        // Clean up
        eventContinuation?.finish()
        await store.skipInFlightEffects()
    }

    // MARK: - testTranscriptionUnavailableEvent

    /// Tests that when transcription fails to start, the state shows unavailable
    @Test
    func testTranscriptionUnavailableEvent() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-unavailable")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { _ in }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        eventContinuation?.yield(.listeningChanged(true))
        await store.receive(\.processorEvent) {
            $0.isListening = true
        }

        // Emit transcription unavailable event
        let errorMessage = "Models not initialized"
        eventContinuation?.yield(.transcriptionUnavailable(errorMessage))
        await store.receive(\.processorEvent) {
            $0.isTranscriptionAvailable = false
            $0.transcriptionUnavailableMessage = errorMessage
        }

        // Verify transcription is unavailable
        #expect(store.state.isTranscriptionAvailable == false)
        #expect(store.state.transcriptionUnavailableMessage == errorMessage)

        // Recording should still be active
        #expect(store.state.isRecording == true)
        #expect(store.state.isListening == true)

        // Clean up
        eventContinuation?.finish()
        await store.skipInFlightEffects()
    }

    // MARK: - testTranscriptionRecovery

    /// Tests that if transcription becomes unavailable then later starts, state updates correctly
    @Test
    func testTranscriptionRecovery() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-recovery")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { _ in }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // First: transcription unavailable
        eventContinuation?.yield(.transcriptionUnavailable("Initial error"))
        await store.receive(\.processorEvent) {
            $0.isTranscriptionAvailable = false
            $0.transcriptionUnavailableMessage = "Initial error"
        }

        // Then: transcription starts (recovery)
        eventContinuation?.yield(.transcriptionStarted)
        await store.receive(\.processorEvent) {
            $0.isTranscriptionAvailable = true
            $0.transcriptionUnavailableMessage = nil
        }

        // Verify transcription is now available
        #expect(store.state.isTranscriptionAvailable == true)
        #expect(store.state.transcriptionUnavailableMessage == nil)

        // Clean up
        eventContinuation?.finish()
        await store.skipInFlightEffects()
    }
}
