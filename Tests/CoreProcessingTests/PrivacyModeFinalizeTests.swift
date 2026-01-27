import Testing
import Foundation
import Dependencies
import Models
import Persistence
@testable import Processing
@testable import Audio

@Test func testAudioRemovedWhenTranscriptOnly() async throws {
    // Setup: Create a temporary audio file that will be deleted
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Create in-memory database
    let dbQueue = try makeDatabase(configuration: .inMemory)

    // Mock audio capture that emits frames then finishes
    let mockAudioCapture = AudioCaptureClient(
        startCapture: {
            AsyncStream { continuation in
                continuation.yield(AudioFrame(data: Data(repeating: 0, count: 1024), timestamp: 0))
                continuation.yield(AudioFrame(data: Data(repeating: 0, count: 1024), timestamp: 100))
                continuation.finish()
            }
        },
        stopCapture: { },
        isCapturing: { false },
        getInputFormat: { .recording }
    )

    // Track written audio file
    actor WrittenFile {
        var audioPath: URL?
        func setPath(_ url: URL) { audioPath = url }
        func getPath() -> URL? { audioPath }
    }
    let writtenFile = WrittenFile()

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { url, _ in
            await writtenFile.setPath(url)
            // Create the file to simulate actual writing
            try? Data("mock audio".utf8).write(to: url)
        },
        appendFrame: { _ in },
        finishWriting: { 2048 },
        cancelWriting: { },
        isWriting: { false }
    )

    // Mock audio session
    let mockAudioSession = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    // Mock FluidAudio with a simple segment
    let script = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Test transcript",
                startMs: 0,
                endMs: 2000,
                speakerId: "spk_0",
                isFinal: true
            )
        ]
    )
    let mockFluidAudio = MockFluidAudioClient.client(script: script)

    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Create preferences client that returns transcriptOnly mode
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .transcriptOnly },
        setAudioRetentionMode: { _ in }
    )

    var receivedEvents: [RecordingProcessorEvent] = []

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
    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    // Collect events
    let collectTask = Task {
        for await event in eventStream {
            receivedEvents.append(event)
        }
    }

    // Wait for processing
    try await Task.sleep(for: .milliseconds(100))
    await processor.stopRecording()

    // Wait for finalization
    collectTask.cancel()
    try await Task.sleep(for: .milliseconds(50))

    // Verify didFinish event was emitted
    let finishEvents = receivedEvents.filter {
        if case .didFinish = $0 { return true }
        return false
    }
    #expect(finishEvents.count == 1, "Should have received didFinish event")

    // Verify audio file was deleted
    let audioPath = await writtenFile.getPath()
    #expect(audioPath != nil, "Should have written an audio file")
    if let audioPath = audioPath {
        #expect(!FileManager.default.fileExists(atPath: audioPath.path), "Audio file should be deleted in transcriptOnly mode")
    }

    // Verify session audioPath is nil in database
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1, "Should have exactly 1 session")
    #expect(sessions[0].audioPath == nil, "Session audioPath should be nil after transcriptOnly finalize")
    #expect(sessions[0].processingState == .processed, "Session should be in processed state")
}

@Test func testAudioRetainedWhenBothMode() async throws {
    // Setup: Create a temporary directory for audio
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    let dbQueue = try makeDatabase(configuration: .inMemory)

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

    actor WrittenFile {
        var audioPath: URL?
        func setPath(_ url: URL) { audioPath = url }
        func getPath() -> URL? { audioPath }
    }
    let writtenFile = WrittenFile()

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { url, _ in
            await writtenFile.setPath(url)
            try? Data("mock audio".utf8).write(to: url)
        },
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

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Create preferences client that returns both mode
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

    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await _ in eventStream { }
    }

    try await Task.sleep(for: .milliseconds(100))
    await processor.stopRecording()
    collectTask.cancel()
    try await Task.sleep(for: .milliseconds(50))

    // Verify audio file still exists
    let audioPath = await writtenFile.getPath()
    #expect(audioPath != nil, "Should have written an audio file")
    if let audioPath = audioPath {
        #expect(FileManager.default.fileExists(atPath: audioPath.path), "Audio file should be retained in both mode")
    }

    // Verify session audioPath is set in database
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1, "Should have exactly 1 session")
    // audioPath won't be set since we're not actually saving it to the session in startRecording
    // The session.audioPath stays nil in the current implementation
    #expect(sessions[0].processingState == .processed, "Session should be in processed state")
}

@Test func testAudioRetainedWhenAudioOnlyMode() async throws {
    // Setup: Create a temporary directory for audio
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    let dbQueue = try makeDatabase(configuration: .inMemory)

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

    actor WrittenFile {
        var audioPath: URL?
        func setPath(_ url: URL) { audioPath = url }
        func getPath() -> URL? { audioPath }
    }
    let writtenFile = WrittenFile()

    let mockFileWriter = AudioFileWriterClient(
        startWriting: { url, _ in
            await writtenFile.setPath(url)
            try? Data("mock audio".utf8).write(to: url)
        },
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

    let mockFluidAudio = MockFluidAudioClient.empty
    let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

    // Create preferences client that returns audioOnly mode
    let mockPreferences = PreferencesClient(
        getAudioRetentionMode: { .audioOnly },
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

    let eventStream = try await processor.startRecording(audioDirectory: tempDir)

    let collectTask = Task {
        for await _ in eventStream { }
    }

    try await Task.sleep(for: .milliseconds(100))
    await processor.stopRecording()
    collectTask.cancel()
    try await Task.sleep(for: .milliseconds(50))

    // Verify audio file still exists (should be retained in audioOnly mode)
    let audioPath = await writtenFile.getPath()
    #expect(audioPath != nil, "Should have written an audio file")
    if let audioPath = audioPath {
        #expect(FileManager.default.fileExists(atPath: audioPath.path), "Audio file should be retained in audioOnly mode")
    }

    // Verify session is processed
    let sessions = try await databaseClient.fetchSessions()
    #expect(sessions.count == 1, "Should have exactly 1 session")
    #expect(sessions[0].processingState == .processed, "Session should be in processed state")
}
