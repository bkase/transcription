import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

@MainActor
struct RecordingDiscardTests {

    // MARK: - testDiscardRemovesPartialSession

    @Test
    func testDiscardRemovesPartialSession() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-discard")

        // Create a continuation we can control
        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        var discardCalled = false

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in
                return eventStream
            }
            $0.recordingProcessorClient.discardRecording = {
                discardCalled = true
            }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

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

        // Advance clock so we have some elapsed time
        await clock.advance(by: .seconds(2))
        await store.receive(\.timerTicked) {
            $0.elapsedSeconds = 1
        }
        await store.receive(\.timerTicked) {
            $0.elapsedSeconds = 2
        }

        // User taps discard button - shows confirmation
        await store.send(.discardTapped) {
            $0.isShowingDiscardConfirmation = true
        }

        // User confirms discard
        await store.send(.discardConfirmed) {
            $0.isShowingDiscardConfirmation = false
        }

        // Verify discard was called on processor
        #expect(discardCalled)

        // Processor emits didDiscard event
        eventContinuation?.yield(.didDiscard(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isListening = false
            $0.sessionID = nil
            $0.elapsedSeconds = 0
        }

        // Clean up
        eventContinuation?.finish()
    }

    // MARK: - testDiscardCancelled

    @Test
    func testDiscardCancelled() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-cancel")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        var discardCalled = false

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in
                return eventStream
            }
            $0.recordingProcessorClient.stopRecording = { }
            $0.recordingProcessorClient.discardRecording = {
                discardCalled = true
            }
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

        // User taps discard button
        await store.send(.discardTapped) {
            $0.isShowingDiscardConfirmation = true
        }

        // User cancels discard
        await store.send(.discardCancelled) {
            $0.isShowingDiscardConfirmation = false
        }

        // Verify discard was NOT called
        #expect(!discardCalled)

        // Recording should still be in progress
        #expect(store.state.isRecording)
        #expect(store.state.sessionID == mockSessionID)

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testDiscardWhileNotRecordingIsIgnored

    @Test
    func testDiscardWhileNotRecordingIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: false)
        ) {
            RecordingFeature()
        }

        // Discard while not recording should be ignored
        await store.send(.discardTapped)
    }

    // MARK: - testDiscardConfirmedWhileNotRecordingIsIgnored

    @Test
    func testDiscardConfirmedWhileNotRecordingIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: false, isShowingDiscardConfirmation: true)
        ) {
            RecordingFeature()
        }

        // Discard confirmed while not recording should just close the alert
        await store.send(.discardConfirmed) {
            $0.isShowingDiscardConfirmation = false
        }
    }
}
