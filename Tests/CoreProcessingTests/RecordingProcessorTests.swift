import Testing
import Foundation
import Dependencies
import Models
import Persistence
@testable import Processing
@testable import Audio

@Test func testProcessorEmitsEventsInOrder() async throws {
    // Setup mock dependencies
    let testSegmentIds = ["seg-001", "seg-002", "seg-003"]

    // Create in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Collect events
    var receivedEvents: [RecordingProcessorEvent] = []

    // Mock audio capture that emits a few frames then finishes
    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            AsyncStream { continuation in
                // Emit a couple of audio frames
                continuation.yield(AudioFrame(data: Data(repeating: 0, count: 1024), timestamp: 0))
                continuation.yield(AudioFrame(data: Data(repeating: 0, count: 1024), timestamp: 100))
                continuation.finish()
            }
        },
        stopCapture: { },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    // Mock audio file writer
    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 2048 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Create mock FluidAudioClient with scripted segments
    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: testSegmentIds[0]),
                text: "Hello, how are you?",
                startMs: 0,
                endMs: 2000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: testSegmentIds[1]),
                text: "I'm doing great!",
                startMs: 2500,
                endMs: 4500,
                speakerId: "spk_1",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: testSegmentIds[2]),
                text: "That's wonderful.",
                startMs: 5000,
                endMs: 7000,
                speakerId: "spk_0",
                isFinal: true
            ),
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: script)

    // Create database client
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Mock audio session client (no-op for tests)
    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    // Run the test with injected dependencies
    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events with timeout
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait a bit for segments to be processed, then stop
    try await Task.sleep(for: .milliseconds(100))
    await processor.stopRecording()

    // Wait for collection to complete
    collectTask.cancel()
    try await Task.sleep(for: .milliseconds(50))

    // Verify event order
    #expect(receivedEvents.count >= 4, "Should have at least 4 events (didStart, listeningChanged(true), listeningChanged(false), didFinish)")

    // First event should be didStart
    if case .didStart(let sessionId) = receivedEvents[0] {
        #expect(!sessionId.rawValue.isEmpty, "Session ID should not be empty")
    } else {
        Issue.record("First event should be didStart, got \(receivedEvents[0])")
    }

    // Second event should be listeningChanged(true)
    #expect(receivedEvents[1] == .listeningChanged(true), "Second event should be listeningChanged(true)")

    // Check for didAppendSegment events (may be interleaved)
    let appendEvents = receivedEvents.filter {
        if case .didAppendSegment = $0 { return true }
        return false
    }
    #expect(appendEvents.count == 3, "Should have 3 didAppendSegment events")

    // Check for listeningChanged(false) before didFinish
    let lastEvents = receivedEvents.suffix(2)
    let lastEventsList = Array(lastEvents)
    #expect(lastEventsList[0] == .listeningChanged(false), "Second to last event should be listeningChanged(false)")

    // Last event should be didFinish
    if case .didFinish(let sessionId) = lastEventsList[1] {
        #expect(!sessionId.rawValue.isEmpty, "Session ID should not be empty")
    } else {
        Issue.record("Last event should be didFinish, got \(lastEventsList[1])")
    }

    // Verify database state
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1, "Should have exactly 1 session in database")

    let session = sessions[0]
    #expect(session.processingState == .processed, "Session should be in processed state")
    #expect(session.speakerCount == 2, "Session should have 2 speakers")
    #expect(session.durationMs == 7000, "Session duration should be 7000ms")
    #expect(session.previewText != nil, "Session should have preview text")

    // Verify transcript segments in database
    let sessionId = SessionID(rawValue: session.id)
    let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
    #expect(segments.count == 3, "Should have 3 transcript segments in database")

    // Verify speaker tracks in database
    let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)
    #expect(speakerTracks.count == 2, "Should have 2 speaker tracks in database")
}

@Test func testProcessorAlreadyRecordingThrows() async throws {
    // Create in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Mock audio capture that doesn't finish
    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            AsyncStream { _ in }
        },
        stopCapture: { },
        isCapturing: { true },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 0 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Mock audio session client (no-op for tests)
    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory

    // Start first recording
    _ = try await processor.startRecording(audioDirectory: tempDir)

    // Second start should throw
    await #expect(throws: RecordingProcessorError.alreadyRecording) {
        _ = try await processor.startRecording(audioDirectory: tempDir)
    }

    // Clean up
    await processor.stopRecording()
}

@Test func testProcessorStateTracking() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    let mockAudioCapture = AudioCaptureClient(
        startCapture: { AsyncStream { _ in } },
        stopCapture: { },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 0 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Mock audio session client (no-op for tests)
    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Initial state
    var isRecording = await processor.getIsRecording()
    var sessionId = await processor.getCurrentSessionID()
    #expect(!isRecording, "Should not be recording initially")
    #expect(sessionId == nil, "Should have no session ID initially")

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    _ = try await processor.startRecording(audioDirectory: tempDir)

    isRecording = await processor.getIsRecording()
    sessionId = await processor.getCurrentSessionID()
    #expect(isRecording, "Should be recording after start")
    #expect(sessionId != nil, "Should have session ID after start")

    // Stop recording
    await processor.stopRecording()

    isRecording = await processor.getIsRecording()
    sessionId = await processor.getCurrentSessionID()
    #expect(!isRecording, "Should not be recording after stop")
    #expect(sessionId == nil, "Should have no session ID after stop")
}

@Test func testProcessorHandlesInterruptionBegan() async throws {
    // This test verifies that when an audio session interruption begins,
    // the processor pauses capture and emits the interrupted event.

    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Track stop calls
    actor CaptureState {
        var stopCallCount = 0
        func incrementStopCount() { stopCallCount += 1 }
        func getStopCount() -> Int { stopCallCount }
    }
    let captureState = CaptureState()

    // Create controllable audio session stream
    let (sessionStream, sessionContinuation) = AsyncStream<AudioSessionEvent>.makeStream()

    let mockAudioCapture = AudioCaptureClient(
        startCapture: { AsyncStream { _ in } },
        stopCapture: { await captureState.incrementStopCount() },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 0 },
        cancelWriting: { },
        isWriting: { false }
    )

    let mockAudioSession = AudioSessionClient(
        startObserving: { sessionStream },
        stopObserving: { },
        configureForRecording: { }
    )

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    var receivedEvents: [RecordingProcessorEvent] = []

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events in background
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait for start
    try await Task.sleep(for: .milliseconds(50))

    // Initial stop count is 0
    var stopCount = await captureState.getStopCount()
    #expect(stopCount == 0, "Should not have stopped capture yet")

    // Simulate interruption began
    sessionContinuation.yield(.interrupted(.began))

    // Wait for event processing
    try await Task.sleep(for: .milliseconds(50))

    // Verify processor paused capture
    stopCount = await captureState.getStopCount()
    #expect(stopCount == 1, "Should have stopped capture once on interruption")

    // Verify isInterrupted state
    let isInterrupted = await processor.getIsInterrupted()
    #expect(isInterrupted, "Should be in interrupted state")

    // Verify events emitted
    let interruptedEvents = receivedEvents.filter {
        if case .interrupted = $0 { return true }
        return false
    }
    #expect(interruptedEvents.count == 1, "Should have received one interrupted event")

    let listeningFalseEvents = receivedEvents.filter { $0 == .listeningChanged(false) }
    #expect(listeningFalseEvents.count >= 1, "Should have received listeningChanged(false) on interruption")

    // Clean up
    sessionContinuation.finish()
    await processor.stopRecording()
    collectTask.cancel()
}

@Test func testProcessorHandlesInterruptionEndedWithResume() async throws {
    // This test verifies that when an interruption ends with shouldResume=true,
    // the processor auto-resumes capture.

    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Track start/stop calls
    actor CaptureState {
        var startCallCount = 0
        var stopCallCount = 0
        func incrementStartCount() { startCallCount += 1 }
        func incrementStopCount() { stopCallCount += 1 }
        func getStartCount() -> Int { startCallCount }
        func getStopCount() -> Int { stopCallCount }
    }
    let captureState = CaptureState()

    // Create controllable audio session stream
    let (sessionStream, sessionContinuation) = AsyncStream<AudioSessionEvent>.makeStream()

    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            await captureState.incrementStartCount()
            return AsyncStream { _ in }
        },
        stopCapture: { await captureState.incrementStopCount() },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 0 },
        cancelWriting: { },
        isWriting: { false }
    )

    let mockAudioSession = AudioSessionClient(
        startObserving: { sessionStream },
        stopObserving: { },
        configureForRecording: { }
    )

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    var receivedEvents: [RecordingProcessorEvent] = []

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events in background
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait for start
    try await Task.sleep(for: .milliseconds(50))

    // Initial start count is 1 (from startRecording)
    var startCount = await captureState.getStartCount()
    #expect(startCount == 1, "Should have started capture once")

    // Simulate interruption began then ended with shouldResume
    sessionContinuation.yield(.interrupted(.began))
    try await Task.sleep(for: .milliseconds(50))

    sessionContinuation.yield(.interrupted(.ended(shouldResume: true)))
    try await Task.sleep(for: .milliseconds(50))

    // Verify auto-resume (second start call)
    startCount = await captureState.getStartCount()
    #expect(startCount == 2, "Should have restarted capture after interruption ended")

    // Verify isInterrupted is cleared
    let isInterrupted = await processor.getIsInterrupted()
    #expect(!isInterrupted, "Should not be in interrupted state after resume")

    // Verify interruptionEnded event
    let endedEvents = receivedEvents.filter {
        if case .interruptionEnded(let shouldResume) = $0 {
            return shouldResume
        }
        return false
    }
    #expect(endedEvents.count == 1, "Should have received interruptionEnded(shouldResume: true)")

    // Clean up
    sessionContinuation.finish()
    await processor.stopRecording()
    collectTask.cancel()
}

@Test func testProcessorHandlesRouteChangeOldDeviceUnavailable() async throws {
    // This test verifies that when an old device becomes unavailable (e.g., headphones unplugged),
    // the processor restarts capture.

    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Track start/stop calls
    actor CaptureState {
        var startCallCount = 0
        var stopCallCount = 0
        func incrementStartCount() { startCallCount += 1 }
        func incrementStopCount() { stopCallCount += 1 }
        func getStartCount() -> Int { startCallCount }
        func getStopCount() -> Int { stopCallCount }
    }
    let captureState = CaptureState()

    // Create controllable audio session stream
    let (sessionStream, sessionContinuation) = AsyncStream<AudioSessionEvent>.makeStream()

    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            await captureState.incrementStartCount()
            return AsyncStream { _ in }
        },
        stopCapture: { await captureState.incrementStopCount() },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 0 },
        cancelWriting: { },
        isWriting: { false }
    )

    let mockAudioSession = AudioSessionClient(
        startObserving: { sessionStream },
        stopObserving: { },
        configureForRecording: { }
    )

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    var receivedEvents: [RecordingProcessorEvent] = []

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events in background
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait for start
    try await Task.sleep(for: .milliseconds(50))

    // Initial counts
    var startCount = await captureState.getStartCount()
    var stopCount = await captureState.getStopCount()
    #expect(startCount == 1, "Should have started capture once")
    #expect(stopCount == 0, "Should not have stopped capture yet")

    // Simulate oldDeviceUnavailable (headphones unplugged)
    sessionContinuation.yield(.routeChanged(.oldDeviceUnavailable))
    try await Task.sleep(for: .milliseconds(50))

    // Verify restart (stop + start again)
    startCount = await captureState.getStartCount()
    stopCount = await captureState.getStopCount()
    #expect(stopCount == 1, "Should have stopped capture for route change")
    #expect(startCount == 2, "Should have restarted capture after route change")

    // Verify routeChanged event
    let routeEvents = receivedEvents.filter {
        if case .routeChanged(let info) = $0 {
            return info.reason == .oldDeviceUnavailable && info.shouldRestartCapture
        }
        return false
    }
    #expect(routeEvents.count == 1, "Should have received routeChanged event with shouldRestartCapture=true")

    // Clean up
    sessionContinuation.finish()
    await processor.stopRecording()
    collectTask.cancel()
}

@Test func testProcessorDoesNotRestartCaptureForNewDevice() async throws {
    // This test verifies that when a new device becomes available,
    // the processor does NOT restart capture (it continues normally).

    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Track start/stop calls
    actor CaptureState {
        var startCallCount = 0
        var stopCallCount = 0
        func incrementStartCount() { startCallCount += 1 }
        func incrementStopCount() { stopCallCount += 1 }
        func getStartCount() -> Int { startCallCount }
        func getStopCount() -> Int { stopCallCount }
    }
    let captureState = CaptureState()

    // Create controllable audio session stream
    let (sessionStream, sessionContinuation) = AsyncStream<AudioSessionEvent>.makeStream()

    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            await captureState.incrementStartCount()
            return AsyncStream { _ in }
        },
        stopCapture: { await captureState.incrementStopCount() },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 0 },
        cancelWriting: { },
        isWriting: { false }
    )

    let mockAudioSession = AudioSessionClient(
        startObserving: { sessionStream },
        stopObserving: { },
        configureForRecording: { }
    )

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    var receivedEvents: [RecordingProcessorEvent] = []

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events in background
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait for start
    try await Task.sleep(for: .milliseconds(50))

    // Simulate newDeviceAvailable (headphones plugged in)
    sessionContinuation.yield(.routeChanged(.newDeviceAvailable))
    try await Task.sleep(for: .milliseconds(50))

    // Verify NO restart (counts unchanged after initial start)
    let startCount = await captureState.getStartCount()
    let stopCount = await captureState.getStopCount()
    #expect(startCount == 1, "Should NOT restart capture for new device")
    #expect(stopCount == 0, "Should NOT stop capture for new device")

    // Verify routeChanged event with shouldRestartCapture=false
    let routeEvents = receivedEvents.filter {
        if case .routeChanged(let info) = $0 {
            return info.reason == .newDeviceAvailable && !info.shouldRestartCapture
        }
        return false
    }
    #expect(routeEvents.count == 1, "Should have received routeChanged event with shouldRestartCapture=false")

    // Clean up
    sessionContinuation.finish()
    await processor.stopRecording()
    collectTask.cancel()
}

// MARK: - Offline Transcription Failure Tests

@Test func testOfflineTranscriptionFailureKeepsLiveSegments() async throws {
    // This test verifies that when offline transcription fails, live segments are preserved
    // and the session is marked as .partial (since live segments exist)

    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Set up temp directory and create a dummy audio file
    // The incrementing UUID starts with 00000000-0000-0000-0000-000000000000
    let tempDir = FileManager.default.temporaryDirectory
    let expectedSessionId = "00000000-0000-0000-0000-000000000000"
    let expectedAudioPath = tempDir.appendingPathComponent("\(expectedSessionId).caf")

    // Create dummy audio file so offline transcription is triggered
    FileManager.default.createFile(atPath: expectedAudioPath.path, contents: Data(repeating: 0, count: 1024), attributes: nil)

    // Mock audio capture that emits frames then finishes
    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            AsyncStream { continuation in
                continuation.yield(AudioFrame(data: Data(repeating: 0, count: 1024), timestamp: 0))
                continuation.finish()
            }
        },
        stopCapture: { },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 1024 },
        cancelWriting: { },
        isWriting: { false }
    )

    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    // Mock FluidAudio that emits live segments but fails offline transcription
    let mockFluidAudio = MockFluidAudioClient.offlineFailure(
        script: .twoSpeakerConversation,
        errorMessage: "Simulated offline transcription failure"
    )

    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events
    let collectTask = Task {
        var events: [RecordingProcessorEvent] = []
        for await event in eventStream {
            events.append(event)
        }
        return events
    }

    // Wait for live segments to be processed
    try await Task.sleep(for: .milliseconds(100))

    // Stop recording (triggers offline transcription which will fail)
    await processor.stopRecording()

    // Wait for collection to complete
    try await Task.sleep(for: .milliseconds(200))
    collectTask.cancel()

    // Verify session is marked as partial (live segments exist, but offline failed)
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1)

    let session = sessions[0]
    #expect(session.processingState == .partial, "Session should be .partial when offline fails but live segments exist")
    #expect(session.processingError != nil, "Session should have an error message")
    #expect(session.processingError?.contains("Offline transcription failed") == true)

    // Verify live segments are still in database (not deleted)
    let sessionId = SessionID(rawValue: session.id)
    let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
    #expect(segments.count == 3, "Live segments should be preserved when offline transcription fails")

    // Clean up
    try? FileManager.default.removeItem(at: expectedAudioPath)
}

@Test func testRetryOfflineTranscriptionSuccess() async throws {
    // This test verifies that retrying offline transcription on a failed/partial session
    // succeeds and marks the session as .processed

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Create a session in failed state with an audio file
    let tempDir = FileManager.default.temporaryDirectory
    let audioPath = tempDir.appendingPathComponent("retry-test.caf").path

    // Create a dummy audio file
    FileManager.default.createFile(atPath: audioPath, contents: Data(repeating: 0, count: 1024), attributes: nil)

    let failedSession = SessionRecord(
        id: "retry-test-session",
        startedAt: Date(timeIntervalSince1970: 1000),
        endedAt: Date(timeIntervalSince1970: 1100),
        audioPath: audioPath,
        processingState: .failed,
        speakerCount: 0,
        updatedAt: Date(timeIntervalSince1970: 1100),
        processingError: "Previous transcription failed"
    )
    try await databaseClient.createSession(failedSession)

    // Add some old (failed) transcript segments to verify they get replaced
    let oldSegment = TranscriptSegmentRecord(
        id: "old-segment-1",
        sessionId: "retry-test-session",
        startMs: 0,
        endMs: 1000,
        machineSpeakerId: "old_spk",
        text: "Old failed segment",
        isFinal: true,
        createdAt: Date(),
        updatedAt: Date()
    )
    try await databaseClient.createTranscriptSegment(oldSegment)

    // Mock FluidAudio that succeeds on retry
    let retryScript = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "retry-seg-001"),
                text: "Successfully transcribed text",
                startMs: 0,
                endMs: 5000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "retry-seg-002"),
                text: "More transcribed content",
                startMs: 5500,
                endMs: 10000,
                speakerId: "spk_1",
                isFinal: true
            )
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: retryScript, offlineBehavior: .success)

    let processor = withDependencies {
        $0.databaseClient = databaseClient
        $0.fluidAudioClient = mockFluidAudio
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 2000))
    } operation: {
        RecordingProcessor()
    }

    // Retry offline transcription
    let sessionId = SessionID(rawValue: "retry-test-session")
    let success = try await processor.retryOfflineTranscription(sessionId: sessionId)

    #expect(success, "Retry should succeed")

    // Verify session is now processed
    let updatedSession = try await databaseClient.fetchSession(sessionId)
    #expect(updatedSession?.processingState == .processed)
    #expect(updatedSession?.processingError == nil, "Error should be cleared on success")

    // Verify old segments were replaced with new ones
    let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
    #expect(segments.count == 2, "Should have 2 segments from retry")
    #expect(segments.allSatisfy { $0.text.contains("transcribed") }, "Segments should be from retry")

    // Verify speaker tracks were recreated
    let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)
    #expect(speakerTracks.count == 2, "Should have 2 speaker tracks from retry")

    // Clean up
    try? FileManager.default.removeItem(atPath: audioPath)
}

@Test func testRetryOfflineTranscriptionFailsWithoutAudioFile() async throws {
    // This test verifies that retry fails appropriately when there's no audio file

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Create a session in failed state WITHOUT an audio file
    let failedSession = SessionRecord(
        id: "no-audio-session",
        startedAt: Date(timeIntervalSince1970: 1000),
        endedAt: Date(timeIntervalSince1970: 1100),
        audioPath: nil, // No audio file
        processingState: .failed,
        speakerCount: 0,
        updatedAt: Date(timeIntervalSince1970: 1100),
        processingError: "Previous transcription failed"
    )
    try await databaseClient.createSession(failedSession)

    let processor = withDependencies {
        $0.databaseClient = databaseClient
        $0.fluidAudioClient = MockFluidAudioClient.empty
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 2000))
    } operation: {
        RecordingProcessor()
    }

    // Retry should fail with noAudioFile error
    let sessionId = SessionID(rawValue: "no-audio-session")
    await #expect(throws: RecordingProcessorError.noAudioFile) {
        _ = try await processor.retryOfflineTranscription(sessionId: sessionId)
    }
}

@Test func testRetryOfflineTranscriptionFailsForProcessedSession() async throws {
    // This test verifies that retry is rejected for sessions already in processed state

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let tempDir = FileManager.default.temporaryDirectory
    let audioPath = tempDir.appendingPathComponent("processed-test.caf").path
    FileManager.default.createFile(atPath: audioPath, contents: Data(repeating: 0, count: 1024), attributes: nil)

    // Create a session that's already processed
    let processedSession = SessionRecord(
        id: "processed-session",
        startedAt: Date(timeIntervalSince1970: 1000),
        endedAt: Date(timeIntervalSince1970: 1100),
        audioPath: audioPath,
        processingState: .processed,
        speakerCount: 2,
        updatedAt: Date(timeIntervalSince1970: 1100)
    )
    try await databaseClient.createSession(processedSession)

    let processor = withDependencies {
        $0.databaseClient = databaseClient
        $0.fluidAudioClient = MockFluidAudioClient.empty
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 2000))
    } operation: {
        RecordingProcessor()
    }

    // Retry should fail with invalidStateForRetry error
    let sessionId = SessionID(rawValue: "processed-session")
    await #expect(throws: RecordingProcessorError.invalidStateForRetry(.processed)) {
        _ = try await processor.retryOfflineTranscription(sessionId: sessionId)
    }

    // Clean up
    try? FileManager.default.removeItem(atPath: audioPath)
}

@Test func testRetryOfflineTranscriptionFailsWhileRecording() async throws {
    // This test verifies that retry is rejected while a recording is in progress

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Create a session in failed state
    let failedSession = SessionRecord(
        id: "failed-session",
        startedAt: Date(timeIntervalSince1970: 1000),
        endedAt: Date(timeIntervalSince1970: 1100),
        audioPath: "/tmp/test.caf",
        processingState: .failed,
        speakerCount: 0,
        updatedAt: Date(timeIntervalSince1970: 1100)
    )
    try await databaseClient.createSession(failedSession)

    let mockAudioCapture = AudioCaptureClient(
        startCapture: { AsyncStream { _ in } },
        stopCapture: { },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 0 },
        cancelWriting: { },
        isWriting: { false }
    )

    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = MockFluidAudioClient.empty
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 2000))
    } operation: {
        RecordingProcessor()
    }

    // Start a new recording
    let tempDir = FileManager.default.temporaryDirectory
    _ = try await processor.startRecording(audioDirectory: tempDir)

    // Retry should fail with alreadyRecording error
    let sessionId = SessionID(rawValue: "failed-session")
    await #expect(throws: RecordingProcessorError.alreadyRecording) {
        _ = try await processor.retryOfflineTranscription(sessionId: sessionId)
    }

    // Clean up
    await processor.stopRecording()
}
