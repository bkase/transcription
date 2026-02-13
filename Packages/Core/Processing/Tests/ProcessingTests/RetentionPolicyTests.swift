import Testing
import Foundation
import Dependencies
import Models
import Persistence
@testable import Processing
@testable import Audio

// MARK: - Test Helpers

/// Polls a condition at short intervals until it becomes true, or throws after a timeout.
private func waitUntil(
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(10),
    _ description: String = "condition",
    _ condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: pollInterval)
    }
    if await condition() { return }
    struct WaitTimeout: Error, CustomStringConvertible {
        let description: String
    }
    throw WaitTimeout(description: "waitUntil timed out waiting for: \(description)")
}

// MARK: - Shared Test Infrastructure

/// Creates a standard mock audio capture client that emits a few frames then finishes.
private func makeMockAudioCapture() -> AudioCaptureClient {
    AudioCaptureClient(
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
}

/// Creates a mock audio session client (no-op for tests).
private func makeMockAudioSession() -> AudioSessionClient {
    AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )
}

/// Actor that tracks the audio file path written by the mock file writer.
private actor WrittenFile {
    var audioPath: URL?
    func setPath(_ url: URL) { audioPath = url }
    func getPath() -> URL? { audioPath }
}

/// Creates a mock file writer that records the file path and creates a dummy file.
private func makeMockFileWriter(writtenFile: WrittenFile) -> AudioFileWriterClient {
    AudioFileWriterClient(
        startWriting: { url, _ in
            await writtenFile.setPath(url)
            try? Data("mock audio".utf8).write(to: url)
        },
        appendFrame: { _ in },
        finishWriting: { 2048 },
        cancelWriting: { },
        isWriting: { false }
    )
}

/// Creates a script with a single test segment for predictable test output.
private func makeSingleSegmentScript() -> MockFluidAudioScript {
    MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Test transcript content",
                startMs: 0,
                endMs: 2000,
                speakerId: "spk_0",
                isFinal: true
            )
        ]
    )
}

/// Actor to track whether transcribeFile was called (used to verify offline transcription policy).
private actor TranscribeTracker {
    var callCount = 0
    func increment() { callCount += 1 }
    func getCount() -> Int { callCount }
}

// MARK: - Retention Policy Tests

@Suite(.serialized)
struct RetentionPolicyTests {

    // ─── transcriptOnly Mode ───────────────────────────────────────────

    /// Policy: transcriptOnly runs offline transcription BEFORE deleting audio.
    /// After finalization, the session should be .processed, audio file deleted,
    /// audioPath cleared, and transcript segments present.
    @Test func transcriptOnlyRunsOfflineTranscriptionThenDeletesAudio() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()
        let transcribeTracker = TranscribeTracker()

        // Build a FluidAudioClient that tracks transcribeFile calls
        let script = makeSingleSegmentScript()
        let baseClient = MockFluidAudioClient.client(script: script)
        let trackingFluidAudio = FluidAudioClient(
            prepareModels: baseClient.prepareModels,
            modelStatus: baseClient.modelStatus,
            startTranscription: baseClient.startTranscription,
            stopTranscription: baseClient.stopTranscription,
            isTranscribing: baseClient.isTranscribing,
            transcribeFile: { url in
                await transcribeTracker.increment()
                return try await baseClient.transcribeFile(url)
            },
            diarizeFile: baseClient.diarizeFile
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: writtenFile)
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = trackingFluidAudio
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .transcriptOnly },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let eventStream = try await processor.startRecording(audioDirectory: tempDir)
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for live segment to land in DB
        try await waitUntil("live segment stored") {
            let sessions = try? await databaseClient.fetchSessions()
            guard let session = sessions?.first else { return false }
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: session.id))
            return (segs?.count ?? 0) >= 1
        }
        await processor.stopRecording()

        // Wait for finalization to complete (session reaches .processed)
        try await waitUntil("session finalized") {
            let sessions = try? await databaseClient.fetchSessions()
            return sessions?.first?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: offline transcription was invoked
        let callCount = await transcribeTracker.getCount()
        #expect(callCount >= 1, "transcribeFile should have been called for transcriptOnly mode")

        // ASSERT: audio file was deleted after transcription
        let audioPath = await writtenFile.getPath()
        #expect(audioPath != nil, "Audio file should have been written")
        if let audioPath {
            #expect(!FileManager.default.fileExists(atPath: audioPath.path),
                    "Audio file should be deleted after offline transcription in transcriptOnly mode")
        }

        // ASSERT: session audioPath is nil
        let sessions = try await databaseClient.fetchSessions()
        #expect(sessions.count == 1)
        #expect(sessions[0].audioPath == nil, "audioPath should be nil after transcriptOnly finalization")
        #expect(sessions[0].processingState == .processed)
    }

    /// Policy: transcriptOnly still deletes audio even when offline transcription fails.
    /// Session should land in .partial (has live segments), audio file deleted.
    @Test func transcriptOnlyDeletesAudioEvenOnOfflineFailure() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()

        // Use a client where offline transcription fails
        let script = makeSingleSegmentScript()
        let failingFluidAudio = MockFluidAudioClient.offlineFailure(
            script: script,
            errorMessage: "Simulated offline failure"
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: writtenFile)
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = failingFluidAudio
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .transcriptOnly },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let eventStream = try await processor.startRecording(audioDirectory: tempDir)
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for live segment to land in DB
        try await waitUntil("live segment stored") {
            let sessions = try? await databaseClient.fetchSessions()
            guard let session = sessions?.first else { return false }
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: session.id))
            return (segs?.count ?? 0) >= 1
        }
        await processor.stopRecording()

        // Wait for finalization (session reaches .partial because live segments exist but offline failed)
        try await waitUntil("session finalized after failure") {
            let sessions = try? await databaseClient.fetchSessions()
            let state = sessions?.first?.processingState
            return state == .partial || state == .processed
        }
        collectTask.cancel()

        // ASSERT: audio file was deleted even though offline transcription failed
        let audioPath = await writtenFile.getPath()
        #expect(audioPath != nil)
        if let audioPath {
            #expect(!FileManager.default.fileExists(atPath: audioPath.path),
                    "Audio file should be deleted even when offline transcription fails in transcriptOnly mode")
        }

        // ASSERT: session audioPath is nil
        let sessions = try await databaseClient.fetchSessions()
        #expect(sessions[0].audioPath == nil,
                "audioPath should be nil after transcriptOnly finalization (even on failure)")

        // ASSERT: live transcript segments preserved (I3 invariant)
        let sessionId = SessionID(rawValue: sessions[0].id)
        let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
        #expect(!segments.isEmpty, "Live segments should be preserved when offline transcription fails")
    }

    // ─── audioOnly Mode ────────────────────────────────────────────────

    /// Policy: audioOnly skips offline transcription entirely.
    /// Audio file retained, session goes directly to .processed.
    @Test func audioOnlySkipsOfflineTranscription() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()
        let transcribeTracker = TranscribeTracker()

        let script = makeSingleSegmentScript()
        let baseClient = MockFluidAudioClient.client(script: script)
        let trackingFluidAudio = FluidAudioClient(
            prepareModels: baseClient.prepareModels,
            modelStatus: baseClient.modelStatus,
            startTranscription: baseClient.startTranscription,
            stopTranscription: baseClient.stopTranscription,
            isTranscribing: baseClient.isTranscribing,
            transcribeFile: { url in
                await transcribeTracker.increment()
                return try await baseClient.transcribeFile(url)
            },
            diarizeFile: baseClient.diarizeFile
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: writtenFile)
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = trackingFluidAudio
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .audioOnly },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let eventStream = try await processor.startRecording(audioDirectory: tempDir)
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for audio file to be written
        try await waitUntil("audio file written") {
            await writtenFile.getPath() != nil
        }
        await processor.stopRecording()

        // Wait for finalization
        try await waitUntil("session finalized") {
            let sessions = try? await databaseClient.fetchSessions()
            return sessions?.first?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: transcribeFile was NOT called
        let callCount = await transcribeTracker.getCount()
        #expect(callCount == 0, "transcribeFile should NOT be called in audioOnly mode")

        // ASSERT: audio file retained
        let audioPath = await writtenFile.getPath()
        #expect(audioPath != nil)
        if let audioPath {
            #expect(FileManager.default.fileExists(atPath: audioPath.path),
                    "Audio file should be retained in audioOnly mode")
        }

        // ASSERT: session is processed with audioPath set
        let sessions = try await databaseClient.fetchSessions()
        #expect(sessions[0].processingState == .processed)
        #expect(sessions[0].audioPath != nil, "audioPath should be set in audioOnly mode")
    }

    // ─── both Mode ─────────────────────────────────────────────────────

    /// Policy: both mode runs offline transcription and retains audio.
    @Test func bothModeRunsOfflineAndRetainsAudio() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()
        let transcribeTracker = TranscribeTracker()

        let script = makeSingleSegmentScript()
        let baseClient = MockFluidAudioClient.client(script: script)
        let trackingFluidAudio = FluidAudioClient(
            prepareModels: baseClient.prepareModels,
            modelStatus: baseClient.modelStatus,
            startTranscription: baseClient.startTranscription,
            stopTranscription: baseClient.stopTranscription,
            isTranscribing: baseClient.isTranscribing,
            transcribeFile: { url in
                await transcribeTracker.increment()
                return try await baseClient.transcribeFile(url)
            },
            diarizeFile: baseClient.diarizeFile
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: writtenFile)
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = trackingFluidAudio
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .both },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let eventStream = try await processor.startRecording(audioDirectory: tempDir)
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for live segment to land in DB
        try await waitUntil("live segment stored") {
            let sessions = try? await databaseClient.fetchSessions()
            guard let session = sessions?.first else { return false }
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: session.id))
            return (segs?.count ?? 0) >= 1
        }
        await processor.stopRecording()

        // Wait for finalization
        try await waitUntil("session finalized") {
            let sessions = try? await databaseClient.fetchSessions()
            return sessions?.first?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: offline transcription was called
        let callCount = await transcribeTracker.getCount()
        #expect(callCount >= 1, "transcribeFile should be called in both mode")

        // ASSERT: audio file retained
        let audioPath = await writtenFile.getPath()
        #expect(audioPath != nil)
        if let audioPath {
            #expect(FileManager.default.fileExists(atPath: audioPath.path),
                    "Audio file should be retained in both mode")
        }

        // ASSERT: session has audioPath set
        let sessions = try await databaseClient.fetchSessions()
        #expect(sessions[0].processingState == .processed)
        #expect(sessions[0].audioPath != nil, "audioPath should be set in both mode")
    }

    // ─── Continuation Mode ─────────────────────────────────────────────

    /// Policy: continuation mode skips offline transcription, preserves original audio,
    /// and goes directly to .processed.
    @Test func continuationSkipsOfflineTranscriptionAndProcesses() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let transcribeTracker = TranscribeTracker()

        // Create the existing session that we'll continue
        let existingSessionId = "existing-session-001"
        let existingSession = SessionRecord(
            id: existingSessionId,
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 600),
            title: "Original Recording",
            durationMs: 100000,
            audioPath: "/original/audio.caf",
            processingState: .processed,
            speakerCount: 0,
            updatedAt: Date(timeIntervalSince1970: 600)
        )
        try await databaseClient.createSession(existingSession)

        let script = makeSingleSegmentScript()
        let baseClient = MockFluidAudioClient.client(script: script)
        let trackingFluidAudio = FluidAudioClient(
            prepareModels: baseClient.prepareModels,
            modelStatus: baseClient.modelStatus,
            startTranscription: baseClient.startTranscription,
            stopTranscription: baseClient.stopTranscription,
            isTranscribing: baseClient.isTranscribing,
            transcribeFile: { url in
                await transcribeTracker.increment()
                return try await baseClient.transcribeFile(url)
            },
            diarizeFile: baseClient.diarizeFile
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: WrittenFile())
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = trackingFluidAudio
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .both },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        // Continue the existing session
        let continuation = ContinuationConfig(
            sessionID: SessionID(rawValue: existingSessionId),
            timestampOffsetMs: 100000
        )
        let eventStream = try await processor.continueRecording(
            audioDirectory: tempDir,
            continuation: continuation
        )
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for live segment to arrive
        try await waitUntil("continuation segment stored") {
            let segs = try? await databaseClient.fetchTranscriptSegments(
                SessionID(rawValue: existingSessionId)
            )
            return (segs?.count ?? 0) >= 1
        }
        await processor.stopRecording()

        // Wait for finalization
        try await waitUntil("continuation session finalized") {
            let session = try? await databaseClient.fetchSession(
                SessionID(rawValue: existingSessionId)
            )
            return session?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: transcribeFile was NOT called (continuation skips offline)
        let callCount = await transcribeTracker.getCount()
        #expect(callCount == 0,
                "transcribeFile should NOT be called for continuation sessions")

        // ASSERT: original audioPath preserved
        let session = try await databaseClient.fetchSession(SessionID(rawValue: existingSessionId))
        #expect(session?.audioPath == "/original/audio.caf",
                "Original audioPath should be preserved for continuation")
        #expect(session?.processingState == .processed)

        // ASSERT: continuation segments have nil speakerId (no diarization)
        let segments = try await databaseClient.fetchTranscriptSegments(
            SessionID(rawValue: existingSessionId)
        )
        #expect(!segments.isEmpty, "Should have continuation segments")
        for segment in segments {
            #expect(segment.machineSpeakerId == nil,
                    "Continuation segments should have nil speakerId (diarization deferred)")
        }
    }

    /// Policy: continuation from .partial state is valid.
    @Test func continuationFromPartialStateIsValid() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        // Create a session in partial state (previously failed offline transcription)
        let sessionId = "partial-session-001"
        let partialSession = SessionRecord(
            id: sessionId,
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 600),
            durationMs: 100000,
            audioPath: "/original/audio.caf",
            processingState: .partial,
            speakerCount: 0,
            updatedAt: Date(timeIntervalSince1970: 600),
            processingError: "Previous offline transcription failed"
        )
        try await databaseClient.createSession(partialSession)

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: WrittenFile())
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = MockFluidAudioClient.client(script: makeSingleSegmentScript())
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .both },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        // Continue from partial - should not throw
        let continuation = ContinuationConfig(
            sessionID: SessionID(rawValue: sessionId),
            timestampOffsetMs: 100000
        )
        let eventStream = try await processor.continueRecording(
            audioDirectory: tempDir,
            continuation: continuation
        )
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for live segment
        try await waitUntil("continuation segment stored") {
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: sessionId))
            return (segs?.count ?? 0) >= 1
        }
        await processor.stopRecording()

        // Wait for finalization
        try await waitUntil("continuation finalized") {
            let session = try? await databaseClient.fetchSession(SessionID(rawValue: sessionId))
            return session?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: session is now processed
        let session = try await databaseClient.fetchSession(SessionID(rawValue: sessionId))
        #expect(session?.processingState == .processed)
    }

    /// Policy: continuation from invalid state (.recording, .transcribing, .failed) should throw.
    @Test func continuationFromInvalidStatesThrows() async throws {
        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        let invalidStates: [(ProcessingState, String)] = [
            (.recording, "recording-001"),
            (.transcribing, "transcribing-001"),
            (.failed, "failed-001"),
        ]

        for (state, id) in invalidStates {
            let session = SessionRecord(
                id: id,
                startedAt: Date(timeIntervalSince1970: 500),
                processingState: state,
                speakerCount: 0,
                updatedAt: Date(timeIntervalSince1970: 600)
            )
            try await databaseClient.createSession(session)
        }

        let tempDir = FileManager.default.temporaryDirectory

        for (state, id) in invalidStates {
            let processor = withDependencies {
                $0.audioCaptureClient = makeMockAudioCapture()
                $0.audioFileWriterClient = makeMockFileWriter(writtenFile: WrittenFile())
                $0.audioSessionClient = makeMockAudioSession()
                $0.fluidAudioClient = MockFluidAudioClient.empty
                $0.databaseClient = databaseClient
                $0.preferencesClient = PreferencesClient(
                    getAudioRetentionMode: { .both },
                    setAudioRetentionMode: { _ in }
                )
                $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
                $0.uuid = .incrementing
                $0.date = .constant(Date(timeIntervalSince1970: 1000))
            } operation: {
                RecordingProcessor()
            }

            let continuation = ContinuationConfig(
                sessionID: SessionID(rawValue: id),
                timestampOffsetMs: 0
            )

            do {
                _ = try await processor.continueRecording(
                    audioDirectory: tempDir,
                    continuation: continuation
                )
                Issue.record("Should have thrown for state \(state.rawValue)")
            } catch let error as RecordingProcessorError {
                #expect(error == .invalidStateForContinuation(state),
                        "Expected invalidStateForContinuation(\(state.rawValue)), got \(error)")
            } catch {
                Issue.record("Unexpected error type for state \(state.rawValue): \(error)")
            }
        }
    }

    // ─── Post-Stop Speaker Enrichment ───────────────────────────────────

    /// Successful finalization with diarization enriches segments with speaker IDs.
    /// Session ends in .processed with non-nil speakerId on segments and speaker tracks created.
    @Test func bothModeEnrichesSegmentsWithSpeakerIds() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()

        // Use the two-speaker conversation script with matching diarization
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .twoSpeakerDefault
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: writtenFile)
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = fluidAudioClient
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .both },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let eventStream = try await processor.startRecording(audioDirectory: tempDir)
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for live segments (emitted with nil speakerId)
        try await waitUntil("live segments stored") {
            let sessions = try? await databaseClient.fetchSessions()
            guard let session = sessions?.first else { return false }
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: session.id))
            return (segs?.count ?? 0) >= 1
        }
        await processor.stopRecording()

        // Wait for finalization to complete
        try await waitUntil("session finalized with enrichment") {
            let sessions = try? await databaseClient.fetchSessions()
            return sessions?.first?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: session is .processed
        let sessions = try await databaseClient.fetchSessions()
        let sessionId = SessionID(rawValue: sessions[0].id)
        #expect(sessions[0].processingState == .processed)

        // ASSERT: segments have speaker IDs from diarization enrichment
        let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
        #expect(!segments.isEmpty, "Should have offline transcript segments")
        let segmentsWithSpeaker = segments.filter { $0.machineSpeakerId != nil }
        #expect(!segmentsWithSpeaker.isEmpty,
                "At least some segments should have speaker IDs after enrichment")

        // ASSERT: speaker tracks were created
        let speakerTracks = try await databaseClient.fetchSpeakerTracks(sessionId)
        #expect(!speakerTracks.isEmpty, "Speaker tracks should be created from diarization")

        // ASSERT: session speakerCount reflects the enriched speakers
        #expect(sessions[0].speakerCount > 0, "Speaker count should be > 0 after enrichment")
    }

    /// Diarization failure during finalization preserves transcript text without speaker IDs.
    /// Session ends in .processed (ASR succeeded), segments have nil speakerId.
    @Test func diarizationFailureDuringFinalizationPreservesTranscript() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()

        // ASR works fine, but diarization fails
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .failure("Diarization model crashed")
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: writtenFile)
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = fluidAudioClient
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .both },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let eventStream = try await processor.startRecording(audioDirectory: tempDir)
        let collectTask = Task { for await _ in eventStream { } }

        // Wait for live segments
        try await waitUntil("live segments stored") {
            let sessions = try? await databaseClient.fetchSessions()
            guard let session = sessions?.first else { return false }
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: session.id))
            return (segs?.count ?? 0) >= 1
        }
        await processor.stopRecording()

        // Wait for finalization
        try await waitUntil("session finalized after diarization failure") {
            let sessions = try? await databaseClient.fetchSessions()
            return sessions?.first?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: session is .processed (ASR succeeded even though diarization failed)
        let sessions = try await databaseClient.fetchSessions()
        let sessionId = SessionID(rawValue: sessions[0].id)
        #expect(sessions[0].processingState == .processed)

        // ASSERT: transcript text is preserved (invariant I3)
        let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
        #expect(!segments.isEmpty, "Transcript segments must be preserved when diarization fails")

        // Verify text content is present
        let texts = segments.map(\.text)
        #expect(texts.contains(where: { !$0.isEmpty }),
                "Segments should have non-empty text")

        // ASSERT: segments have nil speakerId (diarization failed)
        for segment in segments {
            #expect(segment.machineSpeakerId == nil,
                    "Segments should have nil speakerId when diarization fails")
        }
    }

    // ─── Retry with Speaker Enrichment ────────────────────────────────

    /// Retry success enriches segments with speaker IDs and ends in .processed.
    @Test func retrySuccessEnrichesWithSpeakerIds() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        // Create a failed session with audio file
        let audioPath = tempDir.appendingPathComponent("retry-session.caf")
        try Data("mock audio data".utf8).write(to: audioPath)

        let sessionId = "retry-session-001"
        let failedSession = SessionRecord(
            id: sessionId,
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 600),
            audioPath: audioPath.path,
            processingState: .failed,
            speakerCount: 0,
            updatedAt: Date(timeIntervalSince1970: 600),
            processingError: "Previous offline transcription failed"
        )
        try await databaseClient.createSession(failedSession)

        // Insert a stale live segment (should be replaced by retry)
        let staleSegment = TranscriptSegmentRecord(
            id: "stale-seg-001",
            sessionId: sessionId,
            startMs: 0,
            endMs: 1000,
            machineSpeakerId: nil,
            text: "Old live segment",
            isFinal: true,
            createdAt: Date(timeIntervalSince1970: 500),
            updatedAt: Date(timeIntervalSince1970: 500)
        )
        try await databaseClient.createTranscriptSegment(staleSegment)

        // Mock: both ASR and diarization succeed
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .twoSpeakerDefault
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: WrittenFile())
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = fluidAudioClient
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .both },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let result = try await processor.retryOfflineTranscription(sessionId: SessionID(rawValue: sessionId))

        // ASSERT: retry succeeded
        #expect(result == true, "Retry should succeed")

        // ASSERT: session is .processed
        let session = try await databaseClient.fetchSession(SessionID(rawValue: sessionId))
        #expect(session?.processingState == .processed)
        #expect(session?.processingError == nil, "Error should be cleared after successful retry")

        // ASSERT: segments have speaker IDs from enrichment
        let segments = try await databaseClient.fetchTranscriptSegments(SessionID(rawValue: sessionId))
        #expect(!segments.isEmpty, "Should have transcript segments after retry")
        let segmentsWithSpeaker = segments.filter { $0.machineSpeakerId != nil }
        #expect(!segmentsWithSpeaker.isEmpty,
                "At least some segments should have speaker IDs after retry enrichment")

        // ASSERT: old stale segment was replaced
        let staleFound = segments.contains { $0.text == "Old live segment" }
        #expect(!staleFound, "Old live segment should be replaced by retry results")

        // ASSERT: speaker tracks created
        let tracks = try await databaseClient.fetchSpeakerTracks(SessionID(rawValue: sessionId))
        #expect(!tracks.isEmpty, "Speaker tracks should be created from diarization")

        // ASSERT: session speakerCount > 0
        #expect(session?.speakerCount ?? 0 > 0, "Speaker count should reflect enriched speakers")
    }

    /// Retry with diarization failure preserves transcript text, ends in .processed.
    @Test func retryDiarizationFailurePreservesTranscript() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        // Create a partial session with audio file
        let audioPath = tempDir.appendingPathComponent("retry-diarize-fail.caf")
        try Data("mock audio data".utf8).write(to: audioPath)

        let sessionId = "retry-diarize-fail-001"
        let partialSession = SessionRecord(
            id: sessionId,
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 600),
            audioPath: audioPath.path,
            processingState: .partial,
            speakerCount: 0,
            updatedAt: Date(timeIntervalSince1970: 600),
            processingError: "Previous attempt failed"
        )
        try await databaseClient.createSession(partialSession)

        // Mock: ASR succeeds but diarization fails
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .failure("Diarization model unavailable")
        )

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: WrittenFile())
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = fluidAudioClient
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .both },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        let result = try await processor.retryOfflineTranscription(sessionId: SessionID(rawValue: sessionId))

        // ASSERT: retry succeeded (ASR worked, diarization failure is non-fatal)
        #expect(result == true, "Retry should succeed even when diarization fails")

        // ASSERT: session is .processed
        let session = try await databaseClient.fetchSession(SessionID(rawValue: sessionId))
        #expect(session?.processingState == .processed)

        // ASSERT: transcript segments preserved with text (invariant I3)
        let segments = try await databaseClient.fetchTranscriptSegments(SessionID(rawValue: sessionId))
        #expect(!segments.isEmpty, "Transcript segments must be present after retry")
        let texts = segments.map(\.text)
        #expect(texts.contains(where: { !$0.isEmpty }),
                "Segments should have non-empty text")

        // ASSERT: segments have nil speakerId (diarization failed)
        for segment in segments {
            #expect(segment.machineSpeakerId == nil,
                    "Segments should have nil speakerId when diarization fails during retry")
        }

        // ASSERT: session speakerCount is 0 (no speakers assigned)
        #expect(session?.speakerCount == 0,
                "Speaker count should be 0 when diarization fails")
    }

    // ─── Retry Policy ──────────────────────────────────────────────────

    /// Policy: retry is not available when audioPath is nil (e.g. after transcriptOnly deletion).
    @Test func retryNotAvailableWithoutAudioFile() async throws {
        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        // Create a partial session with no audio path (transcriptOnly deleted it)
        let sessionId = "no-audio-session"
        let session = SessionRecord(
            id: sessionId,
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 600),
            audioPath: nil,
            processingState: .partial,
            speakerCount: 0,
            updatedAt: Date(timeIntervalSince1970: 600)
        )
        try await databaseClient.createSession(session)

        let processor = withDependencies {
            $0.audioCaptureClient = makeMockAudioCapture()
            $0.audioFileWriterClient = makeMockFileWriter(writtenFile: WrittenFile())
            $0.audioSessionClient = makeMockAudioSession()
            $0.fluidAudioClient = MockFluidAudioClient.empty
            $0.databaseClient = databaseClient
            $0.preferencesClient = PreferencesClient(
                getAudioRetentionMode: { .transcriptOnly },
                setAudioRetentionMode: { _ in }
            )
            $0.titleGeneratorClient = TitleGeneratorClient(generateTitle: { _ in nil }, isAvailable: { false })
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 1000))
        } operation: {
            RecordingProcessor()
        }

        // Retry should throw noAudioFile
        do {
            _ = try await processor.retryOfflineTranscription(sessionId: SessionID(rawValue: sessionId))
            Issue.record("Should have thrown noAudioFile")
        } catch let error as RecordingProcessorError {
            #expect(error == .noAudioFile,
                    "Expected noAudioFile, got \(error)")
        }
    }
}
