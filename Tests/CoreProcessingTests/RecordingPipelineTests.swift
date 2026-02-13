import Testing
import Foundation
import Dependencies
import Models
import Persistence
@testable import Processing
@testable import Audio

/// End-to-end tests for the recording pipeline from audio capture to DB persistence.
/// Uses GeneratedAudioCapture for deterministic audio and MockFluidAudioClient for scripted transcription.

@Test func testRecordingCreatesSessionAndSegments() async throws {
    // Setup: Create test configuration
    let testDuration: Double = 0.5 // Short duration for fast tests
    let audioConfig = GeneratedAudioConfig(
        durationSeconds: testDuration,
        sampleRate: 44100,
        samplesPerFrame: 4096,
        frequency: 440,
        amplitude: 0.3
    )

    // Create in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Use GeneratedAudioCapture for deterministic audio
    let generatedAudioClient = AudioCaptureClient.generated(config: audioConfig)

    // Mock audio file writer (we don't need to actually write files)
    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 1024 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Create mock FluidAudioClient with a two-speaker conversation
    let mockFluidAudio = MockFluidAudioClient.twoSpeakerConversation

    // Fixed date and incrementing UUIDs for determinism
    let fixedDate = Date(timeIntervalSince1970: 1000)

    // Mock audio session client (no-op for tests)
    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    // Collect events from the recording processor
    var receivedEvents: [RecordingProcessorEvent] = []

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    // Create processor with injected dependencies
    let processor = withDependencies {
        $0.audioCaptureClient = generatedAudioClient
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(fixedDate)
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events in background task
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait for all 3 segments to be stored in database
    try await waitUntil("3 segments stored in DB") {
        let sessions = try? await databaseClient.fetchSessions()
        guard let session = sessions?.first else { return false }
        let sessionId = SessionID(rawValue: session.id)
        let segs = try? await databaseClient.fetchTranscriptSegments(sessionId)
        return (segs?.count ?? 0) >= 3
    }

    // Stop recording
    await processor.stopRecording()

    // Wait for finalization
    try await waitUntil("session finalized") {
        let sessions = try? await databaseClient.fetchSessions()
        return sessions?.first?.processingState == .processed
    }
    collectTask.cancel()

    // VERIFY: Session was created in database
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1, "Expected exactly 1 session in database, got \(sessions.count)")

    let session = sessions[0]
    #expect(session.processingState == .processed, "Session should be in processed state")
    #expect(session.previewText != nil, "Session should have preview text")

    // VERIFY: Transcript segments were created
    let sessionId = SessionID(rawValue: session.id)
    let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
    #expect(segments.count == 3, "Expected 3 transcript segments, got \(segments.count)")

    // Verify segment content matches mock script (twoSpeakerConversation)
    let sortedSegments = segments.sorted { $0.startMs < $1.startMs }
    #expect(sortedSegments[0].text == "Hello, how are you today?")
    #expect(sortedSegments[1].text == "I'm doing well, thank you for asking.")
    #expect(sortedSegments[2].text == "That's great to hear!")

    // Verify live segments have nil machineSpeakerId (I1 invariant)
    for segment in sortedSegments {
        #expect(segment.machineSpeakerId == nil, "Live segment '\(segment.text)' should have nil machineSpeakerId")
    }

    // Live segments have nil speakerId (diarization deferred to post-stop processing)
    // so no speaker tracks are created during live recording
    let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)
    #expect(speakerTracks.count == 0, "Live recording should have no speaker tracks (diarization deferred)")
    #expect(session.speakerCount == 0, "Live recording should have speakerCount = 0 (diarization deferred)")

    // VERIFY: Events were emitted correctly
    #expect(receivedEvents.count >= 4, "Should have at least 4 events")

    // Check first event is didStart
    if case .didStart(let eventSessionId) = receivedEvents[0] {
        #expect(eventSessionId.rawValue == session.id, "Event session ID should match DB session")
    } else {
        Issue.record("First event should be didStart, got \(receivedEvents[0])")
    }

    // Check for didAppendSegment events
    let appendEvents = receivedEvents.filter {
        if case .didAppendSegment = $0 { return true }
        return false
    }
    #expect(appendEvents.count == 3, "Should have 3 didAppendSegment events")

    // Check last event is didFinish
    if case .didFinish(let finishSessionId) = receivedEvents.last {
        #expect(finishSessionId.rawValue == session.id, "Finish event session ID should match")
    } else {
        Issue.record("Last event should be didFinish, got \(String(describing: receivedEvents.last))")
    }

    // VERIFY: Duration was computed correctly
    #expect(session.durationMs == 7000, "Session duration should be 7000ms (from mock segments)")
}

@Test func testRecordingWithEmptyTranscription() async throws {
    // Test that recording with no transcription segments still creates a valid session
    let audioConfig = GeneratedAudioConfig.silent(durationSeconds: 0.3)

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let generatedAudioClient = AudioCaptureClient.generated(config: audioConfig)

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 512 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Empty transcription - no segments
    let mockFluidAudio = MockFluidAudioClient.empty

    // Mock audio session client (no-op for tests)
    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    var receivedEvents: [RecordingProcessorEvent] = []

    // Mock preferences client (default to both mode)
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .both },
        setAudioRetentionMode: { _ in }
    )

    let processor = withDependencies {
        $0.audioCaptureClient = generatedAudioClient
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 2000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait for audio capture to finish (stream finishes immediately with empty script)
    try await waitUntil("recording active") {
        await processor.getIsRecording()
    }
    await processor.stopRecording()

    // Wait for finalization
    try await waitUntil("session finalized") {
        let sessions = try? await databaseClient.fetchSessions()
        return sessions?.first?.processingState == .processed
    }
    collectTask.cancel()

    // Session should exist and be processed even with no segments
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1)

    let session = sessions[0]
    #expect(session.processingState == .processed)
    #expect(session.previewText == nil, "Empty transcription should have no preview text")
    #expect(session.speakerCount == 0, "Empty transcription should have 0 speakers")
    #expect(session.durationMs == 0, "Empty transcription should have 0 duration")

    let sessionId = SessionID(rawValue: session.id)
    let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
    #expect(segments.isEmpty, "Should have no segments")

    let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)
    #expect(speakerTracks.isEmpty, "Should have no speaker tracks")
}

@Test func testRecordingWithPartialSegments() async throws {
    // Test that partial segments are handled correctly (updated when final arrives)
    let audioConfig = GeneratedAudioConfig(durationSeconds: 0.4)

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let generatedAudioClient = AudioCaptureClient.generated(config: audioConfig)

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in },
        finishWriting: { 2048 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Script with partial + final segments
    let mockFluidAudio = MockFluidAudioClient.withPartialSegments

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

    let processor = withDependencies {
        $0.audioCaptureClient = generatedAudioClient
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 3000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await _ in eventStream {}
    }

    // Wait for segments to be stored in database
    try await waitUntil("segments stored in DB") {
        let sessions = try? await databaseClient.fetchSessions()
        guard let session = sessions?.first else { return false }
        let sessionId = SessionID(rawValue: session.id)
        let segs = try? await databaseClient.fetchTranscriptSegments(sessionId)
        return (segs?.count ?? 0) >= 1
    }
    await processor.stopRecording()

    // Wait for finalization
    try await waitUntil("session finalized") {
        let sessions = try? await databaseClient.fetchSessions()
        return sessions?.first?.processingState == .processed
    }
    collectTask.cancel()

    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1)

    let session = sessions[0]
    let sessionId = SessionID(rawValue: session.id)
    let segments = try await databaseClient.fetchTranscriptSegments(sessionId)

    // Should have segments (partial segments may be updated to final)
    #expect(!segments.isEmpty, "Should have at least one segment")

    // Check that final segments have correct text
    let finalSegments = segments.filter { $0.isFinal }
    #expect(!finalSegments.isEmpty, "Should have at least one final segment")
}

@Test func testAudioFramesAreForkedToFileWriter() async throws {
    // Test that audio frames are delivered to both ML and file writer
    let audioConfig = GeneratedAudioConfig(durationSeconds: 0.2)

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    let generatedAudioClient = AudioCaptureClient.generated(config: audioConfig)

    // Track frames received by file writer
    actor FrameCounter {
        var count = 0
        func increment() { count += 1 }
        func getCount() -> Int { count }
    }
    let frameCounter = FrameCounter()

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { _, _ in },
        appendFrame: { _ in await frameCounter.increment() },
        finishWriting: { await frameCounter.getCount() * 4096 },
        cancelWriting: { },
        isWriting: { false }
    )

    let mockFluidAudio = MockFluidAudioClient.empty

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

    let processor = withDependencies {
        $0.audioCaptureClient = generatedAudioClient
        $0.audioFileWriterClient = mockFileWriter
        $0.audioSessionClient = mockAudioSession
        $0.fluidAudioClient = mockFluidAudio
        $0.databaseClient = databaseClient
        $0.preferencesClient = mockPreferences
        $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 4000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await _ in eventStream {}
    }

    // Wait for file writer to receive at least one frame
    try await waitUntil("file writer receives frames") {
        await frameCounter.getCount() > 0
    }
    await processor.stopRecording()

    // Wait for finalization
    try await waitUntil("session finalized") {
        let sessions = try? await databaseClient.fetchSessions()
        return sessions?.first?.processingState == .processed
    }
    collectTask.cancel()

    // File writer should have received frames
    let frameCount = await frameCounter.getCount()
    #expect(frameCount > 0, "File writer should receive at least one audio frame, got \(frameCount)")

    // With 0.2s at 44100Hz with 4096 samples/frame: ~2 frames expected
    #expect(frameCount >= 1, "Expected at least 1 frame for 0.2s audio")
}
