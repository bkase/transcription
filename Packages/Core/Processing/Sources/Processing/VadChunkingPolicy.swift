import Foundation

// MARK: - VadChunkingPolicy

/// Policy for determining chunk boundaries based on Voice Activity Detection (VAD) events.
/// This enables near-real-time transcript segments by processing utterances as they complete,
/// rather than using fixed time intervals.
///
/// VAD-based chunking produces more natural segment boundaries aligned with actual speech patterns.
public struct VadChunkingPolicy: Sendable {

    // MARK: - Configuration

    /// Configuration for VAD-based chunking behavior
    public struct Config: Sendable, Equatable {
        /// Minimum speech duration (in milliseconds) to form a valid chunk
        public let minSpeechDurationMs: UInt64

        /// Maximum speech duration (in milliseconds) before forcing a chunk boundary
        /// This prevents unbounded accumulation for very long utterances
        public let maxSpeechDurationMs: UInt64

        /// Minimum silence duration (in milliseconds) to close a speech segment
        public let minSilenceDurationMs: UInt64

        /// Padding added to segment boundaries (in milliseconds)
        public let speechPaddingMs: UInt64

        /// Default configuration tuned for conversational speech
        public static let `default` = Config(
            minSpeechDurationMs: 250,     // 250ms minimum to filter noise
            maxSpeechDurationMs: 14_000,  // 14s max (FluidAudio VAD default)
            minSilenceDurationMs: 400,    // 400ms silence closes segment
            speechPaddingMs: 120          // 120ms context padding
        )

        /// Configuration for "meeting mode" - longer tolerance for pauses
        public static let meeting = Config(
            minSpeechDurationMs: 300,
            maxSpeechDurationMs: 20_000,  // Allow longer monologues
            minSilenceDurationMs: 800,    // 800ms silence (speaker pauses)
            speechPaddingMs: 150
        )

        /// Configuration for quick/mobile use - faster feedback
        public static let quick = Config(
            minSpeechDurationMs: 200,
            maxSpeechDurationMs: 10_000,
            minSilenceDurationMs: 300,
            speechPaddingMs: 100
        )

        public init(
            minSpeechDurationMs: UInt64,
            maxSpeechDurationMs: UInt64,
            minSilenceDurationMs: UInt64,
            speechPaddingMs: UInt64
        ) {
            self.minSpeechDurationMs = minSpeechDurationMs
            self.maxSpeechDurationMs = maxSpeechDurationMs
            self.minSilenceDurationMs = minSilenceDurationMs
            self.speechPaddingMs = speechPaddingMs
        }
    }

    // MARK: - VAD Events

    /// A VAD event indicating speech state change
    public enum VadEvent: Sendable, Equatable {
        case speechStart(timeMs: UInt64)
        case speechEnd(timeMs: UInt64)
    }

    // MARK: - Chunk Boundary

    /// A chunk boundary indicating when to process accumulated audio for ASR
    public struct ChunkBoundary: Sendable, Equatable {
        /// Start time of the speech chunk (in milliseconds)
        public let startMs: UInt64

        /// End time of the speech chunk (in milliseconds)
        public let endMs: UInt64

        /// Whether this boundary was forced due to max duration limit
        public let wasForced: Bool

        public init(startMs: UInt64, endMs: UInt64, wasForced: Bool = false) {
            self.startMs = startMs
            self.endMs = endMs
            self.wasForced = wasForced
        }

        /// Duration of the chunk in milliseconds
        public var durationMs: UInt64 {
            endMs > startMs ? endMs - startMs : 0
        }
    }

    // MARK: - State

    /// Mutable state for tracking VAD-based chunking
    public struct State: Sendable, Equatable {
        /// Whether speech is currently detected
        public var isSpeaking: Bool

        /// Start time of current speech segment (nil if not speaking)
        public var currentSpeechStartMs: UInt64?

        /// Last emitted chunk end time for continuity
        public var lastChunkEndMs: UInt64

        /// Number of chunks emitted
        public var chunkCount: Int

        public init() {
            self.isSpeaking = false
            self.currentSpeechStartMs = nil
            self.lastChunkEndMs = 0
            self.chunkCount = 0
        }
    }

    // MARK: - Public API

    /// Process a VAD event and determine if a chunk boundary should be emitted.
    /// - Parameters:
    ///   - event: The VAD event (speechStart or speechEnd)
    ///   - state: The current chunking state (mutated in place)
    ///   - config: The chunking configuration
    /// - Returns: A chunk boundary if one should be emitted, nil otherwise
    public static func processEvent(
        _ event: VadEvent,
        state: inout State,
        config: Config = .default
    ) -> ChunkBoundary? {
        switch event {
        case .speechStart(let timeMs):
            return handleSpeechStart(timeMs: timeMs, state: &state, config: config)

        case .speechEnd(let timeMs):
            return handleSpeechEnd(timeMs: timeMs, state: &state, config: config)
        }
    }

    /// Check if current speech segment should be forcibly closed due to max duration.
    /// Call this periodically during long speech segments.
    /// - Parameters:
    ///   - currentTimeMs: Current audio time in milliseconds
    ///   - state: The current chunking state (mutated in place)
    ///   - config: The chunking configuration
    /// - Returns: A forced chunk boundary if max duration exceeded, nil otherwise
    public static func checkMaxDuration(
        currentTimeMs: UInt64,
        state: inout State,
        config: Config = .default
    ) -> ChunkBoundary? {
        guard state.isSpeaking,
              let startMs = state.currentSpeechStartMs else {
            return nil
        }

        let elapsed = currentTimeMs > startMs ? currentTimeMs - startMs : 0

        if elapsed >= config.maxSpeechDurationMs {
            // Force a chunk boundary
            let boundary = ChunkBoundary(
                startMs: startMs,
                endMs: currentTimeMs,
                wasForced: true
            )

            // Reset for next segment (still speaking, new start)
            state.currentSpeechStartMs = currentTimeMs
            state.lastChunkEndMs = currentTimeMs
            state.chunkCount += 1

            return boundary
        }

        return nil
    }

    /// Flush any remaining speech when recording stops.
    /// - Parameters:
    ///   - endTimeMs: The final audio time in milliseconds
    ///   - state: The current chunking state (mutated in place)
    ///   - config: The chunking configuration
    /// - Returns: A final chunk boundary if there's pending speech, nil otherwise
    public static func flush(
        endTimeMs: UInt64,
        state: inout State,
        config: Config = .default
    ) -> ChunkBoundary? {
        guard let startMs = state.currentSpeechStartMs else {
            return nil
        }

        let duration = endTimeMs > startMs ? endTimeMs - startMs : 0

        // Only emit if meets minimum duration
        guard duration >= config.minSpeechDurationMs else {
            state.isSpeaking = false
            state.currentSpeechStartMs = nil
            return nil
        }

        let boundary = ChunkBoundary(
            startMs: startMs,
            endMs: endTimeMs,
            wasForced: false
        )

        state.isSpeaking = false
        state.currentSpeechStartMs = nil
        state.lastChunkEndMs = endTimeMs
        state.chunkCount += 1

        return boundary
    }

    // MARK: - Private Helpers

    private static func handleSpeechStart(
        timeMs: UInt64,
        state: inout State,
        config: Config
    ) -> ChunkBoundary? {
        guard !state.isSpeaking else {
            // Already speaking, ignore duplicate start
            return nil
        }

        state.isSpeaking = true
        // Apply padding: start slightly earlier if possible
        let paddedStart = timeMs >= config.speechPaddingMs
            ? timeMs - config.speechPaddingMs
            : 0
        state.currentSpeechStartMs = max(paddedStart, state.lastChunkEndMs)

        return nil
    }

    private static func handleSpeechEnd(
        timeMs: UInt64,
        state: inout State,
        config: Config
    ) -> ChunkBoundary? {
        guard state.isSpeaking,
              let startMs = state.currentSpeechStartMs else {
            // Not speaking, ignore spurious end
            return nil
        }

        // Apply padding: extend end time slightly
        let paddedEnd = timeMs + config.speechPaddingMs

        let duration = paddedEnd > startMs ? paddedEnd - startMs : 0

        state.isSpeaking = false
        state.currentSpeechStartMs = nil

        // Only emit chunk if meets minimum duration
        guard duration >= config.minSpeechDurationMs else {
            return nil
        }

        let boundary = ChunkBoundary(
            startMs: startMs,
            endMs: paddedEnd,
            wasForced: false
        )

        state.lastChunkEndMs = paddedEnd
        state.chunkCount += 1

        return boundary
    }
}

// MARK: - Sample Range Utilities

extension VadChunkingPolicy.ChunkBoundary {
    /// Convert time boundaries to sample indices at a given sample rate
    /// - Parameter sampleRate: Audio sample rate (e.g., 16000 for ML transcription)
    /// - Returns: Tuple of (startSample, endSample) indices
    public func sampleRange(atSampleRate sampleRate: Int) -> (start: Int, end: Int) {
        let startSample = Int((startMs * UInt64(sampleRate)) / 1000)
        let endSample = Int((endMs * UInt64(sampleRate)) / 1000)
        return (startSample, endSample)
    }
}
