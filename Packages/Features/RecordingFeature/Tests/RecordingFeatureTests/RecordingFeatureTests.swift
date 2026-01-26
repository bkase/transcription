import Testing
import Foundation
import ComposableArchitecture
import Models
import Observability
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

// Test UUID for deterministic alert IDs
private let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

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
            $0.microphonePermissionClient.getStatus = { .authorized }
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

        // Start recording - triggers permission check then permissionGranted
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
            var errorDescription: String? { "Storage error" }
        }

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.uuid = .constant(testUUID)
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in
                throw TestError()
            }
        }

        // Start recording - triggers permission check then permissionGranted
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Should receive failure from processor with alert
        await store.receive(\.recordingFailed) {
            $0.isRecording = false
            $0.error = "Storage error"
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Recording Error",
                message: "Storage error",
                primaryButton: .init(title: "Retry", action: .retry),
                secondaryButton: .init(title: "Cancel", action: .dismiss)
            )
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
            $0.uuid = .constant(testUUID)
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Emit didStart
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Emit failure event with alert
        eventContinuation?.yield(.didFail("Storage full"))
        await store.receive(\.processorEvent) {
            $0.error = "Storage full"
            $0.isRecording = false
            $0.isListening = false
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Recording Error",
                message: "Storage full",
                primaryButton: .init(title: "Retry", action: .retryFinalize),
                secondaryButton: .init(title: "Cancel", action: .dismiss)
            )
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
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
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
            $0.microphonePermissionClient.getStatus = { .authorized }
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
            $0.databaseClient.fetchSpeakerTracks = { _ in
                [
                    SpeakerTrackRecord(
                        id: "track-1",
                        sessionId: mockSessionID.rawValue,
                        machineSpeakerId: "speaker_0",
                        displayOrder: 1
                    )
                ]
            }
            $0.databaseClient.fetchPeople = { [] }
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

        // Segment append - triggers DB fetch and loads segments and speaker tracks
        eventContinuation?.yield(.didAppendSegment(mockSegmentID))
        await store.receive(\.processorEvent)

        // Should receive segmentsLoaded with segment and speaker tracks from DB
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
            $0.speakerTracks = [
                LiveSpeakerTrack(
                    machineSpeakerId: "speaker_0",
                    displayOrder: 1,
                    personName: nil
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
