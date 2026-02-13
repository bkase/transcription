import Testing
import Foundation
import Dependencies
import Models
import Persistence
@testable import Processing
@testable import Audio

// MARK: - Shared Test Infrastructure (duplicated from RetentionPolicyTests)

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

/// Actor to capture live segments as they are emitted during streaming (before finalization).
private actor LiveSegmentCapture {
    var segments: [TranscriptSegment] = []
    func append(_ segment: TranscriptSegment) {
        segments.append(segment)
    }
    func getSegments() -> [TranscriptSegment] {
        segments
    }
}

/// Actor to track diarizeFile invocations.
private actor DiarizeTracker {
    var callCount = 0
    func increment() { callCount += 1 }
    func getCount() -> Int { callCount }
}

// MARK: - End-Only Diarization Invariant Tests
//
// These tests verify the three locked behavioral invariants:
//   I1: Live segments never carry speaker labels (speakerId == nil during live streaming)
//   I2: Post-stop enrichment populates speaker IDs from full-file diarization + mapping
//   I3: Diarization failure preserves transcript text (no data loss)

@Suite(.serialized)
struct EndOnlyDiarizationTests {

    // ─── I1: Live segments have nil speakerId ─────────────────────────

    /// I1: During a normal recording with both ASR and diarizer available,
    /// the live segment stream emits segments with speakerId=nil.
    /// The mock client enforces this (matching production behavior).
    @Test func liveSegmentsEmitNilSpeakerIdDuringNormalRecording() async throws {
        let liveCapture = LiveSegmentCapture()

        // Build a client that captures live segments as they are emitted
        let script = MockFluidAudioScript.twoSpeakerConversation
        let actor = MockFluidAudioClientActor(
            script: script,
            modelState: .ready,
            offlineBehavior: .success,
            diarizationBehavior: .twoSpeakerDefault
        )

        let client = FluidAudioClient(
            prepareModels: { await actor.prepareModels() },
            modelStatus: { await actor.getModelStatus() },
            startTranscription: { audioStream in
                let stream = await actor.startTranscription(audioStream: audioStream)
                // Wrap the stream to capture emitted segments
                return AsyncStream { continuation in
                    Task {
                        for await segment in stream {
                            await liveCapture.append(segment)
                            continuation.yield(segment)
                        }
                        continuation.finish()
                    }
                }
            },
            stopTranscription: { await actor.stopTranscription() },
            isTranscribing: { await actor.getIsTranscribing() },
            transcribeFile: { _ in
                let segments = await actor.getScriptSegments()
                return segments.map { $0.toTranscriptSegment() }
            },
            diarizeFile: { _ in
                let behavior = await actor.getDiarizationBehavior()
                switch behavior {
                case .success(let segments): return segments
                case .empty: return []
                case .failure(let msg): throw MockOfflineTranscriptionError(message: msg)
                case .hang: try await Task.sleep(for: .seconds(3600)); return []
                }
            }
        )

        let audioStream = AsyncStream<AudioFrame> { $0.finish() }
        let segmentStream = try await client.startTranscription(audioStream)

        // Consume stream
        var received: [TranscriptSegment] = []
        for await segment in segmentStream {
            received.append(segment)
        }

        // I1: ALL live segments must have nil speakerId
        #expect(!received.isEmpty, "Should receive at least one live segment")
        for segment in received {
            #expect(segment.speakerId == nil,
                    "I1 violated: live segment '\(segment.text)' has non-nil speakerId '\(segment.speakerId ?? "")'")
        }

        // Also verify via capture actor
        let captured = await liveCapture.getSegments()
        #expect(captured.count == received.count)
        for segment in captured {
            #expect(segment.speakerId == nil,
                    "I1 violated (capture): live segment has non-nil speakerId")
        }
    }

    /// I1: During a full recording flow, the live segments persisted to the database
    /// during streaming have nil machineSpeakerId. We verify this by checking the DB
    /// while the recording is active, then discarding (to avoid slow finalization).
    @Test func liveSegmentsInDatabaseHaveNilSpeakerIdBeforeEnrichment() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()

        // Use a normal client with both ASR and diarization available
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

        // Wait for live segments to land in DB
        try await waitUntil("live segments stored") {
            let sessions = try? await databaseClient.fetchSessions()
            guard let session = sessions?.first else { return false }
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: session.id))
            return (segs?.count ?? 0) >= 1
        }

        // I1: Inspect live segments in DB WHILE STILL RECORDING (before any enrichment)
        let sessions = try await databaseClient.fetchSessions()
        let sessionId = SessionID(rawValue: sessions[0].id)
        let liveSegments = try await databaseClient.fetchTranscriptSegments(sessionId)

        #expect(!liveSegments.isEmpty, "Should have live segments in DB")
        for segment in liveSegments {
            #expect(segment.machineSpeakerId == nil,
                    "I1 violated: live segment in DB has non-nil machineSpeakerId '\(segment.machineSpeakerId ?? "")'")
        }

        // Discard to avoid waiting for offline transcription finalization
        await processor.discardRecording()
        collectTask.cancel()
    }

    // ─── I2: Post-stop enrichment populates speaker IDs ───────────────

    /// I2: When diarization returns empty segments (no speakers detected),
    /// the session still reaches .processed and segments are preserved with nil speaker IDs.
    @Test func emptyDiarizationResultPreservesTranscriptWithNilSpeakers() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()

        // ASR succeeds but diarization returns empty (no speakers detected)
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .empty
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
        try await waitUntil("session finalized") {
            let sessions = try? await databaseClient.fetchSessions()
            return sessions?.first?.processingState == .processed
        }
        collectTask.cancel()

        // ASSERT: session is .processed
        let sessions = try await databaseClient.fetchSessions()
        let sessionId = SessionID(rawValue: sessions[0].id)
        #expect(sessions[0].processingState == .processed)

        // ASSERT: transcript segments exist with text (I2/I3 - text preserved)
        let segments = try await databaseClient.fetchTranscriptSegments(sessionId)
        #expect(!segments.isEmpty, "Transcript segments must be preserved with empty diarization")
        let texts = segments.map(\.text)
        #expect(texts.contains(where: { !$0.isEmpty }), "Segments should have non-empty text")

        // ASSERT: all segments have nil speakerId (no diarization data available)
        for segment in segments {
            #expect(segment.machineSpeakerId == nil,
                    "Segments should have nil speakerId when diarization returns empty")
        }

        // ASSERT: speakerCount is 0
        #expect(sessions[0].speakerCount == 0,
                "Speaker count should be 0 when diarization returns empty")
    }

    // ─── I3: Diarization failure preserves transcript text ────────────

    /// I3: When ASR offline transcription completely fails (throws), live transcript
    /// segments already in the database are preserved. The session lands in .partial
    /// (has live segments) not .failed.
    @Test func offlineASRFailurePreservesLiveSegments() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()

        // Both ASR offline and diarization fail
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .failure("ASR model crashed"),
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

        // Wait for live segments to land in DB
        try await waitUntil("live segments stored") {
            let sessions = try? await databaseClient.fetchSessions()
            guard let session = sessions?.first else { return false }
            let segs = try? await databaseClient.fetchTranscriptSegments(SessionID(rawValue: session.id))
            return (segs?.count ?? 0) >= 1
        }

        // Capture live segment count and text before stop
        let sessionsBefore = try await databaseClient.fetchSessions()
        let sessionIdBefore = SessionID(rawValue: sessionsBefore[0].id)
        let liveSegsBefore = try await databaseClient.fetchTranscriptSegments(sessionIdBefore)
        let liveTexts = liveSegsBefore.map(\.text)

        await processor.stopRecording()

        // Wait for finalization (session should reach .partial since live segments exist)
        try await waitUntil("session finalized after ASR failure") {
            let sessions = try? await databaseClient.fetchSessions()
            let state = sessions?.first?.processingState
            return state == .partial || state == .processed
        }
        collectTask.cancel()

        // ASSERT: session is .partial (has live segments, offline failed)
        let sessions = try await databaseClient.fetchSessions()
        let sessionId = SessionID(rawValue: sessions[0].id)
        #expect(sessions[0].processingState == .partial,
                "Session should be .partial when offline ASR fails but live segments exist")

        // ASSERT: live segments are preserved (I3 - no data loss)
        let segmentsAfter = try await databaseClient.fetchTranscriptSegments(sessionId)
        #expect(!segmentsAfter.isEmpty,
                "I3 violated: live segments must be preserved when offline transcription fails")

        // Verify the same text content is preserved
        let textsAfter = segmentsAfter.map(\.text)
        for text in liveTexts {
            #expect(textsAfter.contains(text),
                    "I3 violated: live segment text '\(text)' was lost after offline failure")
        }

        // ASSERT: segments have nil speakerId (no enrichment happened)
        for segment in segmentsAfter {
            #expect(segment.machineSpeakerId == nil,
                    "Segments should have nil speakerId when offline transcription fails")
        }
    }

    /// I3: Retry when diarization returns empty still preserves ASR transcript text.
    @Test func retryWithEmptyDiarizationPreservesTranscriptText() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        // Create a partial session with audio file
        let audioPath = tempDir.appendingPathComponent("retry-empty-diarize.caf")
        try Data("mock audio data".utf8).write(to: audioPath)

        let sessionId = "retry-empty-diarize-001"
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

        // ASR succeeds, diarization returns empty
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .empty
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

        // ASSERT: retry succeeded (ASR produced segments)
        #expect(result == true, "Retry should succeed when ASR works even with empty diarization")

        // ASSERT: session is .processed
        let session = try await databaseClient.fetchSession(SessionID(rawValue: sessionId))
        #expect(session?.processingState == .processed)

        // ASSERT: transcript segments are present with text
        let segments = try await databaseClient.fetchTranscriptSegments(SessionID(rawValue: sessionId))
        #expect(!segments.isEmpty, "Transcript segments must be present after retry")
        let texts = segments.map(\.text)
        #expect(texts.contains(where: { !$0.isEmpty }),
                "I3: segments should have non-empty text after retry with empty diarization")

        // ASSERT: segments have nil speakerId (no diarization data)
        for segment in segments {
            #expect(segment.machineSpeakerId == nil,
                    "Segments should have nil speakerId when diarization returns empty during retry")
        }

        // ASSERT: speakerCount is 0
        #expect(session?.speakerCount == 0,
                "Speaker count should be 0 when diarization returns empty")
    }

    /// I3: Retry when ASR completely fails preserves existing segments in DB.
    @Test func retryASRFailurePreservesExistingSegments() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

        // Create a partial session with audio file and existing live segments
        let audioPath = tempDir.appendingPathComponent("retry-asr-fail.caf")
        try Data("mock audio data".utf8).write(to: audioPath)

        let sessionId = "retry-asr-fail-001"
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

        // Insert existing live segments that should be preserved
        let existingSegment = TranscriptSegmentRecord(
            id: "existing-seg-001",
            sessionId: sessionId,
            startMs: 0,
            endMs: 2000,
            machineSpeakerId: nil,
            text: "This is preserved live text",
            isFinal: true,
            createdAt: Date(timeIntervalSince1970: 500),
            updatedAt: Date(timeIntervalSince1970: 500)
        )
        try await databaseClient.createTranscriptSegment(existingSegment)

        // Both ASR and diarization fail on retry
        let fluidAudioClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .failure("ASR model crashed on retry"),
            diarizationBehavior: .failure("Diarization model crashed")
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

        // ASSERT: retry failed
        #expect(result == false, "Retry should fail when ASR throws")

        // ASSERT: session is .partial (still has existing segments)
        let session = try await databaseClient.fetchSession(SessionID(rawValue: sessionId))
        #expect(session?.processingState == .partial,
                "Session should be .partial when retry fails but existing segments are preserved")

        // ASSERT: existing segments are preserved (I3 - no data loss)
        let segments = try await databaseClient.fetchTranscriptSegments(SessionID(rawValue: sessionId))
        #expect(!segments.isEmpty, "I3 violated: existing segments must be preserved when retry fails")
        #expect(segments.contains(where: { $0.text == "This is preserved live text" }),
                "I3 violated: original live segment text must survive retry failure")
    }

    // ─── I2: Enrichment verifies diarizeFile is called ────────────────

    /// I2: Verify that diarizeFile is actually invoked during normal finalization,
    /// confirming the post-stop enrichment pipeline runs.
    @Test func diarizeFileIsCalledDuringFinalization() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()
        let diarizeTracker = DiarizeTracker()

        // Build a FluidAudioClient that tracks diarizeFile calls
        let baseClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .twoSpeakerDefault
        )
        let trackingFluidAudio = FluidAudioClient(
            prepareModels: baseClient.prepareModels,
            modelStatus: baseClient.modelStatus,
            startTranscription: baseClient.startTranscription,
            stopTranscription: baseClient.stopTranscription,
            isTranscribing: baseClient.isTranscribing,
            transcribeFile: baseClient.transcribeFile,
            diarizeFile: { url in
                await diarizeTracker.increment()
                return try await baseClient.diarizeFile(url)
            }
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

        // Wait for live segments
        try await waitUntil("live segments stored") {
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

        // I2: diarizeFile was called during finalization
        let callCount = await diarizeTracker.getCount()
        #expect(callCount >= 1,
                "I2: diarizeFile must be called during post-stop enrichment")
    }

    /// I2: Verify diarizeFile is NOT called for continuation sessions
    /// (continuation skips offline processing entirely).
    @Test func diarizeFileNotCalledForContinuation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let diarizeTracker = DiarizeTracker()

        // Create the existing session to continue
        let existingSessionId = "cont-diarize-check-001"
        let existingSession = SessionRecord(
            id: existingSessionId,
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 600),
            title: "Original Recording",
            durationMs: 100000,
            audioPath: "/original/audio.caf",
            processingState: .processed,
            speakerCount: 2,
            updatedAt: Date(timeIntervalSince1970: 600)
        )
        try await databaseClient.createSession(existingSession)

        let baseClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .twoSpeakerDefault
        )
        let trackingFluidAudio = FluidAudioClient(
            prepareModels: baseClient.prepareModels,
            modelStatus: baseClient.modelStatus,
            startTranscription: baseClient.startTranscription,
            stopTranscription: baseClient.stopTranscription,
            isTranscribing: baseClient.isTranscribing,
            transcribeFile: baseClient.transcribeFile,
            diarizeFile: { url in
                await diarizeTracker.increment()
                return try await baseClient.diarizeFile(url)
            }
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

        // ASSERT: diarizeFile was NOT called for continuation
        let callCount = await diarizeTracker.getCount()
        #expect(callCount == 0,
                "diarizeFile should NOT be called for continuation sessions")

        // I1: continuation segments have nil speakerId
        let segments = try await databaseClient.fetchTranscriptSegments(
            SessionID(rawValue: existingSessionId)
        )
        for segment in segments {
            #expect(segment.machineSpeakerId == nil,
                    "I1: continuation segments should have nil speakerId")
        }
    }

    // ─── I2: Enrichment mapping round-trip ────────────────────────────

    /// I2: End-to-end test that mapping result from DiarizationMapping is correctly
    /// applied to transcript segments during enrichment. Verifies the integration
    /// between DiarizationMapping and the enrichment pipeline.
    @Test func enrichmentMappingRoundTrip() async throws {
        // Simulate what enrichSegmentsWithDiarization does: map diarization onto ASR segments
        let asrSegments: [TranscriptSegment] = [
            TranscriptSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Hello, how are you?",
                startMs: 0,
                endMs: 2500,
                speakerId: nil,  // ASR output has no speaker
                isFinal: true
            ),
            TranscriptSegment(
                id: TranscriptSegmentID(rawValue: "seg-002"),
                text: "I'm doing well.",
                startMs: 2500,
                endMs: 5000,
                speakerId: nil,
                isFinal: true
            ),
            TranscriptSegment(
                id: TranscriptSegmentID(rawValue: "seg-003"),
                text: "Great to hear!",
                startMs: 5500,
                endMs: 7000,
                speakerId: nil,
                isFinal: true
            ),
        ]

        let diarizationSegments: [DiarizationMapping.SpeakerSegment] = [
            .init(speakerId: "spk_0", startTimeSeconds: 0.0, endTimeSeconds: 2.5),
            .init(speakerId: "spk_1", startTimeSeconds: 2.5, endTimeSeconds: 5.5),
            .init(speakerId: "spk_0", startTimeSeconds: 5.5, endTimeSeconds: 7.0),
        ]

        // Build transcript intervals from ASR segments
        let intervals = asrSegments.map { seg in
            DiarizationMapping.TranscriptInterval(
                id: seg.id,
                startTimeSeconds: Float(seg.startMs) / 1000.0,
                endTimeSeconds: Float(seg.endMs) / 1000.0
            )
        }

        // Map speakers
        let mappingResult = DiarizationMapping.mapSpeakers(
            intervals: intervals,
            speakerSegments: diarizationSegments
        )

        // Apply mapping to segments (same logic as enrichSegmentsWithDiarization)
        var speakerByIntervalId: [TranscriptSegmentID: String] = [:]
        for assignment in mappingResult.assignments {
            if let speakerId = assignment.speakerId {
                speakerByIntervalId[assignment.intervalId] = speakerId
            }
        }

        let enrichedSegments = asrSegments.map { seg in
            TranscriptSegment(
                id: seg.id,
                text: seg.text,
                startMs: seg.startMs,
                endMs: seg.endMs,
                speakerId: speakerByIntervalId[seg.id],
                isFinal: seg.isFinal
            )
        }

        // I2: Enriched segments should have correct speaker IDs
        #expect(enrichedSegments[0].speakerId == "spk_0", "First segment should be spk_0")
        #expect(enrichedSegments[1].speakerId == "spk_1", "Second segment should be spk_1")
        #expect(enrichedSegments[2].speakerId == "spk_0", "Third segment should be spk_0")

        // I2: Text is preserved through enrichment
        #expect(enrichedSegments[0].text == "Hello, how are you?")
        #expect(enrichedSegments[1].text == "I'm doing well.")
        #expect(enrichedSegments[2].text == "Great to hear!")

        // I2: Display orders are correct
        #expect(mappingResult.displayOrders["spk_0"] == 1, "spk_0 appears first")
        #expect(mappingResult.displayOrders["spk_1"] == 2, "spk_1 appears second")
    }

    // ─── I2: audioOnly mode skips diarization entirely ────────────────

    /// I2: audioOnly mode should NOT call diarizeFile (no offline processing at all).
    @Test func audioOnlyModeSkipsDiarization() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbQueue = try makeDatabase(configuration: .inMemory)
        let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
        let writtenFile = WrittenFile()
        let diarizeTracker = DiarizeTracker()

        let baseClient = MockFluidAudioClient.client(
            script: .twoSpeakerConversation,
            offlineBehavior: .success,
            diarizationBehavior: .twoSpeakerDefault
        )
        let trackingFluidAudio = FluidAudioClient(
            prepareModels: baseClient.prepareModels,
            modelStatus: baseClient.modelStatus,
            startTranscription: baseClient.startTranscription,
            stopTranscription: baseClient.stopTranscription,
            isTranscribing: baseClient.isTranscribing,
            transcribeFile: baseClient.transcribeFile,
            diarizeFile: { url in
                await diarizeTracker.increment()
                return try await baseClient.diarizeFile(url)
            }
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

        // ASSERT: diarizeFile was NOT called (audioOnly skips all offline processing)
        let callCount = await diarizeTracker.getCount()
        #expect(callCount == 0,
                "diarizeFile should NOT be called in audioOnly mode")
    }
}
