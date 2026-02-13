import Foundation
import Models
import Audio
import FluidAudio
import Dependencies
import AVFoundation

// MARK: - LiveFluidAudioClientActor

/// Actor that wraps the FluidAudio SDK for production transcription and diarization
public actor LiveFluidAudioClientActor {
    @Dependency(\.uuid) var uuid

    private var asrManager: AsrManager?
    private var diarizerManager: DiarizerManager?
    private var isTranscribing: Bool = false
    private var continuation: AsyncStream<TranscriptSegment>.Continuation?

    // Model preparation state
    private var modelState: ModelPreparationState = .idle

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

    /// Get the current model preparation state
    public func getModelStatus() -> ModelPreparationState {
        modelState
    }

    /// Prepare ASR models for live transcription (download and load). Idempotent - no-op if already ready.
    /// Diarization models are initialized lazily when needed for offline/post-stop processing.
    public func prepareModels() async {
        NSLog("[FluidAudio] prepareModels called, current state: \(modelState)")
        // Idempotent: if already ready or downloading, no-op
        switch modelState {
        case .ready:
            NSLog("[FluidAudio] ASR models already ready, returning")
            return
        case .downloading:
            NSLog("[FluidAudio] ASR models already downloading, returning")
            return
        case .idle, .failed:
            break
        }

        modelState = .downloading
        NSLog("[FluidAudio] Starting ASR model download...")

        do {
            // Initialize ASR only - diarizer is deferred to post-stop usage
            NSLog("[FluidAudio] Downloading ASR models...")
            let asrModels = try await AsrModels.downloadAndLoad(version: .v3)
            NSLog("[FluidAudio] ASR models downloaded, initializing...")
            let asrConfig = ASRConfig.default
            asrManager = AsrManager(config: asrConfig)
            try await asrManager?.initialize(models: asrModels)
            NSLog("[FluidAudio] ASR initialized")

            modelState = .ready
            NSLog("[FluidAudio] ASR models ready for live transcription!")
        } catch {
            NSLog("[FluidAudio] ASR model preparation failed: \(error)")
            modelState = .failed(error.localizedDescription)
        }
    }

    /// Initialize ASR models (downloads if needed, then loads).
    /// Diarization models are initialized lazily via ensureDiarizerInitialized().
    /// @deprecated Use prepareModels() instead for async model preparation
    public func initializeASR() async throws {
        // Initialize ASR only
        let asrModels = try await AsrModels.downloadAndLoad(version: .v3)
        let asrConfig = ASRConfig.default
        asrManager = AsrManager(config: asrConfig)
        try await asrManager?.initialize(models: asrModels)

        modelState = .ready
    }

    /// Check if ASR models are initialized and ready for live transcription.
    /// Diarizer availability is NOT required for live transcription.
    public func isASRInitialized() -> Bool {
        asrManager != nil
    }

    /// Ensure ASR models are initialized (lazy initialization for live path)
    public func ensureASRInitialized() async throws {
        guard !isASRInitialized() else { return }
        try await initializeASR()
    }

    /// Initialize diarizer models lazily for offline/post-stop processing.
    /// This is separate from ASR so live transcription can start without waiting for diarizer.
    public func ensureDiarizerInitialized() async throws {
        guard diarizerManager == nil else { return }
        NSLog("[FluidAudio] Lazily initializing diarizer models...")
        let diarizerModels = try await DiarizerModels.downloadIfNeeded()
        let diarizerConfig = DiarizerConfig.default
        diarizerManager = DiarizerManager(config: diarizerConfig)
        diarizerManager?.initialize(models: diarizerModels)
        NSLog("[FluidAudio] Diarizer initialized (lazy)")
    }

    /// Start transcription on an audio stream
    public func startTranscription(audioStream: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptSegment> {
        NSLog("[FluidAudio] startTranscription called")
        guard asrManager != nil else {
            NSLog("[FluidAudio] ERROR: ASR not initialized!")
            throw LiveFluidAudioClientError.notInitialized
        }
        NSLog("[FluidAudio] ASR manager available, starting transcription...")

        isTranscribing = true
        accumulatedSamples = []
        lastProcessedEndMs = 0

        return AsyncStream { continuation in
            self.continuation = continuation
            NSLog("[FluidAudio] Created transcript stream continuation")

            Task { [weak self] in
                guard let self = self else { return }
                var frameCount = 0

                for await frame in audioStream {
                    guard await self.getIsTranscribing() else {
                        NSLog("[FluidAudio] Transcription stopped, breaking loop")
                        break
                    }
                    frameCount += 1
                    if frameCount <= 5 || frameCount % 100 == 0 {
                        NSLog("[FluidAudio] Processing frame \(frameCount), size: \(frame.data.count) bytes")
                    }
                    await self.processFrame(frame)
                }

                NSLog("[FluidAudio] Audio stream ended after \(frameCount) frames")
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

    /// Transcribe an entire audio file (offline processing)
    /// - Parameter audioFileURL: URL to the CAF audio file (48kHz Float32)
    /// - Returns: Array of transcript segments
    public func transcribeFile(audioFileURL: URL) async throws -> [TranscriptSegment] {
        NSLog("[FluidAudio] transcribeFile called for: \(audioFileURL.lastPathComponent)")
        NSLog("[FluidAudio] transcribeFile: full path: \(audioFileURL.path)")
        NSLog("[FluidAudio] transcribeFile: checking ASR... asrManager=\(asrManager != nil)")
        NSLog("[FluidAudio] transcribeFile: modelState=\(modelState)")

        guard let asrManager = asrManager else {
            NSLog("[FluidAudio] ERROR: ASR not initialized for offline transcription")
            throw LiveFluidAudioClientError.notInitialized
        }

        // Lazily initialize diarizer for offline processing
        try await ensureDiarizerInitialized()

        guard let diarizerManager = diarizerManager, diarizerManager.isAvailable else {
            NSLog("[FluidAudio] ERROR: Diarizer manager not available after lazy init")
            throw LiveFluidAudioClientError.diarizationUnavailable
        }
        NSLog("[FluidAudio] transcribeFile: managers OK, opening file...")

        // Read the audio file
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioFileURL)
            NSLog("[FluidAudio] transcribeFile: file opened successfully")
        } catch {
            NSLog("[FluidAudio] ERROR: Failed to open audio file: \(error)")
            throw LiveFluidAudioClientError.transcriptionFailed("Failed to open audio file: \(error.localizedDescription)")
        }

        let fileFormat = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        NSLog("[FluidAudio] Audio file: \(frameCount) frames, \(fileFormat.sampleRate) Hz, \(fileFormat.channelCount) channels, format: \(fileFormat)")

        NSLog("[FluidAudio] transcribeFile: creating buffer with capacity \(frameCount)...")
        guard let buffer = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: frameCount) else {
            NSLog("[FluidAudio] ERROR: Failed to create buffer")
            throw LiveFluidAudioClientError.transcriptionFailed("Failed to create audio buffer")
        }
        NSLog("[FluidAudio] transcribeFile: buffer created, reading file...")

        do {
            try audioFile.read(into: buffer)
            NSLog("[FluidAudio] transcribeFile: file read, frameLength=\(buffer.frameLength)")
        } catch {
            NSLog("[FluidAudio] ERROR: Failed to read audio file: \(error)")
            throw LiveFluidAudioClientError.transcriptionFailed("Failed to read audio file: \(error.localizedDescription)")
        }

        // Get float samples from buffer
        guard let floatChannelData = buffer.floatChannelData else {
            NSLog("[FluidAudio] ERROR: No float data in buffer")
            throw LiveFluidAudioClientError.transcriptionFailed("Audio file has no float data")
        }

        let totalSamples = Int(buffer.frameLength)
        NSLog("[FluidAudio] transcribeFile: got floatChannelData, totalSamples=\(totalSamples)")

        guard totalSamples > 0 else {
            NSLog("[FluidAudio] ERROR: Audio file has 0 samples")
            return []
        }

        let inputSamples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: totalSamples))
        NSLog("[FluidAudio] Read \(totalSamples) samples from file")

        // Resample from source rate (likely 48kHz) to 16kHz
        let sourceSampleRate = Int(fileFormat.sampleRate)
        let resampledSamples: [Float]
        if sourceSampleRate == sampleRate {
            resampledSamples = inputSamples
        } else {
            // Calculate resampling ratio
            let ratio = Double(sourceSampleRate) / Double(sampleRate)
            let outputCount = Int(Double(totalSamples) / ratio)
            resampledSamples = (0..<outputCount).map { i in
                let sourceIndex = Int(Double(i) * ratio)
                return inputSamples[min(sourceIndex, totalSamples - 1)]
            }
            NSLog("[FluidAudio] Resampled from \(sourceSampleRate)Hz to \(sampleRate)Hz: \(totalSamples) -> \(resampledSamples.count) samples")
        }

        // Process in chunks
        var segments: [TranscriptSegment] = []
        var offset = 0
        var processedMs: UInt64 = 0

        while offset < resampledSamples.count {
            let chunkSize = min(samplesPerChunk, resampledSamples.count - offset)
            let chunkSamples = Array(resampledSamples[offset..<(offset + chunkSize)])

            let chunkStartMs = processedMs
            let chunkDurationMs = UInt64(chunkSize * 1000 / sampleRate)
            let chunkEndMs = chunkStartMs + chunkDurationMs

            NSLog("[FluidAudio] Processing offline chunk: \(chunkStartMs)-\(chunkEndMs)ms, \(chunkSamples.count) samples")

            do {
                // Run ASR directly (not in detached task to maintain proper context)
                NSLog("[FluidAudio] Offline chunk: running ASR...")
                let asrResult = try await asrManager.transcribe(chunkSamples, source: .microphone)
                NSLog("[FluidAudio] Offline chunk: ASR completed")
                let transcriptText = asrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)

                if !transcriptText.isEmpty {
                    NSLog("[FluidAudio] Offline ASR result: '\(transcriptText)'")

                    // Run diarization
                    NSLog("[FluidAudio] Offline chunk: running diarization...")
                    let startTimeSeconds = TimeInterval(chunkStartMs) / 1000.0
                    let diarizationResult = try diarizerManager.performCompleteDiarization(
                        chunkSamples,
                        sampleRate: sampleRate,
                        atTime: startTimeSeconds
                    )
                    NSLog("[FluidAudio] Offline chunk: diarization completed")

                    let speakerId = findDominantSpeaker(in: diarizationResult)

                    let segment = TranscriptSegment(
                        id: TranscriptSegmentID(rawValue: uuid().uuidString),
                        text: transcriptText,
                        startMs: chunkStartMs,
                        endMs: chunkEndMs,
                        speakerId: speakerId,
                        isFinal: true
                    )
                    segments.append(segment)
                    NSLog("[FluidAudio] Offline chunk: segment added (total: \(segments.count))")
                } else {
                    NSLog("[FluidAudio] Offline chunk: empty transcription, skipping")
                }
            } catch {
                NSLog("[FluidAudio] Offline chunk error: \(type(of: error)) - \(error)")
                NSLog("[FluidAudio] Offline chunk error localizedDescription: \(error.localizedDescription)")
                // Continue processing other chunks
            }

            offset += chunkSize
            processedMs = chunkEndMs
        }

        NSLog("[FluidAudio] Offline transcription complete: \(segments.count) segments")
        return segments
    }

    // MARK: - Private Helpers

    private func processFrame(_ frame: AudioFrame) async {
        // The microphone captures at 48kHz Float32, we need 16kHz Float for ASR
        // Convert frame data from Float32 (from mic) and downsample
        let inputSamples = frame.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            guard let baseAddress = ptr.baseAddress else { return [] }
            let floatPtr = baseAddress.assumingMemoryBound(to: Float.self)
            let count = frame.data.count / MemoryLayout<Float>.size
            return Array(UnsafeBufferPointer(start: floatPtr, count: count))
        }

        // Downsample from 48kHz to 16kHz (3:1 ratio)
        // Simple decimation - take every 3rd sample
        let downsampledSamples = stride(from: 0, to: inputSamples.count, by: 3).map { inputSamples[$0] }

        accumulatedSamples.append(contentsOf: downsampledSamples)

        // Process chunks when we have enough audio
        while accumulatedSamples.count >= samplesPerChunk {
            await processChunk()
        }
    }

    private func processChunk() async {
        guard accumulatedSamples.count >= samplesPerChunk else { return }
        guard let asrManager = asrManager else {
            NSLog("[FluidAudio] ERROR: ASR manager not available in processChunk")
            return
        }

        // Extract chunk
        let chunkSamples = Array(accumulatedSamples.prefix(samplesPerChunk))
        accumulatedSamples.removeFirst(samplesPerChunk)

        let chunkStartMs = lastProcessedEndMs
        let chunkEndMs = chunkStartMs + chunkDurationMs
        lastProcessedEndMs = chunkEndMs

        NSLog("[FluidAudio] Processing chunk: \(chunkStartMs)-\(chunkEndMs)ms, \(chunkSamples.count) samples")

        do {
            // Run ASR for transcription (no live diarization - speaker IDs are assigned post-stop)
            NSLog("[FluidAudio] Running ASR transcribe...")
            let asrResult = try await asrManager.transcribe(chunkSamples, source: .microphone)
            let transcriptText = asrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
            NSLog("[FluidAudio] ASR result: '\(transcriptText)'")

            guard !transcriptText.isEmpty else {
                NSLog("[FluidAudio] Empty transcription, skipping")
                return
            }

            // Emit segment with nil speakerId - diarization is deferred to post-stop processing
            let segment = TranscriptSegment(
                id: TranscriptSegmentID(rawValue: uuid().uuidString),
                text: transcriptText,
                startMs: chunkStartMs,
                endMs: chunkEndMs,
                speakerId: nil,
                isFinal: true
            )

            NSLog("[FluidAudio] Yielding segment: '\(transcriptText)'")
            continuation?.yield(segment)
        } catch {
            // Log error but continue processing
            NSLog("[FluidAudio] processChunk ERROR: \(error)")
        }
    }

    private func processRemainingAudio() async {
        guard !accumulatedSamples.isEmpty else { return }
        guard let asrManager = asrManager else { return }

        let remainingSamples = accumulatedSamples
        accumulatedSamples = []

        let chunkStartMs = lastProcessedEndMs
        let durationMs = UInt64(remainingSamples.count * 1000 / sampleRate)
        let chunkEndMs = chunkStartMs + durationMs

        do {
            let asrResult = try await asrManager.transcribe(remainingSamples, source: .microphone)
            let transcriptText = asrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !transcriptText.isEmpty else { return }

            // Emit segment with nil speakerId - diarization is deferred to post-stop processing
            let segment = TranscriptSegment(
                id: TranscriptSegmentID(rawValue: uuid().uuidString),
                text: transcriptText,
                startMs: chunkStartMs,
                endMs: chunkEndMs,
                speakerId: nil,
                isFinal: true
            )

            continuation?.yield(segment)
        } catch {
            NSLog("[FluidAudio] processRemainingAudio error: \(error)")
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
            prepareModels: {
                await actor.prepareModels()
            },
            modelStatus: {
                await actor.getModelStatus()
            },
            startTranscription: { audioStream in
                // Initialize ASR on first use (lazy initialization inside actor)
                // Diarizer is NOT needed for live transcription
                try await actor.ensureASRInitialized()
                return try await actor.startTranscription(audioStream: audioStream)
            },
            stopTranscription: {
                await actor.stopTranscription()
            },
            isTranscribing: {
                await actor.getIsTranscribing()
            },
            transcribeFile: { audioFileURL in
                NSLog("[FluidAudio] Client.transcribeFile called, ensuring ASR initialized...")
                try await actor.ensureASRInitialized()
                NSLog("[FluidAudio] Client.transcribeFile: ASR initialized, calling actor (diarizer will init lazily)...")
                let result = try await actor.transcribeFile(audioFileURL: audioFileURL)
                NSLog("[FluidAudio] Client.transcribeFile: got \(result.count) segments")
                return result
            }
        )
    }
}

// MARK: - LiveFluidAudioClientError

public enum LiveFluidAudioClientError: Error, Sendable, Equatable {
    /// ASR models are not initialized (required for both live and offline transcription)
    case notInitialized
    /// Diarization models failed to initialize (offline transcription only)
    case diarizationUnavailable
    case modelDownloadFailed
    case transcriptionFailed(String)
}
