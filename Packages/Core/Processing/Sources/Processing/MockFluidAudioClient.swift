import Foundation
import Models
import Audio
import Dependencies

// MARK: - Script Types

/// A scripted segment to be emitted by MockFluidAudioClient
public struct ScriptedSegment: Sendable, Equatable {
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

    /// Convert to TranscriptSegment
    public func toTranscriptSegment() -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            text: text,
            startMs: startMs,
            endMs: endMs,
            speakerId: speakerId,
            isFinal: isFinal
        )
    }
}

/// Configuration for MockFluidAudioClient scripted behavior
public struct MockFluidAudioScript: Sendable {
    /// The segments to emit in order
    public let segments: [ScriptedSegment]

    public init(segments: [ScriptedSegment]) {
        self.segments = segments
    }

    /// A default script with two speakers having a simple conversation
    public static let twoSpeakerConversation = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Hello, how are you today?",
                startMs: 0,
                endMs: 2000,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-002"),
                text: "I'm doing well, thank you for asking.",
                startMs: 2500,
                endMs: 5000,
                speakerId: "spk_1",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-003"),
                text: "That's great to hear!",
                startMs: 5500,
                endMs: 7000,
                speakerId: "spk_0",
                isFinal: true
            ),
        ]
    )

    /// An empty script (no segments)
    public static let empty = MockFluidAudioScript(segments: [])

    /// A script with partial and final segments to test live updates
    public static let withPartialSegments = MockFluidAudioScript(
        segments: [
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-partial-001"),
                text: "Hello",
                startMs: 0,
                endMs: 500,
                speakerId: "spk_0",
                isFinal: false
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-001"),
                text: "Hello, how are you?",
                startMs: 0,
                endMs: 1500,
                speakerId: "spk_0",
                isFinal: true
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-partial-002"),
                text: "I'm",
                startMs: 2000,
                endMs: 2200,
                speakerId: "spk_1",
                isFinal: false
            ),
            ScriptedSegment(
                id: TranscriptSegmentID(rawValue: "seg-002"),
                text: "I'm doing great!",
                startMs: 2000,
                endMs: 3500,
                speakerId: "spk_1",
                isFinal: true
            ),
        ]
    )
}

// MARK: - MockFluidAudioClient Actor

/// Configuration for offline (file) transcription behavior
public enum OfflineTranscriptionBehavior: Sendable {
    /// Return segments from the script
    case success
    /// Return empty array (no segments)
    case empty
    /// Throw an error
    case failure(String)
    /// Hang indefinitely (for timeout testing)
    case hang
}

/// Configuration for offline (file) diarization behavior
public enum DiarizationBehavior: Sendable {
    /// Return predefined speaker segments
    case success([DiarizationMapping.SpeakerSegment])
    /// Return empty array (no speakers detected)
    case empty
    /// Throw an error
    case failure(String)
    /// Hang indefinitely (for timeout testing)
    case hang
}

/// Default two-speaker diarization segments for testing
extension DiarizationBehavior {
    /// A default two-speaker diarization result matching twoSpeakerConversation script
    public static var twoSpeakerDefault: DiarizationBehavior {
        .success([
            DiarizationMapping.SpeakerSegment(
                speakerId: "spk_0",
                startTimeSeconds: 0.0,
                endTimeSeconds: 2.5
            ),
            DiarizationMapping.SpeakerSegment(
                speakerId: "spk_1",
                startTimeSeconds: 2.5,
                endTimeSeconds: 5.5
            ),
            DiarizationMapping.SpeakerSegment(
                speakerId: "spk_0",
                startTimeSeconds: 5.5,
                endTimeSeconds: 7.0
            ),
        ])
    }
}

/// Actor that manages mock transcription state
public actor MockFluidAudioClientActor {
    private var script: MockFluidAudioScript
    private var isTranscribing: Bool = false
    private var continuation: AsyncStream<TranscriptSegment>.Continuation?
    private var modelState: ModelPreparationState
    private var offlineBehavior: OfflineTranscriptionBehavior
    private var diarizationBehavior: DiarizationBehavior

    public init(
        script: MockFluidAudioScript = .twoSpeakerConversation,
        modelState: ModelPreparationState = .ready,
        offlineBehavior: OfflineTranscriptionBehavior = .success,
        diarizationBehavior: DiarizationBehavior = .twoSpeakerDefault
    ) {
        self.script = script
        self.modelState = modelState
        self.offlineBehavior = offlineBehavior
        self.diarizationBehavior = diarizationBehavior
    }

    /// Update the script to use for the next transcription
    public func setScript(_ script: MockFluidAudioScript) {
        self.script = script
    }

    /// Update the model state
    public func setModelState(_ state: ModelPreparationState) {
        self.modelState = state
    }

    /// Update the offline behavior
    public func setOfflineBehavior(_ behavior: OfflineTranscriptionBehavior) {
        self.offlineBehavior = behavior
    }

    /// Get the offline behavior
    public func getOfflineBehavior() -> OfflineTranscriptionBehavior {
        offlineBehavior
    }

    /// Update the diarization behavior
    public func setDiarizationBehavior(_ behavior: DiarizationBehavior) {
        self.diarizationBehavior = behavior
    }

    /// Get the diarization behavior
    public func getDiarizationBehavior() -> DiarizationBehavior {
        diarizationBehavior
    }

    /// Get the script segments
    public func getScriptSegments() -> [ScriptedSegment] {
        script.segments
    }

    /// Get current model status
    public func getModelStatus() -> ModelPreparationState {
        modelState
    }

    /// Prepare models (simulated - just transitions to ready unless configured to fail)
    public func prepareModels() {
        switch modelState {
        case .ready:
            // Already ready, no-op
            return
        case .downloading:
            // Already downloading, no-op
            return
        case .idle:
            // Transition directly to ready for mocks
            modelState = .ready
        case .failed:
            // Stay in failed state - requires explicit reset
            return
        }
    }

    /// Start transcription and return a stream of segments
    /// Live segments are emitted with speakerId=nil (diarization is deferred to post-stop processing)
    public func startTranscription(audioStream: AsyncStream<AudioFrame>) -> AsyncStream<TranscriptSegment> {
        isTranscribing = true
        let segments = self.script.segments

        return AsyncStream { continuation in
            self.continuation = continuation

            Task { [weak self] in
                // Emit all scripted segments immediately, but with nil speakerId
                // (matches production behavior: live segments have no speaker labels)
                for segment in segments {
                    guard let self else { break }
                    guard await self.getIsTranscribing() else { break }
                    let liveSegment = TranscriptSegment(
                        id: segment.id,
                        text: segment.text,
                        startMs: segment.startMs,
                        endMs: segment.endMs,
                        speakerId: nil,
                        isFinal: segment.isFinal
                    )
                    continuation.yield(liveSegment)
                }

                // Mark transcription as complete
                await self?.markComplete()
                continuation.finish()
            }
        }
    }

    /// Stop transcription
    public func stopTranscription() {
        isTranscribing = false
        continuation?.finish()
        continuation = nil
    }

    /// Check if currently transcribing
    public func getIsTranscribing() -> Bool {
        isTranscribing
    }

    private func markComplete() {
        isTranscribing = false
    }
}

// MARK: - MockFluidAudioClient Factory

/// Error type for mock offline transcription failures
public struct MockOfflineTranscriptionError: Error, LocalizedError {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

/// Creates a FluidAudioClient that emits scripted segments for testing
public struct MockFluidAudioClient {

    /// Create a FluidAudioClient with scripted segment output and configurable model state
    public static func client(
        script: MockFluidAudioScript = .twoSpeakerConversation,
        modelState: ModelPreparationState = .ready,
        offlineBehavior: OfflineTranscriptionBehavior = .success,
        diarizationBehavior: DiarizationBehavior = .twoSpeakerDefault
    ) -> FluidAudioClient {
        let actor = MockFluidAudioClientActor(
            script: script,
            modelState: modelState,
            offlineBehavior: offlineBehavior,
            diarizationBehavior: diarizationBehavior
        )

        return FluidAudioClient(
            prepareModels: {
                await actor.prepareModels()
            },
            modelStatus: {
                await actor.getModelStatus()
            },
            startTranscription: { audioStream in
                await actor.startTranscription(audioStream: audioStream)
            },
            stopTranscription: {
                await actor.stopTranscription()
            },
            isTranscribing: {
                await actor.getIsTranscribing()
            },
            transcribeFile: { _ in
                let behavior = await actor.getOfflineBehavior()
                switch behavior {
                case .success:
                    // Return script segments for offline transcription
                    let segments = await actor.getScriptSegments()
                    return segments.map { $0.toTranscriptSegment() }
                case .empty:
                    return []
                case .failure(let message):
                    throw MockOfflineTranscriptionError(message: message)
                case .hang:
                    // Hang indefinitely (for timeout testing)
                    // Sleep for a very long time (effectively forever)
                    try await Task.sleep(for: .seconds(3600))
                    return []
                }
            },
            diarizeFile: { _, _ in
                let behavior = await actor.getDiarizationBehavior()
                switch behavior {
                case .success(let segments):
                    return segments
                case .empty:
                    return []
                case .failure(let message):
                    throw MockOfflineTranscriptionError(message: message)
                case .hang:
                    try await Task.sleep(for: .seconds(3600))
                    return []
                }
            }
        )
    }

    /// Create a FluidAudioClient with the default two-speaker conversation script
    public static var twoSpeakerConversation: FluidAudioClient {
        client(script: .twoSpeakerConversation)
    }

    /// Create a FluidAudioClient with partial segments for testing live updates
    public static var withPartialSegments: FluidAudioClient {
        client(script: .withPartialSegments)
    }

    /// Create a FluidAudioClient with no segments (empty script)
    public static var empty: FluidAudioClient {
        client(script: .empty)
    }

    /// Create a FluidAudioClient configured with idle model state (not yet prepared)
    public static var idle: FluidAudioClient {
        client(script: .empty, modelState: .idle)
    }

    /// Create a FluidAudioClient configured with failed model state
    public static func failed(message: String) -> FluidAudioClient {
        client(script: .empty, modelState: .failed(message))
    }

    /// Create a FluidAudioClient where offline transcription fails with an error
    public static func offlineFailure(
        script: MockFluidAudioScript = .twoSpeakerConversation,
        errorMessage: String = "Mock offline transcription error"
    ) -> FluidAudioClient {
        client(script: script, modelState: .ready, offlineBehavior: .failure(errorMessage))
    }

    /// Create a FluidAudioClient where offline transcription returns empty (no segments)
    public static func offlineEmpty(
        script: MockFluidAudioScript = .twoSpeakerConversation
    ) -> FluidAudioClient {
        client(script: script, modelState: .ready, offlineBehavior: .empty)
    }

    /// Create a FluidAudioClient where offline transcription hangs indefinitely (for timeout testing)
    public static func offlineHang(
        script: MockFluidAudioScript = .twoSpeakerConversation
    ) -> FluidAudioClient {
        client(script: script, modelState: .ready, offlineBehavior: .hang)
    }

    /// Create a FluidAudioClient where ASR is not initialized.
    /// startTranscription will throw notInitialized, simulating production behavior
    /// when ASR models haven't been loaded.
    public static var asrNotInitialized: FluidAudioClient {
        FluidAudioClient(
            prepareModels: { },
            modelStatus: { .idle },
            startTranscription: { _ in
                throw LiveFluidAudioClientError.notInitialized
            },
            stopTranscription: { },
            isTranscribing: { false },
            transcribeFile: { _ in
                throw LiveFluidAudioClientError.notInitialized
            },
            diarizeFile: { _, _ in
                throw LiveFluidAudioClientError.notInitialized
            }
        )
    }

    /// Create a FluidAudioClient where ASR is ready (live transcription works)
    /// but diarizer is not available (offline transcription with diarization will fail).
    /// This simulates the decoupled model lifecycle where live path works independently.
    public static func asrReadyDiarizerUnavailable(
        script: MockFluidAudioScript = .twoSpeakerConversation
    ) -> FluidAudioClient {
        let actor = MockFluidAudioClientActor(
            script: script,
            modelState: .ready,
            offlineBehavior: .failure("Diarization models unavailable"),
            diarizationBehavior: .failure("Diarization models unavailable")
        )
        return FluidAudioClient(
            prepareModels: {
                await actor.prepareModels()
            },
            modelStatus: {
                await actor.getModelStatus()
            },
            startTranscription: { audioStream in
                // ASR is ready, so live transcription works
                await actor.startTranscription(audioStream: audioStream)
            },
            stopTranscription: {
                await actor.stopTranscription()
            },
            isTranscribing: {
                await actor.getIsTranscribing()
            },
            transcribeFile: { _ in
                // Diarizer is not available, so offline transcription fails
                throw LiveFluidAudioClientError.diarizationUnavailable
            },
            diarizeFile: { _, _ in
                throw LiveFluidAudioClientError.diarizationUnavailable
            }
        )
    }

    /// Create a FluidAudioClient where diarization fails with an error
    public static func diarizationFailure(
        script: MockFluidAudioScript = .twoSpeakerConversation,
        errorMessage: String = "Mock diarization error"
    ) -> FluidAudioClient {
        client(script: script, modelState: .ready, diarizationBehavior: .failure(errorMessage))
    }

    /// Create a FluidAudioClient where diarization returns empty (no speakers)
    public static func diarizationEmpty(
        script: MockFluidAudioScript = .twoSpeakerConversation
    ) -> FluidAudioClient {
        client(script: script, modelState: .ready, diarizationBehavior: .empty)
    }

    /// Create a FluidAudioClient where diarization hangs indefinitely (for timeout testing)
    public static func diarizationHang(
        script: MockFluidAudioScript = .twoSpeakerConversation
    ) -> FluidAudioClient {
        client(script: script, modelState: .ready, diarizationBehavior: .hang)
    }
}
