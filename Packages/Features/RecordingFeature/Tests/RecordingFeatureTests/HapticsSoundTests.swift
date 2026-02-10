import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

/// Test mock for tracking feedback client calls
private actor FeedbackTracker {
    var startSoundCount = 0
    var stopSoundCount = 0
    var startHapticCount = 0
    var stopHapticCount = 0

    func recordStartSound() {
        startSoundCount += 1
    }

    func recordStopSound() {
        stopSoundCount += 1
    }

    func recordStartHaptic() {
        startHapticCount += 1
    }

    func recordStopHaptic() {
        stopHapticCount += 1
    }

    func counts() -> (startSound: Int, stopSound: Int, startHaptic: Int, stopHaptic: Int) {
        (startSoundCount, stopSoundCount, startHapticCount, stopHapticCount)
    }
}

@MainActor
struct HapticsSoundTests {

    // MARK: - testStartStopTriggersFeedback

    @Test
    func testStartStopTriggersFeedback() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-feedback")
        let tracker = FeedbackTracker()

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
            $0.recordingProcessorClient.stopRecording = { }
            $0.feedbackClient.playStartSound = {
                await tracker.recordStartSound()
            }
            $0.feedbackClient.playStopSound = {
                await tracker.recordStopSound()
            }
            $0.feedbackClient.triggerStartHaptic = {
                await tracker.recordStartHaptic()
            }
            $0.feedbackClient.triggerStopHaptic = {
                await tracker.recordStopHaptic()
            }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Emit didStart from processor
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Verify start feedback was triggered
        let countsAfterStart = await tracker.counts()
        #expect(countsAfterStart.startSound == 1)
        #expect(countsAfterStart.startHaptic == 1)
        #expect(countsAfterStart.stopSound == 0)
        #expect(countsAfterStart.stopHaptic == 0)

        // Stop recording
        await store.send(.stopRecording)

        // Emit didFinish from processor
        eventContinuation?.yield(.didFinish(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isPaused = false
            $0.isListening = false
            $0.sessionID = nil
        }

        // Verify stop feedback was triggered
        let countsAfterStop = await tracker.counts()
        #expect(countsAfterStop.startSound == 1)
        #expect(countsAfterStop.startHaptic == 1)
        #expect(countsAfterStop.stopSound == 1)
        #expect(countsAfterStop.stopHaptic == 1)

        eventContinuation?.finish()
    }

    // MARK: - testDiscardTriggersFeedback

    @Test
    func testDiscardTriggersFeedback() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-discard-feedback")
        let tracker = FeedbackTracker()

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
            $0.recordingProcessorClient.stopRecording = { }
            $0.recordingProcessorClient.discardRecording = { }
            $0.feedbackClient.playStartSound = {
                await tracker.recordStartSound()
            }
            $0.feedbackClient.playStopSound = {
                await tracker.recordStopSound()
            }
            $0.feedbackClient.triggerStartHaptic = {
                await tracker.recordStartHaptic()
            }
            $0.feedbackClient.triggerStopHaptic = {
                await tracker.recordStopHaptic()
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

        // Show discard confirmation and confirm
        await store.send(.discardTapped) {
            $0.destination = .discardConfirmation
        }

        await store.send(.discardConfirmed) {
            $0.destination = nil
        }

        // Emit didDiscard from processor
        eventContinuation?.yield(.didDiscard(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isPaused = false
            $0.isListening = false
            $0.sessionID = nil
            $0.elapsedSeconds = 0
        }

        // Verify start and stop feedback were triggered
        let counts = await tracker.counts()
        #expect(counts.startSound == 1)
        #expect(counts.startHaptic == 1)
        #expect(counts.stopSound == 1)
        #expect(counts.stopHaptic == 1)

        eventContinuation?.finish()
    }

    // MARK: - testNoFeedbackWhenNotRecording

    @Test
    func testNoFeedbackWhenPermissionDenied() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let tracker = FeedbackTracker()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.microphonePermissionClient.getStatus = { .denied }
            $0.feedbackClient.playStartSound = {
                await tracker.recordStartSound()
            }
            $0.feedbackClient.triggerStartHaptic = {
                await tracker.recordStartHaptic()
            }
        }

        // Try to start recording - permission denied
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionDenied) {
            $0.isPermissionDenied = true
            $0.error = "Microphone access is required to record. Please enable it in Settings."
        }

        // Verify no feedback was triggered
        let counts = await tracker.counts()
        #expect(counts.startSound == 0)
        #expect(counts.startHaptic == 0)
    }
}
