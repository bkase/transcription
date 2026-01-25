import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

@MainActor
struct RecordingProcessorWiringTests {

    // MARK: - testEventsUpdateState

    /// Tests that processor events update the RecordingFeature state correctly,
    /// including loading segments from the database when didAppendSegment is received.
    @Test
    func testEventsUpdateState() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-wiring")
        let mockSegmentID1 = TranscriptSegmentID("segment-001")
        let mockSegmentID2 = TranscriptSegmentID("segment-002")

        // Create controllable event stream
        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        // Mock database returns for segments
        var fetchSegmentsCallCount = 0

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
            $0.databaseClient.fetchTranscriptSegments = { sessionId in
                fetchSegmentsCallCount += 1
                #expect(sessionId == mockSessionID)

                // Return mock segments based on call count
                if fetchSegmentsCallCount == 1 {
                    // First call: one segment
                    return [
                        TranscriptSegmentRecord(
                            id: mockSegmentID1.rawValue,
                            sessionId: mockSessionID.rawValue,
                            startMs: 0,
                            endMs: 2500,
                            machineSpeakerId: "speaker_0",
                            text: "Hello, this is a test.",
                            confidence: 0.95,
                            isFinal: true,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                    ]
                } else {
                    // Second call: two segments
                    return [
                        TranscriptSegmentRecord(
                            id: mockSegmentID1.rawValue,
                            sessionId: mockSessionID.rawValue,
                            startMs: 0,
                            endMs: 2500,
                            machineSpeakerId: "speaker_0",
                            text: "Hello, this is a test.",
                            confidence: 0.95,
                            isFinal: true,
                            createdAt: Date(),
                            updatedAt: Date()
                        ),
                        TranscriptSegmentRecord(
                            id: mockSegmentID2.rawValue,
                            sessionId: mockSessionID.rawValue,
                            startMs: 2500,
                            endMs: 5000,
                            machineSpeakerId: "speaker_1",
                            text: "This is the second segment.",
                            confidence: 0.92,
                            isFinal: false,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                    ]
                }
            }
            $0.databaseClient.fetchSpeakerTracks = { _ in
                if fetchSegmentsCallCount == 1 {
                    return [
                        SpeakerTrackRecord(
                            id: "track-1",
                            sessionId: mockSessionID.rawValue,
                            machineSpeakerId: "speaker_0",
                            displayOrder: 1
                        )
                    ]
                } else {
                    return [
                        SpeakerTrackRecord(
                            id: "track-1",
                            sessionId: mockSessionID.rawValue,
                            machineSpeakerId: "speaker_0",
                            displayOrder: 1
                        ),
                        SpeakerTrackRecord(
                            id: "track-2",
                            sessionId: mockSessionID.rawValue,
                            machineSpeakerId: "speaker_1",
                            displayOrder: 2
                        )
                    ]
                }
            }
            $0.databaseClient.fetchPeople = { [] }
        }

        // Initially empty
        #expect(store.state.isRecording == false)
        #expect(store.state.liveSegments.isEmpty)

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Processor emits didStart
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Processor emits listeningChanged
        eventContinuation?.yield(.listeningChanged(true))
        await store.receive(\.processorEvent) {
            $0.isListening = true
        }

        // Processor emits first segment
        eventContinuation?.yield(.didAppendSegment(mockSegmentID1))
        await store.receive(\.processorEvent)

        // Should receive segmentsLoaded with one segment and one speaker track
        await store.receive(\.segmentsLoaded) {
            $0.liveSegments = [
                LiveSegment(
                    id: mockSegmentID1,
                    machineSpeakerId: "speaker_0",
                    startMs: 0,
                    endMs: 2500,
                    text: "Hello, this is a test.",
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

        // Verify segment count
        #expect(store.state.liveSegments.count == 1)
        #expect(store.state.liveSegments[0].text == "Hello, this is a test.")

        // Processor emits second segment
        eventContinuation?.yield(.didAppendSegment(mockSegmentID2))
        await store.receive(\.processorEvent)

        // Should receive segmentsLoaded with two segments and two speaker tracks
        await store.receive(\.segmentsLoaded) {
            $0.liveSegments = [
                LiveSegment(
                    id: mockSegmentID1,
                    machineSpeakerId: "speaker_0",
                    startMs: 0,
                    endMs: 2500,
                    text: "Hello, this is a test.",
                    isFinal: true
                ),
                LiveSegment(
                    id: mockSegmentID2,
                    machineSpeakerId: "speaker_1",
                    startMs: 2500,
                    endMs: 5000,
                    text: "This is the second segment.",
                    isFinal: false
                )
            ]
            $0.speakerTracks = [
                LiveSpeakerTrack(
                    machineSpeakerId: "speaker_0",
                    displayOrder: 1,
                    personName: nil
                ),
                LiveSpeakerTrack(
                    machineSpeakerId: "speaker_1",
                    displayOrder: 2,
                    personName: nil
                )
            ]
        }

        // Verify two segments now
        #expect(store.state.liveSegments.count == 2)
        #expect(store.state.liveSegments[1].text == "This is the second segment.")
        #expect(store.state.liveSegments[1].isFinal == false)

        // Stop recording
        await store.send(.stopRecording)

        // Processor emits didFinish - segments and speaker tracks should be cleared
        eventContinuation?.yield(.didFinish(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isListening = false
            $0.sessionID = nil
            $0.liveSegments = []
            $0.speakerTracks = []
        }

        // Verify segments and speaker tracks are cleared after finish
        #expect(store.state.liveSegments.isEmpty)
        #expect(store.state.speakerTracks.isEmpty)

        // Verify database was queried twice (once per segment event)
        #expect(fetchSegmentsCallCount == 2)

        // Clean up
        eventContinuation?.finish()
    }

    // MARK: - testSegmentsNotLoadedWithoutSessionID

    /// Tests that segments are not loaded if there's no session ID set.
    @Test
    func testSegmentsNotLoadedWithoutSessionID() async {
        let mockSegmentID = TranscriptSegmentID("segment-orphan")

        var fetchSegmentsCalled = false

        let store = TestStore(initialState: RecordingFeature.State(isRecording: true, sessionID: nil)) {
            RecordingFeature()
        } withDependencies: {
            $0.databaseClient.fetchTranscriptSegments = { _ in
                fetchSegmentsCalled = true
                return []
            }
        }

        // Note: sessionID is nil
        #expect(store.state.sessionID == nil)

        // Send processor event directly (without sessionID being set)
        // When sessionID is nil, the reducer should return .none and not query DB
        await store.send(.processorEvent(.didAppendSegment(mockSegmentID)))

        // Database should not be queried when there's no session ID
        #expect(fetchSegmentsCalled == false)
    }

    // MARK: - testSegmentsClearedOnFailure

    /// Tests that segments are cleared when the processor fails.
    @Test
    func testSegmentsClearedOnFailure() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-fail")
        let mockSegmentID = TranscriptSegmentID("segment-before-fail")

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
                        endMs: 1000,
                        machineSpeakerId: "speaker_0",
                        text: "Some text before failure",
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

        // Get a segment first
        eventContinuation?.yield(.didAppendSegment(mockSegmentID))
        await store.receive(\.processorEvent)
        await store.receive(\.segmentsLoaded) {
            $0.liveSegments = [
                LiveSegment(
                    id: mockSegmentID,
                    machineSpeakerId: "speaker_0",
                    startMs: 0,
                    endMs: 1000,
                    text: "Some text before failure",
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

        #expect(store.state.liveSegments.count == 1)
        #expect(store.state.speakerTracks.count == 1)

        // Now fail
        eventContinuation?.yield(.didFail("Storage error"))
        await store.receive(\.processorEvent) {
            $0.error = "Storage error"
            $0.isRecording = false
            $0.isListening = false
            $0.liveSegments = []
            $0.speakerTracks = []
        }

        // Segments and speaker tracks should be cleared
        #expect(store.state.liveSegments.isEmpty)
        #expect(store.state.speakerTracks.isEmpty)

        // Clean up
        eventContinuation?.finish()
    }
}
