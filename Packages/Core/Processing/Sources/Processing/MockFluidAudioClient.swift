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

/// Actor that manages mock transcription state
public actor MockFluidAudioClientActor {
    private var script: MockFluidAudioScript
    private var isTranscribing: Bool = false
    private var continuation: AsyncStream<TranscriptSegment>.Continuation?
    private var modelState: ModelPreparationState

    public init(
        script: MockFluidAudioScript = .twoSpeakerConversation,
        modelState: ModelPreparationState = .ready
    ) {
        self.script = script
        self.modelState = modelState
    }

    /// Update the script to use for the next transcription
    public func setScript(_ script: MockFluidAudioScript) {
        self.script = script
    }

    /// Update the model state
    public func setModelState(_ state: ModelPreparationState) {
        self.modelState = state
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
    public func startTranscription(audioStream: AsyncStream<AudioFrame>) -> AsyncStream<TranscriptSegment> {
        isTranscribing = true
        let segments = self.script.segments

        return AsyncStream { continuation in
            self.continuation = continuation

            Task { [weak self] in
                // Emit all scripted segments immediately
                for segment in segments {
                    guard let self else { break }
                    guard await self.getIsTranscribing() else { break }
                    continuation.yield(segment.toTranscriptSegment())
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

/// Creates a FluidAudioClient that emits scripted segments for testing
public struct MockFluidAudioClient {

    /// Create a FluidAudioClient with scripted segment output and configurable model state
    public static func client(
        script: MockFluidAudioScript = .twoSpeakerConversation,
        modelState: ModelPreparationState = .ready
    ) -> FluidAudioClient {
        let actor = MockFluidAudioClientActor(script: script, modelState: modelState)

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
}
