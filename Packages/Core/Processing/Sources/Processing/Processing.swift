import Foundation
import Models
import Audio
import Persistence
import Observability
import Dependencies
import DependenciesMacros

// MARK: - TranscriptSegment

/// A segment of transcribed audio
public struct TranscriptSegment: Sendable, Equatable {
    public let id: TranscriptSegmentID
    public let text: String
    public let startMs: UInt64
    public let endMs: UInt64
    public let speakerId: String?
    public let isFinal: Bool

    public init(
        id: TranscriptSegmentID,
        text: String,
        startMs: UInt64,
        endMs: UInt64,
        speakerId: String?,
        isFinal: Bool
    ) {
        self.id = id
        self.text = text
        self.startMs = startMs
        self.endMs = endMs
        self.speakerId = speakerId
        self.isFinal = isFinal
    }
}

// MARK: - ModelPreparationState

/// State of ML model preparation (download and loading)
public enum ModelPreparationState: Sendable, Equatable {
    /// Models have not been prepared yet
    case idle
    /// Models are currently being downloaded
    case downloading
    /// Models are ready to use
    case ready
    /// Model preparation failed with an error message
    case failed(String)
}

// MARK: - FluidAudioClient

/// Client for ML transcription and diarization (wraps FluidAudio SDK)
@DependencyClient
public struct FluidAudioClient: Sendable {
    /// Prepare ML models (download and load). This is idempotent - calling when already ready is a no-op.
    public var prepareModels: @Sendable () async -> Void
    /// Get the current model preparation status without triggering preparation
    public var modelStatus: @Sendable () async -> ModelPreparationState = { .idle }
    /// Start transcription on audio frames, returns a stream of transcript segments
    public var startTranscription: @Sendable (_ audioStream: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptSegment>
    /// Stop transcription
    public var stopTranscription: @Sendable () async -> Void
    /// Check if currently transcribing
    public var isTranscribing: @Sendable () async -> Bool = { false }
    /// Transcribe an entire audio file (offline processing). Returns all segments.
    public var transcribeFile: @Sendable (_ audioFileURL: URL) async throws -> [TranscriptSegment] = { _ in [] }
    /// Diarize an entire audio file using the offline (VBx) pipeline.
    /// Returns speaker segments with timing info (no DB writes).
    /// This runs full-file diarization in a single pass for stable speaker identities.
    public var diarizeFile: @Sendable (_ audioFileURL: URL) async throws -> [DiarizationMapping.SpeakerSegment] = { _ in [] }
}

extension FluidAudioClient: DependencyKey {
    public static var liveValue: Self { LiveFluidAudioClient.client() }

    public static var previewValue: Self {
        Self(
            prepareModels: { },
            modelStatus: { .ready },
            startTranscription: { _ in AsyncStream { $0.finish() } },
            stopTranscription: { },
            isTranscribing: { false },
            transcribeFile: { _ in [] },
            diarizeFile: { _ in [] }
        )
    }

    public static var testValue: Self { Self() }
}

extension DependencyValues {
    public var fluidAudioClient: FluidAudioClient {
        get { self[FluidAudioClient.self] }
        set { self[FluidAudioClient.self] = newValue }
    }
}

// MARK: - RecordingProcessorEvent

/// Events emitted by the recording processor
public enum RecordingProcessorEvent: Sendable, Equatable {
    case didStart(SessionID)
    case listeningChanged(Bool)
    case didAppendSegment(TranscriptSegmentID)
    case didPause
    case didResume
    case didFinish(SessionID)
    case didDiscard(SessionID)
    case didFail(String)
    /// Audio session was interrupted (e.g., phone call, Siri)
    case interrupted
    /// Audio session interruption ended
    case interruptionEnded(shouldResume: Bool)
    /// Audio route changed (e.g., headphones disconnected)
    case routeChanged(RouteChangeInfo)
    /// Transcription started successfully
    case transcriptionStarted
    /// Transcription failed to start (audio will still be recorded)
    case transcriptionUnavailable(String)
}

/// Information about an audio route change
public struct RouteChangeInfo: Sendable, Equatable {
    public let reason: AudioRouteChangeReason
    public let shouldRestartCapture: Bool

    public init(reason: AudioRouteChangeReason, shouldRestartCapture: Bool) {
        self.reason = reason
        self.shouldRestartCapture = shouldRestartCapture
    }
}

/// Reason for audio route change (mirrors Audio.RouteChangeReason for decoupling)
public enum AudioRouteChangeReason: Sendable, Equatable {
    case newDeviceAvailable
    case oldDeviceUnavailable
    case categoryChange
    case override
    case wakeFromSleep
    case noSuitableRouteForCategory
    case routeConfigurationChange
    case unknown
}

// MARK: - RecordingProcessorClient

/// Configuration for continuing an existing recording session
public struct ContinuationConfig: Sendable, Equatable {
    /// The session ID to continue
    public let sessionID: SessionID
    /// Timestamp offset in milliseconds (segments will have this added to their timestamps)
    public let timestampOffsetMs: Int

    public init(sessionID: SessionID, timestampOffsetMs: Int) {
        self.sessionID = sessionID
        self.timestampOffsetMs = timestampOffsetMs
    }
}

/// Client for orchestrating recording sessions
@DependencyClient
public struct RecordingProcessorClient: Sendable {
    /// Start a new recording session
    /// - Parameter audioDirectory: Directory where audio files should be saved
    /// - Returns: Stream of recording processor events
    public var startRecording: @Sendable (_ audioDirectory: URL) async throws -> AsyncStream<RecordingProcessorEvent>
    /// Continue an existing recording session (append new content)
    /// - Parameters:
    ///   - audioDirectory: Directory where audio files should be saved
    ///   - continuation: Configuration for the continuation (session ID and timestamp offset)
    /// - Returns: Stream of recording processor events
    public var continueRecording: @Sendable (_ audioDirectory: URL, _ continuation: ContinuationConfig) async throws -> AsyncStream<RecordingProcessorEvent> = { _, _ in AsyncStream { $0.finish() } }
    /// Stop the current recording session
    public var stopRecording: @Sendable () async -> Void
    /// Discard the current recording session (delete session and audio file)
    public var discardRecording: @Sendable () async -> Void
    /// Pause the current recording session
    public var pauseRecording: @Sendable () async -> Void
    /// Resume the current recording session
    public var resumeRecording: @Sendable () async -> Void
    /// Check if currently recording
    public var isRecording: @Sendable () async -> Bool = { false }
    /// Check if currently paused
    public var isPaused: @Sendable () async -> Bool = { false }
    /// Get the current session ID if recording
    public var currentSessionID: @Sendable () async -> SessionID? = { nil }
    /// Retry offline transcription for a failed/partial session
    /// - Parameter sessionId: The session ID to retry transcription for
    /// - Returns: true if retry succeeded, false otherwise
    public var retryOfflineTranscription: @Sendable (_ sessionId: SessionID) async throws -> Bool = { _ in false }
}

extension RecordingProcessorClient: DependencyKey {
    /// Creates a new client instance wrapping a new RecordingProcessor.
    /// Call this within a dependency injection context to use injected dependencies.
    public static func live() -> Self {
        let processor = RecordingProcessor()
        return Self(
            startRecording: { audioDirectory in
                try await processor.startRecording(audioDirectory: audioDirectory)
            },
            continueRecording: { audioDirectory, continuation in
                try await processor.continueRecording(audioDirectory: audioDirectory, continuation: continuation)
            },
            stopRecording: {
                await processor.stopRecording()
            },
            discardRecording: {
                await processor.discardRecording()
            },
            pauseRecording: {
                await processor.pauseRecording()
            },
            resumeRecording: {
                await processor.resumeRecording()
            },
            isRecording: {
                await processor.getIsRecording()
            },
            isPaused: {
                await processor.getIsPaused()
            },
            currentSessionID: {
                await processor.getCurrentSessionID()
            },
            retryOfflineTranscription: { sessionId in
                try await processor.retryOfflineTranscription(sessionId: sessionId)
            }
        )
    }

    public static var liveValue: Self { live() }

    public static var previewValue: Self {
        Self(
            startRecording: { _ in AsyncStream { $0.finish() } },
            continueRecording: { _, _ in AsyncStream { $0.finish() } },
            stopRecording: { },
            discardRecording: { },
            pauseRecording: { },
            resumeRecording: { },
            isRecording: { false },
            isPaused: { false },
            currentSessionID: { nil },
            retryOfflineTranscription: { _ in false }
        )
    }

    public static var testValue: Self { Self() }
}

extension DependencyValues {
    public var recordingProcessorClient: RecordingProcessorClient {
        get { self[RecordingProcessorClient.self] }
        set { self[RecordingProcessorClient.self] = newValue }
    }
}

// MARK: - RecordingProcessor Actor

/// Actor that orchestrates a recording session: audio capture, ML transcription, and persistence
public actor RecordingProcessor {
    @Dependency(\.audioCaptureClient) var audioCaptureClient
    @Dependency(\.audioFileWriterClient) var audioFileWriterClient
    @Dependency(\.audioSessionClient) var audioSessionClient
    @Dependency(\.fluidAudioClient) var fluidAudioClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.preferencesClient) var preferencesClient
    @Dependency(\.titleGeneratorClient) var titleGeneratorClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    private var currentSessionID: SessionID?
    private var currentAudioFileURL: URL?
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    private var isInterrupted: Bool = false
    private var seenSpeakers: Set<String> = []
    private var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
    private var audioSessionTask: Task<Void, Never>?

    // Continuation mode state
    private var isContinuation: Bool = false
    private var timestampOffsetMs: Int = 0

    // Title generation state
    private var accumulatedTranscriptText: String = ""
    private var titleGenerationTriggered: Bool = false

    public init() {}

    /// Start a new recording session
    /// - Parameters:
    ///   - audioDirectory: Directory where audio files should be saved
    /// - Returns: Stream of recording processor events
    public func startRecording(audioDirectory: URL) async throws -> AsyncStream<RecordingProcessorEvent> {
        guard !isRecording else {
            throw RecordingProcessorError.alreadyRecording
        }

        isRecording = true
        seenSpeakers = []
        accumulatedTranscriptText = ""
        titleGenerationTriggered = false
        isContinuation = false
        timestampOffsetMs = 0

        // Create event stream
        let (stream, continuation) = AsyncStream.makeStream(of: RecordingProcessorEvent.self)
        self.eventContinuation = continuation

        // Generate session ID and create session record
        let sessionId = SessionID(rawValue: uuid().uuidString)
        self.currentSessionID = sessionId
        let now = date.now

        let sessionRecord = SessionRecord(
            id: sessionId.rawValue,
            startedAt: now,
            processingState: .recording,
            updatedAt: now
        )
        try await databaseClient.createSession(sessionRecord)

        // Emit didStart event
        continuation.yield(.didStart(sessionId))

        // Configure audio session for recording (required on iOS before AVAudioEngine can access mic)
        try await audioSessionClient.configureForRecording()

        // Get the actual input format from the microphone (must be after audio session is configured)
        let inputFormat = audioCaptureClient.getInputFormat()

        // Start audio file writing with the actual microphone format
        let audioPath = audioDirectory.appendingPathComponent("\(sessionId.rawValue).m4a")
        self.currentAudioFileURL = audioPath
        try await audioFileWriterClient.startWriting(audioPath, inputFormat)

        // Start audio capture
        let audioStream = try await audioCaptureClient.startCapture()

        // Emit listening changed
        continuation.yield(.listeningChanged(true))

        // Fork audio stream for file writing and ML
        let (writerStream, mlStream) = forkAudioStream(audioStream)

        // Process audio frames for file writing in background
        Task { [weak self] in
            for await frame in writerStream {
                guard let self = self, await self.getIsRecording() else { break }
                try? await self.audioFileWriterClient.appendFrame(frame)
            }
        }

        // Start ML transcription in background (may download models on first use)
        Task { [weak self, fluidAudioClient] in
            guard let self = self else { return }
            do {
                NSLog("[RecordingProcessor] Starting transcription...")
                let segmentStream = try await fluidAudioClient.startTranscription(mlStream)
                NSLog("[RecordingProcessor] Transcription started, emitting event")
                await self.emitTranscriptionStarted()
                var segmentCount = 0
                for await segment in segmentStream {
                    guard await self.getIsRecording() else {
                        NSLog("[RecordingProcessor] Recording stopped, breaking segment loop")
                        break
                    }
                    segmentCount += 1
                    NSLog("[RecordingProcessor] Received segment \(segmentCount): '\(segment.text)'")
                    await self.handleSegment(segment, sessionId: sessionId)
                }
                NSLog("[RecordingProcessor] Segment stream ended after \(segmentCount) segments")
            } catch {
                // Emit event so UI can inform user - audio recording continues
                let errorMessage = "Live transcription unavailable: \(error.localizedDescription)"
                NSLog("[RecordingProcessor] Transcription error: \(errorMessage)")
                await self.emitTranscriptionUnavailable(errorMessage)
            }
        }

        // Start observing audio session events (interruptions, route changes)
        let audioSessionStream = await audioSessionClient.startObserving()
        audioSessionTask = Task { [weak self] in
            for await event in audioSessionStream {
                guard let self = self else { break }
                guard await self.getIsRecording() else { break }
                await self.handleAudioSessionEvent(event)
            }
        }

        return stream
    }

    /// Continue an existing recording session (append new audio and transcript)
    /// - Parameters:
    ///   - audioDirectory: Directory where audio files should be saved
    ///   - continuation: Configuration for the continuation (session ID and timestamp offset)
    /// - Returns: Stream of recording processor events
    public func continueRecording(audioDirectory: URL, continuation config: ContinuationConfig) async throws -> AsyncStream<RecordingProcessorEvent> {
        guard !isRecording else {
            throw RecordingProcessorError.alreadyRecording
        }

        // Verify the session exists
        guard let session = try await databaseClient.fetchSession(config.sessionID) else {
            throw RecordingProcessorError.sessionNotFound
        }

        // Verify session is in a state that can be continued (processed or partial)
        guard session.processingState == .processed || session.processingState == .partial else {
            throw RecordingProcessorError.invalidStateForContinuation(session.processingState)
        }

        isRecording = true
        isContinuation = true
        timestampOffsetMs = config.timestampOffsetMs
        accumulatedTranscriptText = ""
        titleGenerationTriggered = true // Don't regenerate title for continuations

        // Load existing speakers for this session
        let existingTracks = try await databaseClient.fetchSpeakerTracks(config.sessionID)
        seenSpeakers = Set(existingTracks.map(\.machineSpeakerId))

        // Create event stream
        let (stream, eventContinuation) = AsyncStream.makeStream(of: RecordingProcessorEvent.self)
        self.eventContinuation = eventContinuation

        // Use the existing session ID
        let sessionId = config.sessionID
        self.currentSessionID = sessionId

        // Update session to recording state
        var updatedSession = session
        updatedSession.processingState = .recording
        updatedSession.updatedAt = date.now
        try await databaseClient.updateSession(updatedSession)

        // Emit didStart event with the existing session ID
        eventContinuation.yield(.didStart(sessionId))

        // Configure audio session for recording
        try await audioSessionClient.configureForRecording()

        // Get the actual input format from the microphone
        let inputFormat = audioCaptureClient.getInputFormat()

        // Start audio file writing to a continuation file
        // Use a unique suffix to avoid overwriting the original audio
        let continuationSuffix = "_cont_\(Int(date.now.timeIntervalSince1970))"
        let audioPath = audioDirectory.appendingPathComponent("\(sessionId.rawValue)\(continuationSuffix).m4a")
        self.currentAudioFileURL = audioPath
        try await audioFileWriterClient.startWriting(audioPath, inputFormat)

        // Start audio capture
        let audioStream = try await audioCaptureClient.startCapture()

        // Emit listening changed
        eventContinuation.yield(.listeningChanged(true))

        // Fork audio stream for file writing and ML
        let (writerStream, mlStream) = forkAudioStream(audioStream)

        // Process audio frames for file writing in background
        Task { [weak self] in
            for await frame in writerStream {
                guard let self = self, await self.getIsRecording() else { break }
                try? await self.audioFileWriterClient.appendFrame(frame)
            }
        }

        // Start ML transcription in background
        Task { [weak self, fluidAudioClient] in
            guard let self = self else { return }
            do {
                NSLog("[RecordingProcessor] Starting continuation transcription with offset \(config.timestampOffsetMs)ms...")
                let segmentStream = try await fluidAudioClient.startTranscription(mlStream)
                NSLog("[RecordingProcessor] Continuation transcription started, emitting event")
                await self.emitTranscriptionStarted()
                var segmentCount = 0
                for await segment in segmentStream {
                    guard await self.getIsRecording() else {
                        NSLog("[RecordingProcessor] Recording stopped, breaking segment loop")
                        break
                    }
                    segmentCount += 1
                    NSLog("[RecordingProcessor] Received continuation segment \(segmentCount): '\(segment.text)'")
                    await self.handleSegment(segment, sessionId: sessionId)
                }
                NSLog("[RecordingProcessor] Continuation segment stream ended after \(segmentCount) segments")
            } catch {
                let errorMessage = "Live transcription unavailable: \(error.localizedDescription)"
                NSLog("[RecordingProcessor] Continuation transcription error: \(errorMessage)")
                await self.emitTranscriptionUnavailable(errorMessage)
            }
        }

        // Start observing audio session events
        let audioSessionStream = await audioSessionClient.startObserving()
        audioSessionTask = Task { [weak self] in
            for await event in audioSessionStream {
                guard let self = self else { break }
                guard await self.getIsRecording() else { break }
                await self.handleAudioSessionEvent(event)
            }
        }

        return stream
    }

    /// Stop the current recording session
    public func stopRecording() async {
        guard isRecording else { return }

        isRecording = false
        isPaused = false
        isInterrupted = false

        // Stop audio session observation
        audioSessionTask?.cancel()
        audioSessionTask = nil
        await audioSessionClient.stopObserving()

        // Stop capture and transcription
        await audioCaptureClient.stopCapture()
        await fluidAudioClient.stopTranscription()

        // Finish writing audio file
        _ = try? await audioFileWriterClient.finishWriting()

        // Emit listening changed
        eventContinuation?.yield(.listeningChanged(false))

        // Finalize session
        if let sessionId = currentSessionID {
            await finalizeSession(sessionId, audioFileURL: currentAudioFileURL)
        }

        currentSessionID = nil
        currentAudioFileURL = nil
        eventContinuation?.finish()
        eventContinuation = nil
    }

    /// Discard the current recording session (delete session and audio file)
    public func discardRecording() async {
        guard isRecording else { return }
        guard let sessionId = currentSessionID else { return }

        isRecording = false
        isPaused = false
        isInterrupted = false

        // Stop audio session observation
        audioSessionTask?.cancel()
        audioSessionTask = nil
        await audioSessionClient.stopObserving()

        // Stop capture and transcription
        await audioCaptureClient.stopCapture()
        await fluidAudioClient.stopTranscription()

        // Cancel writing (don't finalize the file)
        await audioFileWriterClient.cancelWriting()

        // Emit listening changed
        eventContinuation?.yield(.listeningChanged(false))

        // Delete session and all related data from database
        try? await databaseClient.deleteSession(sessionId)

        // Emit discard event
        eventContinuation?.yield(.didDiscard(sessionId))

        currentSessionID = nil
        eventContinuation?.finish()
        eventContinuation = nil
    }

    /// Pause the current recording session
    public func pauseRecording() async {
        guard isRecording, !isPaused else { return }

        isPaused = true

        // Pause audio capture (stops listening but keeps session active)
        await audioCaptureClient.stopCapture()

        // Emit events
        eventContinuation?.yield(.listeningChanged(false))
        eventContinuation?.yield(.didPause)
    }

    /// Resume the current recording session
    public func resumeRecording() async {
        guard isRecording, isPaused else { return }

        isPaused = false

        // Resume audio capture
        // Note: We restart capture but the file writer and ML pipeline are still running
        do {
            _ = try await audioCaptureClient.startCapture()
            eventContinuation?.yield(.listeningChanged(true))
            eventContinuation?.yield(.didResume)
        } catch {
            eventContinuation?.yield(.didFail("Failed to resume recording: \(error.localizedDescription)"))
        }
    }

    /// Check if currently recording
    public func getIsRecording() -> Bool {
        isRecording
    }

    /// Check if currently paused
    public func getIsPaused() -> Bool {
        isPaused
    }

    /// Get the current session ID
    public func getCurrentSessionID() -> SessionID? {
        currentSessionID
    }

    /// Check if currently interrupted
    public func getIsInterrupted() -> Bool {
        isInterrupted
    }

    // MARK: - Private Helpers

    /// Handle audio session events (interruptions and route changes)
    private func handleAudioSessionEvent(_ event: AudioSessionEvent) async {
        switch event {
        case .interrupted(let type):
            await handleInterruption(type)
        case .routeChanged(let reason):
            await handleRouteChange(reason)
        }
    }

    /// Handle audio session interruption
    private func handleInterruption(_ type: InterruptionType) async {
        switch type {
        case .began:
            guard !isInterrupted else { return }
            isInterrupted = true

            // Pause capture during interruption
            await audioCaptureClient.stopCapture()

            // Emit events
            eventContinuation?.yield(.listeningChanged(false))
            eventContinuation?.yield(.interrupted)

        case .ended(let shouldResume):
            guard isInterrupted else { return }
            isInterrupted = false

            eventContinuation?.yield(.interruptionEnded(shouldResume: shouldResume))

            // Auto-resume if the system indicates we should and we're not manually paused
            if shouldResume && !isPaused {
                do {
                    _ = try await audioCaptureClient.startCapture()
                    eventContinuation?.yield(.listeningChanged(true))
                } catch {
                    eventContinuation?.yield(.didFail("Failed to resume after interruption: \(error.localizedDescription)"))
                }
            }
        }
    }

    /// Handle audio route change
    private func handleRouteChange(_ reason: RouteChangeReason) async {
        let processingReason = mapRouteChangeReason(reason)
        let shouldRestartCapture = shouldRestartCaptureForRouteChange(reason)

        eventContinuation?.yield(.routeChanged(RouteChangeInfo(
            reason: processingReason,
            shouldRestartCapture: shouldRestartCapture
        )))

        // Restart capture if needed (e.g., when old device became unavailable)
        if shouldRestartCapture && !isPaused && !isInterrupted {
            // Stop current capture
            await audioCaptureClient.stopCapture()

            // Restart capture with new route
            do {
                _ = try await audioCaptureClient.startCapture()
                eventContinuation?.yield(.listeningChanged(true))
            } catch {
                eventContinuation?.yield(.didFail("Failed to restart capture after route change: \(error.localizedDescription)"))
            }
        }
    }

    /// Map Audio.RouteChangeReason to Processing.AudioRouteChangeReason
    private func mapRouteChangeReason(_ reason: RouteChangeReason) -> AudioRouteChangeReason {
        switch reason {
        case .newDeviceAvailable: return .newDeviceAvailable
        case .oldDeviceUnavailable: return .oldDeviceUnavailable
        case .categoryChange: return .categoryChange
        case .override: return .override
        case .wakeFromSleep: return .wakeFromSleep
        case .noSuitableRouteForCategory: return .noSuitableRouteForCategory
        case .routeConfigurationChange: return .routeConfigurationChange
        case .unknown: return .unknown
        }
    }

    /// Determine if capture should be restarted for a given route change
    private func shouldRestartCaptureForRouteChange(_ reason: RouteChangeReason) -> Bool {
        switch reason {
        case .oldDeviceUnavailable:
            // Device was unplugged - restart capture to use new route
            return true
        case .noSuitableRouteForCategory:
            // No suitable route - may need to restart when one becomes available
            return true
        default:
            // For other changes, capture continues normally
            return false
        }
    }

    private func handleSegment(_ segment: TranscriptSegment, sessionId: SessionID) async {
        let now = date.now

        // Create speaker track if this is a new speaker
        if let speakerId = segment.speakerId, !seenSpeakers.contains(speakerId) {
            seenSpeakers.insert(speakerId)
            let displayOrder = seenSpeakers.count
            let trackId = uuid().uuidString

            let speakerTrack = SpeakerTrackRecord(
                id: trackId,
                sessionId: sessionId.rawValue,
                machineSpeakerId: speakerId,
                displayOrder: displayOrder
            )
            try? await databaseClient.createSpeakerTrack(speakerTrack)
        }

        // Apply timestamp offset for continuation mode
        let adjustedStartMs = Int(segment.startMs) + timestampOffsetMs
        let adjustedEndMs = Int(segment.endMs) + timestampOffsetMs

        // Create transcript segment record
        let segmentRecord = TranscriptSegmentRecord(
            id: segment.id.rawValue,
            sessionId: sessionId.rawValue,
            startMs: adjustedStartMs,
            endMs: adjustedEndMs,
            machineSpeakerId: segment.speakerId,
            text: segment.text,
            isFinal: segment.isFinal,
            createdAt: now,
            updatedAt: now
        )

        do {
            try await databaseClient.createTranscriptSegment(segmentRecord)
            eventContinuation?.yield(.didAppendSegment(segment.id))
        } catch {
            // Segment may already exist (partial update), try updating
            try? await databaseClient.updateTranscriptSegment(segmentRecord)
            eventContinuation?.yield(.didAppendSegment(segment.id))
        }

        // The single live segment's text IS the full accumulated transcript
        accumulatedTranscriptText = segment.text

        // Trigger title generation after 15 seconds of transcript
        if !titleGenerationTriggered && segment.endMs >= 15_000 {
            titleGenerationTriggered = true
            let textSnapshot = accumulatedTranscriptText
            let sessionIdSnapshot = sessionId

            Task { [databaseClient, titleGeneratorClient, date] in
                guard titleGeneratorClient.isAvailable() else { return }

                do {
                    guard let title = try await titleGeneratorClient.generateTitle(textSnapshot) else { return }
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\"", with: "")
                    guard !trimmedTitle.isEmpty else { return }

                    // Update session title if not already set by user
                    if var session = try await databaseClient.fetchSession(sessionIdSnapshot),
                       session.title == nil {
                        session.title = trimmedTitle
                        session.updatedAt = date.now
                        try await databaseClient.updateSession(session)
                        NSLog("[TitleGeneration] Auto-generated title: '%@' for session %@", trimmedTitle, sessionIdSnapshot.rawValue)
                    }
                } catch {
                    NSLog("[TitleGeneration] Failed to generate title: %@", error.localizedDescription)
                    // Silent failure - title generation is best-effort
                }
            }
        }
    }

    private func emitTranscriptionStarted() {
        eventContinuation?.yield(.transcriptionStarted)
    }

    private func emitTranscriptionUnavailable(_ message: String) {
        eventContinuation?.yield(.transcriptionUnavailable(message))
    }

    /// Generate title at finalization for short recordings that didn't trigger live generation
    private func generateTitleAtFinalization(text: String, sessionId: SessionID) async {
        guard titleGeneratorClient.isAvailable() else {
            NSLog("[TitleGeneration] Skipping finalization title generation - unavailable")
            return
        }

        do {
            guard let title = try await titleGeneratorClient.generateTitle(text) else {
                NSLog("[TitleGeneration] Finalization title generation returned nil")
                return
            }
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
            guard !trimmedTitle.isEmpty else {
                NSLog("[TitleGeneration] Finalization title was empty after trimming")
                return
            }

            // Update session title if not already set by user
            if var sessionToUpdate = try await databaseClient.fetchSession(sessionId),
               sessionToUpdate.title == nil {
                sessionToUpdate.title = trimmedTitle
                sessionToUpdate.updatedAt = date.now
                try await databaseClient.updateSession(sessionToUpdate)
                NSLog("[TitleGeneration] Finalization auto-generated title: '%@' for session %@", trimmedTitle, sessionId.rawValue)
            }
        } catch {
            NSLog("[TitleGeneration] Finalization title generation failed: %@", error.localizedDescription)
            // Silent failure - title generation is best-effort
        }
    }

    private func finalizeSession(_ sessionId: SessionID, audioFileURL: URL?) async {
        let now = date.now

        // Fetch current session
        guard var session = try? await databaseClient.fetchSession(sessionId) else {
            eventContinuation?.yield(.didFail("Failed to fetch session for finalization"))
            return
        }

        // Fetch segments to compute preview text and duration
        let segments = (try? await databaseClient.fetchTranscriptSegments(sessionId)) ?? []

        // Compute preview text from first few segments
        let previewText = segments
            .filter { $0.isFinal }
            .prefix(3)
            .map { $0.text }
            .joined(separator: " ")

        // For continuation mode, compute duration from max segment timestamp
        // (which already includes the offset). For new recordings, use elapsed time.
        let durationMs: Int
        if isContinuation {
            // Use the max segment end time (includes offset from previous recording)
            durationMs = segments.map { $0.endMs }.max() ?? (session.durationMs ?? 0)
            NSLog("[Finalize] Continuation mode - computed duration from segments: %dms", durationMs)
        } else {
            // Compute duration from actual recording time (startedAt to now)
            // Fall back to transcript segments if available, but prefer actual elapsed time
            let elapsedMs = Int(now.timeIntervalSince(session.startedAt) * 1000)
            let segmentDurationMs = segments.map { $0.endMs }.max() ?? 0
            durationMs = max(elapsedMs, segmentDurationMs)
        }

        // Update session - set to transcribing state first
        session.endedAt = now
        session.previewText = previewText.isEmpty ? nil : String(previewText.prefix(200))
        session.durationMs = durationMs
        session.speakerCount = seenSpeakers.count
        session.updatedAt = now

        // ────────────────────────────────────────────────────────────────────
        // CONTINUATION POLICY
        //
        // Continuations record a NEW audio segment appended to an existing session.
        // The continuation audio file only covers the appended portion, NOT the full
        // session, so full-file offline transcription and diarization are not meaningful.
        //
        // Policy:
        //   1. Live transcript segments are persisted with speakerId=nil (no live diarization).
        //   2. Offline transcription is SKIPPED because the continuation audio is partial.
        //   3. Speaker enrichment for the continuation portion is deferred to a future
        //      re-diarize pass over the combined audio (not yet implemented).
        //   4. The session transitions directly to .processed.
        //   5. The original session audioPath is preserved (points to the initial recording).
        //      The continuation audio file is stored separately but not tracked in the
        //      session record.
        //
        // Valid state transitions:
        //   .recording -> .processed  (always, for continuations)
        //
        // Speaker outcome:
        //   Continuation segments have machineSpeakerId=nil. Existing speaker tracks from
        //   the original recording are preserved. A future combined-diarize feature could
        //   enrich all segments together.
        // ────────────────────────────────────────────────────────────────────
        if isContinuation {
            session.processingState = .processed
            NSLog("[Finalize] Continuation mode - marking as processed without offline transcription")

            do {
                try await databaseClient.updateSession(session)
                eventContinuation?.yield(.didFinish(sessionId))
            } catch {
                NSLog("[Finalize] ERROR: %@", String(describing: error))
                eventContinuation?.yield(.didFail("Failed to finalize continuation session: \(error)"))
            }
            return
        }

        // ────────────────────────────────────────────────────────────────────
        // RETENTION POLICY (non-continuation, normal recordings)
        //
        // AudioRetentionMode determines what happens to audio and transcription
        // after recording stops. Three modes exist:
        //
        // .both (default):
        //   - Audio file is KEPT.
        //   - Offline transcription runs (replaces live segments with higher-quality output).
        //   - Speaker enrichment (diarization) runs as part of offline transcription.
        //   - State transitions: .recording -> .transcribing -> .processed
        //   - On failure: .recording -> .transcribing -> .partial (has live segments)
        //                                              -> .failed  (no segments at all)
        //
        // .transcriptOnly:
        //   - Offline transcription runs FIRST (to get higher-quality segments + speakers).
        //   - After offline transcription completes (success or failure), the audio file
        //     is DELETED and audioPath is cleared.
        //   - This ensures speaker enrichment still happens for privacy-conscious users
        //     who don't want to retain audio long-term.
        //   - State transitions: .recording -> .transcribing -> .processed (audio deleted)
        //   - On failure: .recording -> .transcribing -> .partial/.failed (audio deleted)
        //   - Retry is NOT possible after audio deletion (no audio file to re-process).
        //
        // .audioOnly:
        //   - Audio file is KEPT.
        //   - Offline transcription is SKIPPED (user chose audio-only).
        //   - No speaker enrichment.
        //   - State transitions: .recording -> .processed
        //
        // Edge case: no audio file URL:
        //   - Offline transcription is SKIPPED (nothing to process).
        //   - State transitions: .recording -> .processed
        // ────────────────────────────────────────────────────────────────────
        let retentionMode = preferencesClient.getAudioRetentionMode()

        // Determine processing behavior from retention mode
        let isTranscriptOnly = retentionMode == .transcriptOnly
        let isAudioOnly = retentionMode == .audioOnly
        let canRunOfflineTranscription = audioFileURL != nil && !isAudioOnly

        if canRunOfflineTranscription {
            // Offline transcription will run (both or transcriptOnly modes)
            session.processingState = .transcribing
            // Always set audioPath for offline transcription to find the file
            session.audioPath = audioFileURL?.path
        } else {
            // No offline transcription (audioOnly mode or no audio file)
            session.processingState = .processed
            session.audioPath = audioFileURL?.path
        }

        do {
            NSLog("[Finalize] Updating session state to: %@, retentionMode: %@", session.processingState.rawValue, retentionMode.rawValue)
            try await databaseClient.updateSession(session)
            NSLog("[Finalize] Session updated, emitting didFinish event")
            // Emit didFinish so UI can navigate to detail view
            eventContinuation?.yield(.didFinish(sessionId))

            // Generate title at finalization if not already generated (handles short recordings)
            // This is a fallback for recordings that didn't reach 15 seconds during live transcription
            if !titleGenerationTriggered && !accumulatedTranscriptText.isEmpty {
                await generateTitleAtFinalization(
                    text: accumulatedTranscriptText,
                    sessionId: sessionId
                )
            }

            // Start offline transcription if needed
            if canRunOfflineTranscription, let audioURL = audioFileURL {
                // transcriptOnly: ensure audio cleanup runs even if offline transcription
                // is interrupted (cancellation, crash recovery handles true process death)
                if isTranscriptOnly {
                    defer {
                        NSLog("[Finalize] transcriptOnly mode - deleting audio after offline transcription")
                        try? FileManager.default.removeItem(at: audioURL)
                    }
                    NSLog("[Finalize] Starting offline transcription (transcriptOnly)...")
                    await runOfflineTranscription(sessionId: sessionId, audioFileURL: audioURL)
                    NSLog("[Finalize] Offline transcription completed (transcriptOnly)")
                } else {
                    NSLog("[Finalize] Starting offline transcription...")
                    await runOfflineTranscription(sessionId: sessionId, audioFileURL: audioURL)
                    NSLog("[Finalize] Offline transcription completed")
                }

                // transcriptOnly: clear audioPath in DB after audio file is deleted
                if isTranscriptOnly {
                    if var updatedSession = try? await databaseClient.fetchSession(sessionId) {
                        updatedSession.audioPath = nil
                        updatedSession.updatedAt = date.now
                        try? await databaseClient.updateSession(updatedSession)
                    }
                    NSLog("[Finalize] audioPath cleared in DB")
                }
            } else {
                NSLog("[Finalize] Skipping offline transcription (canRun=%d, hasAudio=%d)", canRunOfflineTranscription ? 1 : 0, audioFileURL != nil ? 1 : 0)
            }
        } catch {
            NSLog("[Finalize] ERROR: %@", String(describing: error))
            eventContinuation?.yield(.didFail("Failed to finalize session: \(error)"))
        }
    }

    /// Timeout for offline transcription (5 minutes)
    private static let offlineTranscriptionTimeout: TimeInterval = 5 * 60

    /// Timeout for full-file diarization (5 minutes)
    private static let diarizationTimeout: TimeInterval = 5 * 60

    /// Run offline transcription on the saved audio file
    /// This provides a higher quality full-pass transcription after recording stops
    private func runOfflineTranscription(sessionId: SessionID, audioFileURL: URL) async {
        NSLog("[OfflineTranscription] Starting for session \(sessionId.rawValue)")
        NSLog("[OfflineTranscription] Audio file URL: \(audioFileURL.path)")

        // Check if audio file exists
        let fileExists = FileManager.default.fileExists(atPath: audioFileURL.path)
        NSLog("[OfflineTranscription] Audio file exists: \(fileExists)")

        guard fileExists else {
            NSLog("[OfflineTranscription] ERROR: Audio file does not exist, keeping live transcription")
            // Just mark as processed, keep live transcription
            do {
                if var session = try await databaseClient.fetchSession(sessionId) {
                    session.processingState = .processed
                    session.updatedAt = date.now
                    try await databaseClient.updateSession(session)
                }
            } catch {
                NSLog("[OfflineTranscription] ERROR updating session: \(error)")
            }
            return
        }

        do {
            // Run offline transcription on the saved audio file with timeout
            // Do this BEFORE deleting live segments so we don't lose them on failure
            NSLog("[OfflineTranscription] Calling transcribeFile with \(Self.offlineTranscriptionTimeout)s timeout...")
            let segments = try await withThrowingTaskGroup(of: [TranscriptSegment].self) { group in
                group.addTask { [fluidAudioClient] in
                    try await fluidAudioClient.transcribeFile(audioFileURL)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(Self.offlineTranscriptionTimeout))
                    throw OfflineTranscriptionError.timeout
                }
                // Return result from whichever task finishes first
                guard let result = try await group.next() else {
                    throw OfflineTranscriptionError.timeout
                }
                group.cancelAll()
                return result
            }
            NSLog("[OfflineTranscription] Got \(segments.count) segments from file")

            // If offline transcription returned no segments, keep the live transcription
            guard !segments.isEmpty else {
                NSLog("[OfflineTranscription] No segments from offline transcription, keeping live transcription")
                if var session = try await databaseClient.fetchSession(sessionId) {
                    session.processingState = .processed
                    session.updatedAt = date.now
                    try await databaseClient.updateSession(session)
                }
                return
            }

            // ────────────────────────────────────────────────────────────────
            // POST-STOP SPEAKER ENRICHMENT
            //
            // After ASR transcription succeeds, run full-file diarization to
            // get stable speaker identities across the entire recording. Map
            // diarization results onto transcript intervals using overlap-based
            // assignment. If diarization fails, preserve transcript text without
            // speaker labels (invariant I3).
            // ────────────────────────────────────────────────────────────────
            let enrichedSegments = await enrichSegmentsWithDiarization(
                segments: segments,
                audioFileURL: audioFileURL,
                logPrefix: "[OfflineTranscription]"
            )

            // Only delete existing segments AFTER we successfully got offline segments
            try await databaseClient.deleteTranscriptSegmentsForSession(sessionId)
            NSLog("[OfflineTranscription] Deleted existing transcript segments")

            // Delete existing speaker tracks and recreate them based on enriched results
            try await databaseClient.deleteSpeakerTracksForSession(sessionId)

            // Persist enriched segments and build speaker tracks
            let speakerCount = try await persistEnrichedSegments(
                enrichedSegments,
                sessionId: sessionId,
                logPrefix: "[OfflineTranscription]"
            )

            // Update session to processed state
            if var session = try await databaseClient.fetchSession(sessionId) {
                // Recompute preview text from offline segments
                let previewText = enrichedSegments
                    .filter { $0.isFinal }
                    .prefix(3)
                    .map { $0.text }
                    .joined(separator: " ")

                session.previewText = previewText.isEmpty ? nil : String(previewText.prefix(200))
                session.speakerCount = speakerCount
                session.processingState = .processed
                session.updatedAt = date.now
                try await databaseClient.updateSession(session)
                NSLog("[OfflineTranscription] Session marked as processed")
            }
        } catch {
            NSLog("[OfflineTranscription] ERROR type: \(type(of: error))")
            NSLog("[OfflineTranscription] ERROR description: \(String(describing: error))")
            NSLog("[OfflineTranscription] ERROR localizedDescription: \(error.localizedDescription)")
            if let liveError = error as? LiveFluidAudioClientError {
                NSLog("[OfflineTranscription] ERROR is LiveFluidAudioClientError: \(liveError)")
            }
            if let offlineError = error as? OfflineTranscriptionError {
                NSLog("[OfflineTranscription] ERROR is OfflineTranscriptionError: \(offlineError)")
            }
            // Mark session as failed with error message, but keep live transcription segments
            // Live segments are still available since we only delete after successful offline transcription
            do {
                if var session = try await databaseClient.fetchSession(sessionId) {
                    // Check if there are live segments - if so, mark as partial; otherwise failed
                    let existingSegments = (try? await databaseClient.fetchTranscriptSegments(sessionId)) ?? []
                    let hasLiveSegments = !existingSegments.isEmpty

                    session.processingState = hasLiveSegments ? .partial : .failed
                    session.processingError = "Offline transcription failed: \(error.localizedDescription)"
                    session.updatedAt = date.now
                    try await databaseClient.updateSession(session)
                    NSLog("[OfflineTranscription] Session marked as \(session.processingState.rawValue) with error: \(session.processingError ?? "unknown")")
                }
            } catch {
                // Silent failure - recovery routine will clean up
            }
        }
    }

    // MARK: - Post-Stop Speaker Enrichment Helpers

    /// Enrich ASR transcript segments with full-file diarization speaker IDs.
    ///
    /// Runs `diarizeFile` on the audio, then maps speaker segments onto transcript
    /// intervals using `DiarizationMapping.mapSpeakers`. On diarization failure,
    /// returns the original segments with `speakerId = nil` (text preserved, I3).
    ///
    /// - Parameters:
    ///   - segments: ASR transcript segments (may already have per-chunk speaker IDs).
    ///   - audioFileURL: URL to the audio file for full-file diarization.
    ///   - logPrefix: Log prefix for consistent logging context.
    /// - Returns: Enriched segments with full-file speaker IDs, or original segments
    ///   with nil speakers on diarization failure.
    private func enrichSegmentsWithDiarization(
        segments: [TranscriptSegment],
        audioFileURL: URL,
        logPrefix: String
    ) async -> [TranscriptSegment] {
        NSLog("\(logPrefix) Starting post-stop speaker enrichment via full-file diarization...")

        // Attempt full-file diarization with timeout
        let speakerSegments: [DiarizationMapping.SpeakerSegment]
        do {
            speakerSegments = try await withThrowingTaskGroup(of: [DiarizationMapping.SpeakerSegment].self) { group in
                group.addTask { [fluidAudioClient] in
                    try await fluidAudioClient.diarizeFile(audioFileURL)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(Self.diarizationTimeout))
                    throw OfflineTranscriptionError.timeout
                }
                guard let result = try await group.next() else {
                    throw OfflineTranscriptionError.timeout
                }
                group.cancelAll()
                return result
            }
            NSLog("\(logPrefix) Diarization returned \(speakerSegments.count) speaker segments")
        } catch {
            NSLog("\(logPrefix) Diarization failed: \(error.localizedDescription) — preserving transcript without speaker labels")
            // Return segments with speakerId stripped (don't trust per-chunk diarization
            // when full-file diarization was requested but failed)
            return segments.map { seg in
                TranscriptSegment(
                    id: seg.id,
                    text: seg.text,
                    startMs: seg.startMs,
                    endMs: seg.endMs,
                    speakerId: nil,
                    isFinal: seg.isFinal
                )
            }
        }

        // If diarization returned no speaker segments, return segments without speaker IDs
        guard !speakerSegments.isEmpty else {
            NSLog("\(logPrefix) Diarization returned 0 speaker segments — preserving transcript without speaker labels")
            return segments.map { seg in
                TranscriptSegment(
                    id: seg.id,
                    text: seg.text,
                    startMs: seg.startMs,
                    endMs: seg.endMs,
                    speakerId: nil,
                    isFinal: seg.isFinal
                )
            }
        }

        // Build transcript intervals for mapping
        let intervals = segments.map { seg in
            DiarizationMapping.TranscriptInterval(
                id: seg.id,
                startTimeSeconds: Float(seg.startMs) / 1000.0,
                endTimeSeconds: Float(seg.endMs) / 1000.0
            )
        }

        // Map speakers onto transcript intervals
        let mappingResult = DiarizationMapping.mapSpeakers(
            intervals: intervals,
            speakerSegments: speakerSegments
        )

        // Build a lookup from interval ID to assigned speaker
        var speakerByIntervalId: [TranscriptSegmentID: String] = [:]
        for assignment in mappingResult.assignments {
            if let speakerId = assignment.speakerId {
                speakerByIntervalId[assignment.intervalId] = speakerId
            }
        }

        // Apply speaker IDs to segments
        let enrichedSegments = segments.map { seg in
            TranscriptSegment(
                id: seg.id,
                text: seg.text,
                startMs: seg.startMs,
                endMs: seg.endMs,
                speakerId: speakerByIntervalId[seg.id],
                isFinal: seg.isFinal
            )
        }

        let assignedCount = enrichedSegments.filter { $0.speakerId != nil }.count
        NSLog("\(logPrefix) Speaker enrichment complete: \(assignedCount)/\(enrichedSegments.count) segments assigned speakers")

        return enrichedSegments
    }

    /// Persist enriched transcript segments and build speaker tracks.
    ///
    /// - Parameters:
    ///   - segments: The enriched transcript segments to persist.
    ///   - sessionId: The session ID to associate segments with.
    ///   - logPrefix: Log prefix for consistent logging context.
    /// - Returns: The number of distinct speakers found.
    private func persistEnrichedSegments(
        _ segments: [TranscriptSegment],
        sessionId: SessionID,
        logPrefix: String
    ) async throws -> Int {
        var seenSpeakers: Set<String> = []
        let now = date.now

        for segment in segments {
            // Create speaker track if this is a new speaker
            if let speakerId = segment.speakerId, !seenSpeakers.contains(speakerId) {
                seenSpeakers.insert(speakerId)
                let displayOrder = seenSpeakers.count
                let trackId = uuid().uuidString

                let speakerTrack = SpeakerTrackRecord(
                    id: trackId,
                    sessionId: sessionId.rawValue,
                    machineSpeakerId: speakerId,
                    displayOrder: displayOrder
                )
                try await databaseClient.createSpeakerTrack(speakerTrack)
            }

            // Create transcript segment record
            let segmentRecord = TranscriptSegmentRecord(
                id: segment.id.rawValue,
                sessionId: sessionId.rawValue,
                startMs: Int(segment.startMs),
                endMs: Int(segment.endMs),
                machineSpeakerId: segment.speakerId,
                text: segment.text,
                isFinal: segment.isFinal,
                createdAt: now,
                updatedAt: now
            )
            try await databaseClient.createTranscriptSegment(segmentRecord)
        }

        NSLog("\(logPrefix) Persisted \(segments.count) segments, \(seenSpeakers.count) speakers")
        return seenSpeakers.count
    }

    /// Fork an audio stream into two independent streams
    private func forkAudioStream(_ source: AsyncStream<AudioFrame>) -> (AsyncStream<AudioFrame>, AsyncStream<AudioFrame>) {
        let (stream1, continuation1) = AsyncStream.makeStream(of: AudioFrame.self)
        let (stream2, continuation2) = AsyncStream.makeStream(of: AudioFrame.self)

        Task {
            for await frame in source {
                continuation1.yield(frame)
                continuation2.yield(frame)
            }
            continuation1.finish()
            continuation2.finish()
        }

        return (stream1, stream2)
    }

    // MARK: - Retry Offline Transcription

    /// Retry offline transcription for a failed/partial session.
    ///
    /// ## Retry Policy
    /// Retry is only possible when:
    ///   - The session is in `.failed` or `.partial` state.
    ///   - An audio file still exists on disk (pointed to by `session.audioPath`).
    ///
    /// Retry is NOT available for:
    ///   - **transcriptOnly** sessions where audio was already deleted after the initial
    ///     offline transcription attempt. These sessions have `audioPath == nil`.
    ///   - **audioOnly** sessions (offline transcription was never attempted).
    ///   - **continuation** sessions (no full-session audio file exists).
    ///
    /// The retry flow follows the same enrichment contract as `runOfflineTranscription`:
    ///   - On success: existing segments are replaced, speaker tracks are rebuilt,
    ///     session moves to `.processed`.
    ///   - On failure: session moves to `.partial` (if live segments exist) or `.failed`.
    ///   - Text is preserved if the retry fails (live segments are only deleted after
    ///     successful offline transcription).
    ///
    /// - Parameter sessionId: The session ID to retry transcription for
    /// - Returns: true if retry succeeded, false otherwise
    public func retryOfflineTranscription(sessionId: SessionID) async throws -> Bool {
        // Verify we're not currently recording
        guard !isRecording else {
            throw RecordingProcessorError.alreadyRecording
        }

        // Fetch session
        guard let session = try await databaseClient.fetchSession(sessionId) else {
            throw RecordingProcessorError.sessionNotFound
        }

        // Verify session is in a state that can be retried (failed or partial)
        guard session.processingState == .failed || session.processingState == .partial else {
            throw RecordingProcessorError.invalidStateForRetry(session.processingState)
        }

        // Verify audio file exists
        guard let audioPath = session.audioPath else {
            throw RecordingProcessorError.noAudioFile
        }

        let audioFileURL = URL(fileURLWithPath: audioPath)
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw RecordingProcessorError.audioFileNotFound
        }

        // Mark session as transcribing
        var updatedSession = session
        updatedSession.processingState = .transcribing
        updatedSession.processingError = nil
        updatedSession.updatedAt = date.now
        try await databaseClient.updateSession(updatedSession)

        NSLog("[RetryOfflineTranscription] Starting retry for session \(sessionId.rawValue)")

        do {
            // Run offline transcription on the saved audio file with timeout
            let segments = try await withThrowingTaskGroup(of: [TranscriptSegment].self) { group in
                group.addTask { [fluidAudioClient] in
                    try await fluidAudioClient.transcribeFile(audioFileURL)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(Self.offlineTranscriptionTimeout))
                    throw OfflineTranscriptionError.timeout
                }
                // Return result from whichever task finishes first
                guard let result = try await group.next() else {
                    throw OfflineTranscriptionError.timeout
                }
                group.cancelAll()
                return result
            }
            NSLog("[RetryOfflineTranscription] Got \(segments.count) segments from file")

            // If offline transcription returned no segments, mark as failed
            guard !segments.isEmpty else {
                NSLog("[RetryOfflineTranscription] No segments from offline transcription")
                var failedSession = session
                failedSession.processingState = .failed
                failedSession.processingError = "Offline transcription produced no segments"
                failedSession.updatedAt = date.now
                try await databaseClient.updateSession(failedSession)
                return false
            }

            // Post-stop speaker enrichment (same contract as runOfflineTranscription)
            let enrichedSegments = await enrichSegmentsWithDiarization(
                segments: segments,
                audioFileURL: audioFileURL,
                logPrefix: "[RetryOfflineTranscription]"
            )

            // Delete existing segments (old live or previous retry)
            try await databaseClient.deleteTranscriptSegmentsForSession(sessionId)
            NSLog("[RetryOfflineTranscription] Deleted existing transcript segments")

            // Delete existing speaker tracks and recreate them based on enriched results
            try await databaseClient.deleteSpeakerTracksForSession(sessionId)

            // Persist enriched segments and build speaker tracks
            let speakerCount = try await persistEnrichedSegments(
                enrichedSegments,
                sessionId: sessionId,
                logPrefix: "[RetryOfflineTranscription]"
            )

            // Update session to processed state
            if var finalSession = try await databaseClient.fetchSession(sessionId) {
                // Recompute preview text from enriched segments
                let previewText = enrichedSegments
                    .filter { $0.isFinal }
                    .prefix(3)
                    .map { $0.text }
                    .joined(separator: " ")

                finalSession.previewText = previewText.isEmpty ? nil : String(previewText.prefix(200))
                finalSession.speakerCount = speakerCount
                finalSession.processingState = .processed
                finalSession.processingError = nil
                finalSession.updatedAt = date.now
                try await databaseClient.updateSession(finalSession)
                NSLog("[RetryOfflineTranscription] Session marked as processed")
            }

            return true

        } catch {
            NSLog("[RetryOfflineTranscription] ERROR: \(String(describing: error))")
            // Mark session as failed again
            do {
                if var failedSession = try await databaseClient.fetchSession(sessionId) {
                    // Check if there are existing segments
                    let existingSegments = (try? await databaseClient.fetchTranscriptSegments(sessionId)) ?? []
                    let hasSegments = !existingSegments.isEmpty

                    failedSession.processingState = hasSegments ? .partial : .failed
                    failedSession.processingError = "Retry failed: \(error.localizedDescription)"
                    failedSession.updatedAt = date.now
                    try await databaseClient.updateSession(failedSession)
                }
            } catch {
                // Silent failure
            }
            return false
        }
    }
}

// MARK: - RecordingProcessorError

public enum RecordingProcessorError: Error, Equatable, Sendable {
    case alreadyRecording
    case notRecording
    case sessionNotFound
    case noAudioFile
    case audioFileNotFound
    case invalidStateForRetry(ProcessingState)
    case invalidStateForContinuation(ProcessingState)
}

// MARK: - OfflineTranscriptionError

/// Errors specific to offline transcription
public enum OfflineTranscriptionError: Error, LocalizedError, Sendable {
    case timeout

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Transcription timed out after 5 minutes"
        }
    }
}

// MARK: - RecoveryRoutine

/// Result of running the recovery routine at app startup
public struct RecoveryResult: Sendable, Equatable {
    public let staleSessionIds: [SessionID]
    public let reconciledCount: Int

    public init(staleSessionIds: [SessionID], reconciledCount: Int) {
        self.staleSessionIds = staleSessionIds
        self.reconciledCount = reconciledCount
    }

    public static let empty = RecoveryResult(staleSessionIds: [], reconciledCount: 0)
}

/// Client for recovering from interrupted recordings on app startup
@DependencyClient
public struct RecoveryRoutineClient: Sendable {
    /// Run the recovery routine to detect and reconcile stale recordings
    public var run: @Sendable () async throws -> RecoveryResult = { .empty }
}

extension RecoveryRoutineClient: DependencyKey {
    public static func live() -> Self {
        @Dependency(\.databaseClient) var databaseClient
        @Dependency(\.loggingClient) var loggingClient
        @Dependency(\.date) var date

        return Self(
            run: {
                // Start trace for recovery operation
                _ = await loggingClient.startTrace()

                await loggingClient.info(
                    "Starting recovery routine",
                    event: "recovery_start"
                )

                // Fetch stale recordings
                let staleRecordings = try await databaseClient.fetchStaleRecordings()

                if staleRecordings.isEmpty {
                    await loggingClient.info(
                        "No stale recordings found",
                        event: "recovery_stale_none"
                    )

                    // Still check for stuck transcriptions
                    // Use 6 minutes (360 seconds) as cutoff to account for 5-minute transcription timeout plus buffer
                    let cutoffDate = date.now.addingTimeInterval(-360)
                    let transcriptionRecovered = try await databaseClient.recoverStuckTranscriptions(cutoffDate)

                    if transcriptionRecovered > 0 {
                        await loggingClient.warning(
                            "Recovered \(transcriptionRecovered) stuck transcription(s)",
                            event: "recovery_transcription_complete",
                            metadata: ["recovered": "\(transcriptionRecovered)"]
                        )
                    }

                    await loggingClient.endTrace()
                    return RecoveryResult(staleSessionIds: [], reconciledCount: transcriptionRecovered)
                }

                let staleIds = staleRecordings.map { SessionID($0.id) }
                let sessionIdsStr = staleIds.map(\.rawValue).joined(separator: ", ")

                await loggingClient.warning(
                    "Found \(staleRecordings.count) stale recording(s): \(sessionIdsStr)",
                    event: "recovery_stale_found",
                    metadata: ["count": "\(staleRecordings.count)"]
                )

                // Reconcile stale recordings
                let now = date.now
                let reconciledCount = try await databaseClient.reconcileStaleRecordings(staleIds, now)

                await loggingClient.info(
                    "Reconciled \(reconciledCount) stale recording(s) to partial state",
                    event: "recovery_stale_complete",
                    metadata: ["reconciled": "\(reconciledCount)"]
                )

                // Also recover sessions stuck in transcribing state
                // Use 6 minutes (360 seconds) as cutoff to account for 5-minute transcription timeout plus buffer
                // NOTE: transcriptOnly sessions recovered here may still have audio files on disk
                // if the app was force-killed during offline transcription. Full cleanup requires
                // per-session retention mode tracking (future work). The finalization path uses
                // defer to handle non-crash interruptions.
                let cutoffDate = date.now.addingTimeInterval(-360)
                let transcriptionRecovered = try await databaseClient.recoverStuckTranscriptions(cutoffDate)

                if transcriptionRecovered > 0 {
                    await loggingClient.warning(
                        "Recovered \(transcriptionRecovered) stuck transcription(s)",
                        event: "recovery_transcription_complete",
                        metadata: ["recovered": "\(transcriptionRecovered)"]
                    )
                }

                await loggingClient.endTrace()

                return RecoveryResult(staleSessionIds: staleIds, reconciledCount: reconciledCount + transcriptionRecovered)
            }
        )
    }

    public static var liveValue: Self { live() }

    public static var previewValue: Self {
        Self(
            run: { .empty }
        )
    }

    public static var testValue: Self { Self() }
}

extension DependencyValues {
    public var recoveryRoutineClient: RecoveryRoutineClient {
        get { self[RecoveryRoutineClient.self] }
        set { self[RecoveryRoutineClient.self] = newValue }
    }
}
