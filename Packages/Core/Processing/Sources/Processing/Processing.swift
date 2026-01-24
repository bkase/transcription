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
    public static let liveValue: Self = {
        // Live implementation will use FluidAudio SDK - placeholder for now
        Self(
            startTranscription: { _ in AsyncStream { _ in } },
            stopTranscription: { },
            isTranscribing: { false }
        )
    }()

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
    case didFinish(SessionID)
    case didFail(String)
}

// MARK: - RecordingProcessorClient

/// Client for orchestrating recording sessions
@DependencyClient
public struct RecordingProcessorClient: Sendable {
    /// Start a new recording session
    public var startRecording: @Sendable () async throws -> AsyncStream<RecordingProcessorEvent>
    /// Stop the current recording session
    public var stopRecording: @Sendable () async -> Void
    /// Check if currently recording
    public var isRecording: @Sendable () async -> Bool = { false }
    /// Get the current session ID if recording
    public var currentSessionID: @Sendable () async -> SessionID? = { nil }
}

extension RecordingProcessorClient: DependencyKey {
    public static let liveValue: Self = {
        // Live implementation will orchestrate audio capture and ML - placeholder for now
        Self(
            startRecording: { AsyncStream { _ in } },
            stopRecording: { },
            isRecording: { false },
            currentSessionID: { nil }
        )
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var recordingProcessorClient: RecordingProcessorClient {
        get { self[RecordingProcessorClient.self] }
        set { self[RecordingProcessorClient.self] = newValue }
    }
}
