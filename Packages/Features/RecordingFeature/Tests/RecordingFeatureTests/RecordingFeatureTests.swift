import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import RecordingFeature
@testable import Processing

@MainActor
struct RecordingFeatureTests {

    // MARK: - testStartStopTransitions

    @Test
    func testStartStopTransitions() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-123")

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
            $0.recordingProcessorClient.startRecording = { _ in
                return eventStream
            }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Initially not recording
        #expect(store.state.isRecording == false)
        #expect(store.state.isListening == false)
        #expect(store.state.sessionID == nil)
        #expect(store.state.elapsedSeconds == 0)

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory)) {
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

        // Advance clock and verify timer ticks
        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTicked) {
            $0.elapsedSeconds = 1
        }

        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTicked) {
            $0.elapsedSeconds = 2
        }

        // Stop recording
        await store.send(.stopRecording)

        // Emit didFinish event
        eventContinuation?.yield(.didFinish(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isListening = false
            $0.sessionID = nil
        }

        // Clean up
        eventContinuation?.finish()
    }

    // MARK: - testRecordingFailure

    @Test
    func testRecordingFailure() async {
        let audioDirectory = FileManager.default.temporaryDirectory

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Permission denied" }
        }

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.recordingProcessorClient.startRecording = { _ in
                throw TestError()
            }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory)) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Should receive failure
        await store.receive(\.recordingFailed) {
            $0.isRecording = false
            $0.error = "Permission denied"
        }
    }

    // MARK: - testProcessorEventFailure

    @Test
    func testProcessorEventFailure() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-456")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory)) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Emit didStart
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Emit failure event
        eventContinuation?.yield(.didFail("Storage full"))
        await store.receive(\.processorEvent) {
            $0.error = "Storage full"
            $0.isRecording = false
            $0.isListening = false
        }

        // Clean up
        eventContinuation?.finish()
    }

    // MARK: - testListeningStateTransitions

    @Test
    func testListeningStateTransitions() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-789")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory)) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Listening starts
        eventContinuation?.yield(.listeningChanged(true))
        await store.receive(\.processorEvent) {
            $0.isListening = true
        }

        // Listening stops (e.g., during pause)
        eventContinuation?.yield(.listeningChanged(false))
        await store.receive(\.processorEvent) {
            $0.isListening = false
        }

        // Listening resumes
        eventContinuation?.yield(.listeningChanged(true))
        await store.receive(\.processorEvent) {
            $0.isListening = true
        }

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testSegmentAppendLoadsFromDB

    @Test
    func testSegmentAppendLoadsFromDB() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-seg")
        let mockSegmentID = TranscriptSegmentID("segment-001")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
            $0.databaseClient.fetchTranscriptSegments = { _ in
                [
                    TranscriptSegmentRecord(
                        id: mockSegmentID.rawValue,
                        sessionId: mockSessionID.rawValue,
                        startMs: 0,
                        endMs: 1500,
                        machineSpeakerId: "speaker_0",
                        text: "Test segment text",
                        confidence: 0.9,
                        isFinal: true,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ]
            }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory)) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Segment append - triggers DB fetch and loads segments
        eventContinuation?.yield(.didAppendSegment(mockSegmentID))
        await store.receive(\.processorEvent)

        // Should receive segmentsLoaded with segment from DB
        await store.receive(\.segmentsLoaded) {
            $0.liveSegments = [
                LiveSegment(
                    id: mockSegmentID,
                    machineSpeakerId: "speaker_0",
                    startMs: 0,
                    endMs: 1500,
                    text: "Test segment text",
                    isFinal: true
                )
            ]
        }

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testStartWhileRecordingIsIgnored

    @Test
    func testStartWhileRecordingIsIgnored() async {
        let audioDirectory = FileManager.default.temporaryDirectory

        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: true)
        ) {
            RecordingFeature()
        }

        // Starting while already recording should be ignored
        await store.send(.startRecording(audioDirectory: audioDirectory))
    }

    // MARK: - testStopWhileNotRecordingIsIgnored

    @Test
    func testStopWhileNotRecordingIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: false)
        ) {
            RecordingFeature()
        }

        // Stopping while not recording should be ignored
        await store.send(.stopRecording)
    }
}
