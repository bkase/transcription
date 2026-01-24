import Foundation
import Models
import Audio
import FluidAudio
import Dependencies

// MARK: - LiveFluidAudioClientActor

/// Actor that wraps the FluidAudio SDK for production transcription and diarization
public actor LiveFluidAudioClientActor {
    @Dependency(\.uuid) var uuid

    private var asrManager: AsrManager?
    private var diarizerManager: DiarizerManager?
    private var isTranscribing: Bool = false
    private var continuation: AsyncStream<TranscriptSegment>.Continuation?

    // Audio accumulation state
    private var accumulatedSamples: [Float] = []
    private var lastProcessedEndMs: UInt64 = 0

    // Configuration
    private let sampleRate: Int = 16000
    private let chunkDurationMs: UInt64 = 5000 // Process every 5 seconds of audio
    private let samplesPerChunk: Int

    public init() {
        samplesPerChunk = sampleRate * Int(chunkDurationMs) / 1000
    }

    /// Initialize the ML models (downloads if needed, then loads)
    public func initialize() async throws {
        // Initialize ASR
        let asrModels = try await AsrModels.downloadAndLoad(version: .v3)
        let asrConfig = ASRConfig.default
        asrManager = AsrManager(config: asrConfig)
        try await asrManager?.initialize(models: asrModels)

        // Initialize Diarizer
        let diarizerModels = try await DiarizerModels.downloadIfNeeded()
        let diarizerConfig = DiarizerConfig.default
        diarizerManager = DiarizerManager(config: diarizerConfig)
        diarizerManager?.initialize(models: diarizerModels)
    }

    /// Check if ML models are initialized and ready
    public func isInitialized() -> Bool {
        asrManager != nil && diarizerManager?.isAvailable == true
    }

    /// Ensure models are initialized (lazy initialization)
    public func ensureInitialized() async throws {
        guard !isInitialized() else { return }
        try await initialize()
    }

    /// Start transcription on an audio stream
    public func startTranscription(audioStream: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptSegment> {
        guard let asrManager = asrManager else {
            throw LiveFluidAudioClientError.notInitialized
        }

        isTranscribing = true
        accumulatedSamples = []
        lastProcessedEndMs = 0

        return AsyncStream { continuation in
            self.continuation = continuation

            Task { [weak self] in
                guard let self = self else { return }

                for await frame in audioStream {
                    guard await self.getIsTranscribing() else { break }
                    await self.processFrame(frame)
                }

                // Process remaining audio when stream ends
                await self.processRemainingAudio()
                await self.finishTranscription()
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

    /// Cleanup resources
    public func cleanup() {
        asrManager?.cleanup()
        asrManager = nil
        diarizerManager = nil
    }

    // MARK: - Private Helpers

    private func processFrame(_ frame: AudioFrame) async {
        // Convert frame data to Float samples (assuming 16-bit PCM)
        let samples = frame.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            guard let baseAddress = ptr.baseAddress else { return [] }
            let int16Ptr = baseAddress.assumingMemoryBound(to: Int16.self)
            let count = frame.data.count / MemoryLayout<Int16>.size
            return (0..<count).map { Float(int16Ptr[$0]) / Float(Int16.max) }
        }

        accumulatedSamples.append(contentsOf: samples)

        // Process chunks when we have enough audio
        while accumulatedSamples.count >= samplesPerChunk {
            await processChunk()
        }
    }

    private func processChunk() async {
        guard accumulatedSamples.count >= samplesPerChunk else { return }
        guard let asrManager = asrManager, let diarizerManager = diarizerManager else { return }

        // Extract chunk
        let chunkSamples = Array(accumulatedSamples.prefix(samplesPerChunk))
        accumulatedSamples.removeFirst(samplesPerChunk)

        let chunkStartMs = lastProcessedEndMs
        let chunkEndMs = chunkStartMs + chunkDurationMs
        lastProcessedEndMs = chunkEndMs

        do {
            // Run ASR for transcription
            let asrResult = try await asrManager.transcribe(chunkSamples, source: .microphone)
            let transcriptText = asrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !transcriptText.isEmpty else { return }

            // Run diarization
            let startTimeSeconds = TimeInterval(chunkStartMs) / 1000.0
            let diarizationResult = try diarizerManager.performCompleteDiarization(
                chunkSamples,
                sampleRate: sampleRate,
                atTime: startTimeSeconds
            )

            // Find the dominant speaker for this chunk
            let speakerId = findDominantSpeaker(in: diarizationResult)

            // Emit segment
            let segment = TranscriptSegment(
                id: TranscriptSegmentID(rawValue: uuid().uuidString),
                text: transcriptText,
                startMs: chunkStartMs,
                endMs: chunkEndMs,
                speakerId: speakerId,
                isFinal: true
            )

            continuation?.yield(segment)
        } catch {
            // Log error but continue processing
            print("FluidAudio processing error: \(error)")
        }
    }

    private func processRemainingAudio() async {
        guard !accumulatedSamples.isEmpty else { return }
        guard let asrManager = asrManager, let diarizerManager = diarizerManager else { return }

        let remainingSamples = accumulatedSamples
        accumulatedSamples = []

        let chunkStartMs = lastProcessedEndMs
        let durationMs = UInt64(remainingSamples.count * 1000 / sampleRate)
        let chunkEndMs = chunkStartMs + durationMs

        do {
            let asrResult = try await asrManager.transcribe(remainingSamples, source: .microphone)
            let transcriptText = asrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !transcriptText.isEmpty else { return }

            let startTimeSeconds = TimeInterval(chunkStartMs) / 1000.0
            let diarizationResult = try diarizerManager.performCompleteDiarization(
                remainingSamples,
                sampleRate: sampleRate,
                atTime: startTimeSeconds
            )

            let speakerId = findDominantSpeaker(in: diarizationResult)

            let segment = TranscriptSegment(
                id: TranscriptSegmentID(rawValue: uuid().uuidString),
                text: transcriptText,
                startMs: chunkStartMs,
                endMs: chunkEndMs,
                speakerId: speakerId,
                isFinal: true
            )

            continuation?.yield(segment)
        } catch {
            print("FluidAudio processing error: \(error)")
        }
    }

    private func finishTranscription() {
        isTranscribing = false
        continuation?.finish()
        continuation = nil
    }

    private func findDominantSpeaker(in result: DiarizationResult) -> String? {
        // Convert FluidAudio segments to our testable struct
        let segments = result.segments.map { segment in
            DiarizationMapping.SpeakerSegment(
                speakerId: segment.speakerId,
                startTimeSeconds: segment.startTimeSeconds,
                endTimeSeconds: segment.endTimeSeconds
            )
        }
        return DiarizationMapping.findDominantSpeaker(in: segments)
    }
}

// MARK: - LiveFluidAudioClient Factory

/// Creates a FluidAudioClient that uses the FluidAudio SDK for production
public struct LiveFluidAudioClient {

    /// Create a FluidAudioClient with the live FluidAudio SDK implementation.
    /// Note: The client initializes models lazily on first use.
    public static func client() -> FluidAudioClient {
        let actor = LiveFluidAudioClientActor()

        return FluidAudioClient(
            startTranscription: { audioStream in
                // Initialize on first use (lazy initialization inside actor)
                try await actor.ensureInitialized()
                return try await actor.startTranscription(audioStream: audioStream)
            },
            stopTranscription: {
                await actor.stopTranscription()
            },
            isTranscribing: {
                await actor.getIsTranscribing()
            }
        )
    }
}

// MARK: - LiveFluidAudioClientError

public enum LiveFluidAudioClientError: Error, Sendable {
    case notInitialized
    case modelDownloadFailed
    case transcriptionFailed(String)
}
