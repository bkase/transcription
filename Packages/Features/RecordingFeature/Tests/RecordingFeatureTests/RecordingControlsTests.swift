import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

@MainActor
struct RecordingControlsTests {

    // MARK: - testPauseAndResume

    @Test
    func testPauseAndResume() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-pause")

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
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in
                return eventStream
            }
            $0.recordingProcessorClient.stopRecording = { _ in }
            $0.recordingProcessorClient.pauseRecording = { }
            $0.recordingProcessorClient.resumeRecording = { }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.playStopSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
            $0.feedbackClient.triggerStopHaptic = { }
        }

        // Initially not recording
        #expect(store.state.isRecording == false)
        #expect(store.state.isPaused == false)

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

        // Advance clock - timer should tick
        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTicked) {
            $0.elapsedSeconds = 1
        }

        // Emit pause events from processor (simulating a pause action)
        eventContinuation?.yield(.listeningChanged(false))
        await store.receive(\.processorEvent) {
            $0.isListening = false
        }

        eventContinuation?.yield(.didPause)
        await store.receive(\.processorEvent) {
            $0.isPaused = true
        }

        // Advance clock - timer should NOT tick when paused
        // The timer effect still runs but the reducer ignores ticks when paused
        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTicked)
        // Note: state doesn't change because isPaused is true

        // Emit resume events from processor
        eventContinuation?.yield(.listeningChanged(true))
        await store.receive(\.processorEvent) {
            $0.isListening = true
        }

        eventContinuation?.yield(.didResume)
        await store.receive(\.processorEvent) {
            $0.isPaused = false
        }

        // Advance clock - timer should tick again
        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTicked) {
            $0.elapsedSeconds = 2
        }

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testPauseWhileNotRecordingIsIgnored

    @Test
    func testPauseWhileNotRecordingIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: false)
        ) {
            RecordingFeature()
        }

        // Pausing while not recording should be ignored
        await store.send(.pauseRecording)
    }

    // MARK: - testResumeWhileNotPausedIsIgnored

    @Test
    func testResumeWhileNotPausedIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: true, isPaused: false)
        ) {
            RecordingFeature()
        }

        // Resuming while not paused should be ignored
        await store.send(.resumeRecording)
    }

    // MARK: - testPauseWhileAlreadyPausedIsIgnored

    @Test
    func testPauseWhileAlreadyPausedIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: true, isPaused: true)
        ) {
            RecordingFeature()
        }

        // Pausing while already paused should be ignored
        await store.send(.pauseRecording)
    }

    // MARK: - testStopResetsPausedState

    @Test
    func testStopResetsPausedState() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-stop-paused")

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
            $0.recordingProcessorClient.pauseRecording = { }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.playStopSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
            $0.feedbackClient.triggerStopHaptic = { }
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

        // Pause recording
        await store.send(.pauseRecording)

        eventContinuation?.yield(.listeningChanged(false))
        await store.receive(\.processorEvent) {
            $0.isListening = false
        }

        eventContinuation?.yield(.didPause)
        await store.receive(\.processorEvent) {
            $0.isPaused = true
        }

        // Stop recording while paused
        await store.send(.stopRecording)

        // Emit didFinish - should reset both isRecording and isPaused
        eventContinuation?.yield(.didFinish(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isPaused = false
            $0.isListening = false
            $0.sessionID = nil
        }

        eventContinuation?.finish()
    }

    // MARK: - Speaker Setup Tests

    @Test
    func testSpeakerSetupToggle() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: true)
        ) {
            RecordingFeature()
        }

        #expect(store.state.speakerSetupExpanded == false)

        await store.send(.toggleSpeakerSetup) {
            $0.speakerSetupExpanded = true
        }

        await store.send(.toggleSpeakerSetup) {
            $0.speakerSetupExpanded = false
        }
    }

    @Test
    func testSelectSpeakerCount() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: true)
        ) {
            RecordingFeature()
        }

        #expect(store.state.selectedSpeakerCount == nil)

        await store.send(.selectSpeakerCount(2)) {
            $0.selectedSpeakerCount = 2
        }

        // Changing selection replaces previous
        await store.send(.selectSpeakerCount(3)) {
            $0.selectedSpeakerCount = 3
        }
    }

    @Test
    func testStopAndSavePassesSpeakerCount() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-stop-save")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()
        var capturedSpeakerCount: Int?

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { count in
                capturedSpeakerCount = count
            }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.playStopSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
            $0.feedbackClient.triggerStopHaptic = { }
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

        // Select speaker count and expand setup
        await store.send(.selectSpeakerCount(2)) {
            $0.selectedSpeakerCount = 2
        }
        await store.send(.toggleSpeakerSetup) {
            $0.speakerSetupExpanded = true
        }

        // Stop and save
        await store.send(.stopAndSave) {
            $0.speakerSetupExpanded = false
            $0.selectedSpeakerCount = nil
        }

        // Verify speaker count was passed through
        #expect(capturedSpeakerCount == 2)

        // Emit didFinish to clean up
        eventContinuation?.yield(.didFinish(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isPaused = false
            $0.isListening = false
            $0.sessionID = nil
        }

        eventContinuation?.finish()
    }

    @Test
    func testStopAndSaveWithoutSelectionIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: true, selectedSpeakerCount: nil)
        ) {
            RecordingFeature()
        }

        // stopAndSave without a speaker count selection should do nothing
        await store.send(.stopAndSave)
    }
}
