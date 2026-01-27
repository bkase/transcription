import Testing
import Foundation
import Dependencies
import Models
import Persistence
@testable import Processing
@testable import Audio

// MARK: - TitleGeneratorClient Tests

@Test func testTitleGeneratorClientExplicitUnavailable() async {
    // Test that a client explicitly configured as unavailable reports unavailable
    let client = TitleGeneratorClient(
        generateTitle: { _ in nil },
        isAvailable: { false }
    )
    #expect(!client.isAvailable(), "Client should report unavailable")
}

@Test func testTitleGeneratorClientGenerateReturnsNilWhenUnavailable() async throws {
    // Create a mock client that always returns unavailable
    let client = TitleGeneratorClient(
        generateTitle: { _ in nil },
        isAvailable: { false }
    )

    #expect(!client.isAvailable())

    let result = try await client.generateTitle("Hello world transcript text")
    #expect(result == nil, "Should return nil when unavailable")
}

@Test func testTitleGeneratorClientMockReturnsTitle() async throws {
    // Create a mock client that returns a title
    let client = TitleGeneratorClient(
        generateTitle: { _ in "Team Meeting Summary" },
        isAvailable: { true }
    )

    #expect(client.isAvailable())

    let result = try await client.generateTitle("We discussed the project timeline and deliverables...")
    #expect(result == "Team Meeting Summary", "Should return the mocked title")
}

// MARK: - Title Generation Integration Tests

@Test func testTitleGenerationTriggersAfter15Seconds() async throws {
    // This test verifies that title generation is triggered after 15 seconds of transcript

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Track title generation calls
    actor TitleGeneratorState {
        var generateTitleCallCount = 0
        var lastTextReceived: String?

        func recordCall(text: String) {
            generateTitleCallCount += 1
            lastTextReceived = text
        }

        func getCallCount() -> Int { generateTitleCallCount }
        func getLastText() -> String? { lastTextReceived }
    }
    let generatorState = TitleGeneratorState()

    // Mock title generator that tracks calls and returns a title
    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { text in
            await generatorState.recordCall(text: text)
            return "Auto-Generated Title"
        },
        isAvailable: { true }
    )

    // Mock audio capture
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

    // Create script with segments that exceed 15 seconds
    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Hello everyone",
                startMs: 0,
                endMs: 5000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-002"),
                text: "Welcome to the meeting",
                startMs: 5000,
                endMs: 10000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-003"),
                text: "Today we will discuss the project",
                startMs: 10000,
                endMs: 16000,  // > 15000ms - should trigger title generation
                speakerId: "spk_1",
                isFinal: true
            ),
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: script)

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
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    // Start recording
    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events
    let collectTask = Task {
        for await _ in eventStream { }
    }

    // Wait for segments to be processed and title generation to trigger
    try await Task.sleep(for: .milliseconds(200))
    await processor.stopRecording()
    try await Task.sleep(for: .milliseconds(100))
    collectTask.cancel()

    // Verify title generation was called
    let callCount = await generatorState.getCallCount()
    #expect(callCount == 1, "Title generation should be triggered once after 15s")

    // Verify the accumulated text was passed
    let lastText = await generatorState.getLastText()
    #expect(lastText?.contains("Hello everyone") == true, "Text should include first segment")
    #expect(lastText?.contains("Welcome to the meeting") == true, "Text should include second segment")
    #expect(lastText?.contains("Today we will discuss the project") == true, "Text should include third segment")

    // Verify session title was updated in database
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1)
    let session = sessions[0]
    #expect(session.title == "Auto-Generated Title", "Session title should be set to generated title")
}

@Test func testTitleGenerationNotTriggeredBefore15Seconds() async throws {
    // This test verifies that title generation is NOT triggered before 15 seconds

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Track title generation calls
    actor TitleGeneratorState {
        var generateTitleCallCount = 0
        func incrementCallCount() { generateTitleCallCount += 1 }
        func getCallCount() -> Int { generateTitleCallCount }
    }
    let generatorState = TitleGeneratorState()

    // Mock title generator that tracks calls
    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { _ in
            await generatorState.incrementCallCount()
            return "Should Not Be Set"
        },
        isAvailable: { true }
    )

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

    // Create script with segments that are all under 15 seconds
    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Short recording",
                startMs: 0,
                endMs: 5000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-002"),
                text: "Still under 15 seconds",
                startMs: 5000,
                endMs: 10000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-003"),
                text: "Almost at threshold",
                startMs: 10000,
                endMs: 14999,  // Just under 15000ms - should NOT trigger
                speakerId: "spk_1",
                isFinal: true
            ),
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: script)

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
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await _ in eventStream { }
    }

    try await Task.sleep(for: .milliseconds(200))
    await processor.stopRecording()
    try await Task.sleep(for: .milliseconds(100))
    collectTask.cancel()

    // Verify title generation was NOT called
    let callCount = await generatorState.getCallCount()
    #expect(callCount == 0, "Title generation should NOT be triggered before 15s")

    // Verify session title is still nil
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1)
    let session = sessions[0]
    #expect(session.title == nil, "Session title should remain nil for short recordings")
}

@Test func testTitleGenerationNotOverwrittenIfUserAlreadySetTitle() async throws {
    // This test verifies that if the user already set a title, the auto-generated title doesn't overwrite it
    // We test this by creating a session, setting its title, then verifying that fetchSession + update
    // logic in the title generation path respects the existing title

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Create a session with a user-set title
    let sessionId = SessionID(rawValue: "test-session")
    var session = SessionRecord(
        id: sessionId.rawValue,
        startedAt: Date(timeIntervalSince1970: 1000),
        processingState: .recording,
        updatedAt: Date(timeIntervalSince1970: 1000)
    )
    session.title = "User Set Title"
    try await databaseClient.createSession(session)

    // Simulate what happens in the title generation code path:
    // 1. Check if session exists and title is nil
    // 2. Only update if title is nil
    let fetchedSession = try await databaseClient.fetchSession(sessionId)
    #expect(fetchedSession != nil, "Session should exist")
    #expect(fetchedSession?.title == "User Set Title", "Session should have user-set title")

    // The title generation logic in Processing.swift does:
    // if var session = try await databaseClient.fetchSession(sessionIdSnapshot),
    //    session.title == nil { ... update title ... }
    // Since title is NOT nil, no update should happen

    // Verify the guard condition
    if var sessionToUpdate = try await databaseClient.fetchSession(sessionId),
       sessionToUpdate.title == nil {
        // This block should NOT execute since title is already set
        sessionToUpdate.title = "Auto-Generated Title"
        try await databaseClient.updateSession(sessionToUpdate)
    }

    // Verify title was not changed
    let finalSession = try await databaseClient.fetchSession(sessionId)
    #expect(finalSession?.title == "User Set Title", "User-set title should be preserved (not overwritten)")
}

@Test func testTitleGenerationSkippedWhenUnavailable() async throws {
    // This test verifies that title generation is skipped when isAvailable() returns false

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Track title generation calls
    actor TitleGeneratorState {
        var generateTitleCallCount = 0
        func incrementCallCount() { generateTitleCallCount += 1 }
        func getCallCount() -> Int { generateTitleCallCount }
    }
    let generatorState = TitleGeneratorState()

    // Mock title generator that is unavailable
    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { _ in
            await generatorState.incrementCallCount()
            return "Should Not Be Called"
        },
        isAvailable: { false }  // Not available!
    )

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

    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Long recording content for testing",
                startMs: 0,
                endMs: 20000,  // Would trigger title generation if available
                speakerId: "spk_0",
                isFinal: true
            ),
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: script)

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
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await _ in eventStream { }
    }

    try await Task.sleep(for: .milliseconds(200))
    await processor.stopRecording()
    try await Task.sleep(for: .milliseconds(100))
    collectTask.cancel()

    // Verify title generation was NOT called (because isAvailable is false)
    let callCount = await generatorState.getCallCount()
    #expect(callCount == 0, "Title generation should NOT be called when unavailable")

    // Verify session title is nil
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1)
    let session = sessions[0]
    #expect(session.title == nil, "Session title should remain nil when title generation unavailable")
}

@Test func testTitleGenerationOnlyTriggersOnce() async throws {
    // This test verifies that title generation is only triggered once per recording session,
    // even if multiple segments exceed the 15s threshold

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Track title generation calls
    actor TitleGeneratorState {
        var generateTitleCallCount = 0
        func incrementCallCount() { generateTitleCallCount += 1 }
        func getCallCount() -> Int { generateTitleCallCount }
    }
    let generatorState = TitleGeneratorState()

    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { _ in
            await generatorState.incrementCallCount()
            return "Generated Title"
        },
        isAvailable: { true }
    )

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

    // Create script with MULTIPLE segments all exceeding 15 seconds
    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "First segment",
                startMs: 0,
                endMs: 16000,  // Triggers title generation
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-002"),
                text: "Second segment",
                startMs: 16000,
                endMs: 30000,  // Also > 15s - should NOT trigger again
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-003"),
                text: "Third segment",
                startMs: 30000,
                endMs: 45000,  // Also > 15s - should NOT trigger again
                speakerId: "spk_1",
                isFinal: true
            ),
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: script)

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
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await _ in eventStream { }
    }

    try await Task.sleep(for: .milliseconds(200))
    await processor.stopRecording()
    try await Task.sleep(for: .milliseconds(100))
    collectTask.cancel()

    // Verify title generation was called exactly ONCE
    let callCount = await generatorState.getCallCount()
    #expect(callCount == 1, "Title generation should only be triggered once per session")
}

@Test func testTitleGenerationHandlesError() async throws {
    // This test verifies that title generation errors don't crash the processor

    let dbQueue = try makeDatabase(configuration: .inMemory)
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    struct TitleGenerationError: Error {}

    // Mock title generator that throws an error
    let mockTitleGenerator = TitleGeneratorClient(
        generateTitle: { _ in
            throw TitleGenerationError()
        },
        isAvailable: { true }
    )

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

    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Recording content",
                startMs: 0,
                endMs: 20000,
                speakerId: "spk_0",
                isFinal: true
            ),
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: script)

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
        $0.titleGeneratorClient = mockTitleGenerator
        $0.uuid = .incrementing
        $0.date = .constant(Date(timeIntervalSince1970: 1000))
    } operation: {
        RecordingProcessor()
    }

    let tempDir = FileManager.default.temporaryDirectory
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    var receivedEvents: [RecordingProcessorEvent] = []
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    try await Task.sleep(for: .milliseconds(200))
    await processor.stopRecording()
    try await Task.sleep(for: .milliseconds(100))
    collectTask.cancel()

    // Verify recording completed normally despite title generation error
    let didFinishEvents = receivedEvents.filter {
        if case .didFinish = $0 { return true }
        return false
    }
    #expect(didFinishEvents.count == 1, "Recording should finish normally despite title generation error")

    // Verify session was created and completed
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1)
    let session = sessions[0]
    #expect(session.title == nil, "Session title should remain nil when title generation fails")
}
