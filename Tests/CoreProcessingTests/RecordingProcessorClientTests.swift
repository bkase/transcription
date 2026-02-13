import Testing
import Foundation
import Dependencies
import Models
import Persistence
@testable import Processing
@testable import Audio

@Test func testClientStartsAndStopsProcessor() async throws {
    // Use actors for thread-safe state tracking
    let stateTracker = ClientTestStateTracker()

    // Create in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Mock audio capture
    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            await stateTracker.setCaptureStarted(true)
            return AsyncStream { continuation in
                // Emit a frame to trigger the pipeline
                continuation.yield(AudioFrame(data: Data(repeating: 0, count: 1024), timestamp: 0))
                // Don't finish - simulate continuous capture until stopped
            }
        },
        stopCapture: {
            await stateTracker.setCaptureStopped(true)
        },
        isCapturing: {
            let started = await stateTracker.isCaptureStarted
            let stopped = await stateTracker.isCaptureStopped
            return started && !stopped
        },
        getInputFormat: { .recording }
    )

    // Mock audio file writer
    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 1024 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Mock FluidAudio client
    let mockFluidAudio = FluidAudioClient(
        prepareModels: { },
        modelStatus: { .ready },
        startTranscription: { _ in
            await stateTracker.setTranscriptionStarted(true)
            return AsyncStream { continuation in
                // Emit one segment (nil speakerId - diarization deferred to post-stop)
                let segment = TranscriptSegment(
                    id: TranscriptSegmentID(rawValue: "seg-001"),
                    text: "Test segment",
                    startMs: 0,
                    endMs: 1000,
                    speakerId: nil,
                    isFinal: true
                )
                continuation.yield(segment)
                // Don't finish - simulate continuous transcription until stopped
            }
        },
        stopTranscription: {
            await stateTracker.setTranscriptionStopped(true)
        },
        isTranscribing: {
            let started = await stateTracker.isTranscriptionStarted
            let stopped = await stateTracker.isTranscriptionStopped
            return started && !stopped
        },
        transcribeFile: { _ in [] },
        diarizeFile: { _ in [] }
    )

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

    // Mock title generator (no-op for tests)
    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { _ in nil },
        isAvailable: { false }
    )

    // Create the RecordingProcessorClient with injected dependencies
    let client = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        // Create client inside operation block so processor inherits dependencies
        RecordingProcessorClient.live()
    }

    // Initially not recording
    var isRecording = await client.isRecording()
    var sessionID = await client.currentSessionID()
    #expect(!isRecording, "Should not be recording initially")
    #expect(sessionID == nil, "Should have no session ID initially")

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await client.startRecording(tempDir)

    // Verify recording state changed
    isRecording = await client.isRecording()
    sessionID = await client.currentSessionID()
    #expect(isRecording, "Should be recording after start")
    #expect(sessionID != nil, "Should have session ID after start")

    // Verify capture and transcription started
    let captureStarted = await stateTracker.isCaptureStarted
    #expect(captureStarted, "Audio capture should have started")

    // Collect events with a short timeout
    var receivedEvents: [RecordingProcessorEvent] = []
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
            // Break after receiving listeningChanged to avoid waiting forever
            if case .listeningChanged(true) = event {
                break
            }
        }
    }

    // Wait for transcription to start
    try await waitUntil("transcription starts") {
        await stateTracker.isTranscriptionStarted
    }

    // Verify transcription started
    let transcriptionStarted = await stateTracker.isTranscriptionStarted
    #expect(transcriptionStarted, "Transcription should have started")

    // Stop recording
    await client.stopRecording()

    // Wait for stop to complete
    try await waitUntil("recording stops") {
        await client.isRecording() == false
    }

    // Verify stopped state
    isRecording = await client.isRecording()
    sessionID = await client.currentSessionID()
    #expect(!isRecording, "Should not be recording after stop")
    #expect(sessionID == nil, "Should have no session ID after stop")

    // Verify capture and transcription stopped
    let captureStopped = await stateTracker.isCaptureStopped
    let transcriptionStopped = await stateTracker.isTranscriptionStopped
    #expect(captureStopped, "Audio capture should have stopped")
    #expect(transcriptionStopped, "Transcription should have stopped")

    // Verify we got the didStart event
    #expect(receivedEvents.contains {
        if case .didStart = $0 { return true }
        return false
    }, "Should have received didStart event")

    // Clean up collect task
    collectTask.cancel()
}

@Test func testClientIsRecordingState() async throws {
    // Create in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Mock audio capture that doesn't finish
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

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

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

    // Mock title generator (no-op for tests)
    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { _ in nil },
        isAvailable: { false }
    )

    let client = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessorClient.live()
    }

    // Initially not recording
    #expect(await client.isRecording() == false)
    #expect(await client.currentSessionID() == nil)

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    _ = try await client.startRecording(tempDir)

    // Now recording
    #expect(await client.isRecording() == true)
    #expect(await client.currentSessionID() != nil)

    // Stop recording
    await client.stopRecording()

    // No longer recording
    #expect(await client.isRecording() == false)
    #expect(await client.currentSessionID() == nil)
}

@Test func testClientAlreadyRecordingThrows() async throws {
    let dbQueue = try makeDatabase(configuration: .inMemory)

    let mockAudioCapture = AudioCaptureClient(
        startCapture: { AsyncStream { _ in } },
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

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

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

    // Mock title generator (no-op for tests)
    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { _ in nil },
        isAvailable: { false }
    )

    let client = withDependencies {
        $0.audioCaptureClient = mockAudioCapture
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessorClient.live()
    }

    let tempDir = FileManager.default.temporaryDirectory

    // Start first recording
    _ = try await client.startRecording(tempDir)

    // Second start should throw
    await #expect(throws: RecordingProcessorError.alreadyRecording) {
        _ = try await client.startRecording(tempDir)
    }

    // Clean up
    await client.stopRecording()
}

// MARK: - Test Helper

/// Thread-safe state tracker for test assertions
private actor ClientTestStateTracker {
    var isCaptureStarted = false
    var isCaptureStopped = false
    var isTranscriptionStarted = false
    var isTranscriptionStopped = false

    func setCaptureStarted(_ value: Bool) { isCaptureStarted = value }
    func setCaptureStopped(_ value: Bool) { isCaptureStopped = value }
    func setTranscriptionStarted(_ value: Bool) { isTranscriptionStarted = value }
    func setTranscriptionStopped(_ value: Bool) { isTranscriptionStopped = value }
}
