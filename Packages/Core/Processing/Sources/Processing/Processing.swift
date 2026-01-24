import Foundation
import Models
import Audio
import Persistence
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
    case didFail(String)
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
    @Dependency(\.fluidAudioClient) var fluidAudioClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    private var currentSessionID: SessionID?
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    private var seenSpeakers: Set<String> = []
    private var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?

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

        return stream
    }

    /// Stop the current recording session
    public func stopRecording() async {
        guard isRecording else { return }

        isRecording = false
        isPaused = false

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

    // MARK: - Private Helpers

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
