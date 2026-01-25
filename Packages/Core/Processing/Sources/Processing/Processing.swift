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

// MARK: - FluidAudioClient

/// Client for ML transcription and diarization (wraps FluidAudio SDK)
@DependencyClient
public struct FluidAudioClient: Sendable {
    /// Start transcription on audio frames, returns a stream of transcript segments
    public var startTranscription: @Sendable (_ audioStream: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptSegment>
    /// Stop transcription
    public var stopTranscription: @Sendable () async -> Void
    /// Check if currently transcribing
    public var isTranscribing: @Sendable () async -> Bool = { false }
}

extension FluidAudioClient: DependencyKey {
    public static let liveValue: Self = LiveFluidAudioClient.client()

    public static let testValue = Self()
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

/// Client for orchestrating recording sessions
@DependencyClient
public struct RecordingProcessorClient: Sendable {
    /// Start a new recording session
    /// - Parameter audioDirectory: Directory where audio files should be saved
    /// - Returns: Stream of recording processor events
    public var startRecording: @Sendable (_ audioDirectory: URL) async throws -> AsyncStream<RecordingProcessorEvent>
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
            }
        )
    }

    public static let liveValue: Self = live()

    public static let testValue = Self()
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
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    private var currentSessionID: SessionID?
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    private var isInterrupted: Bool = false
    private var seenSpeakers: Set<String> = []
    private var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
    private var audioSessionTask: Task<Void, Never>?

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

        // Start audio file writing
        let audioPath = audioDirectory.appendingPathComponent("\(sessionId.rawValue).caf")
        try await audioFileWriterClient.startWriting(audioPath, .recording)

        // Start audio capture
        let audioStream = try await audioCaptureClient.startCapture()

        // Emit listening changed
        continuation.yield(.listeningChanged(true))

        // Fork audio stream for file writing and ML
        let (writerStream, mlStream) = forkAudioStream(audioStream)

        // Start ML transcription
        let segmentStream = try await fluidAudioClient.startTranscription(mlStream)

        // Process audio frames for file writing in background
        Task { [weak self] in
            for await frame in writerStream {
                guard let self = self, await self.getIsRecording() else { break }
                try? await self.audioFileWriterClient.appendFrame(frame)
            }
        }

        // Process transcript segments in background
        Task { [weak self] in
            for await segment in segmentStream {
                guard let self = self else { break }
                guard await self.getIsRecording() else { break }
                await self.handleSegment(segment, sessionId: sessionId)
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
            await finalizeSession(sessionId)
        }

        currentSessionID = nil
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

        do {
            try await databaseClient.createTranscriptSegment(segmentRecord)
            eventContinuation?.yield(.didAppendSegment(segment.id))
        } catch {
            // Segment may already exist (partial update), try updating
            try? await databaseClient.updateTranscriptSegment(segmentRecord)
            eventContinuation?.yield(.didAppendSegment(segment.id))
        }
    }

    private func finalizeSession(_ sessionId: SessionID) async {
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

        // Compute duration from last segment end time
        let durationMs = segments.map { $0.endMs }.max() ?? 0

        // Update session
        session.endedAt = now
        session.previewText = previewText.isEmpty ? nil : String(previewText.prefix(200))
        session.durationMs = durationMs
        session.processingState = .processed
        session.speakerCount = seenSpeakers.count
        session.updatedAt = now

        do {
            try await databaseClient.updateSession(session)
            eventContinuation?.yield(.didFinish(sessionId))
        } catch {
            eventContinuation?.yield(.didFail("Failed to finalize session: \(error)"))
        }
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
}

// MARK: - RecordingProcessorError

public enum RecordingProcessorError: Error, Equatable, Sendable {
    case alreadyRecording
    case notRecording
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
                let traceId = await loggingClient.startTrace()

                await loggingClient.info(
                    "Starting recovery routine",
                    event: "recovery_start"
                )

                // Fetch stale recordings
                let staleRecordings = try await databaseClient.fetchStaleRecordings()

                if staleRecordings.isEmpty {
                    await loggingClient.info(
                        "No stale recordings found",
                        event: "recovery_complete"
                    )
                    await loggingClient.endTrace()
                    return .empty
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
                    event: "recovery_complete",
                    metadata: ["reconciled": "\(reconciledCount)"]
                )

                await loggingClient.endTrace()

                return RecoveryResult(staleSessionIds: staleIds, reconciledCount: reconciledCount)
            }
        )
    }

    public static let liveValue = live()
    public static let testValue = Self()
}

extension DependencyValues {
    public var recoveryRoutineClient: RecoveryRoutineClient {
        get { self[RecoveryRoutineClient.self] }
        set { self[RecoveryRoutineClient.self] = newValue }
    }
}
