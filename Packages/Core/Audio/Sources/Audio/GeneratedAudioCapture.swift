import Foundation

// MARK: - GeneratedAudioConfig

/// Configuration for deterministic audio generation
public struct GeneratedAudioConfig: Sendable, Equatable {
    /// Duration of audio to generate in seconds
    public let durationSeconds: Double
    /// Sample rate (samples per second)
    public let sampleRate: Double
    /// Samples per frame emitted
    public let samplesPerFrame: Int
    /// Frequency of the generated sine wave in Hz (0 for silence)
    public let frequency: Double
    /// Amplitude of the generated signal (0.0 - 1.0)
    public let amplitude: Float

    public init(
        durationSeconds: Double,
        sampleRate: Double = 44100,
        samplesPerFrame: Int = 4096,
        frequency: Double = 440,
        amplitude: Float = 0.5
    ) {
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.samplesPerFrame = samplesPerFrame
        self.frequency = frequency
        self.amplitude = amplitude
    }

    /// Standard test config: 1 second of 440Hz sine at 44.1kHz
    public static let standard = GeneratedAudioConfig(durationSeconds: 1.0)

    /// Silent audio for testing processing without actual audio content
    public static func silent(durationSeconds: Double) -> GeneratedAudioConfig {
        GeneratedAudioConfig(
            durationSeconds: durationSeconds,
            frequency: 0,
            amplitude: 0
        )
    }
}

// MARK: - GeneratedAudioCapture

/// Actor to manage generated audio capture state
public actor GeneratedAudioCapture {
    private let config: GeneratedAudioConfig
    private var _isCapturing = false
    private var continuation: AsyncStream<AudioFrame>.Continuation?
    private var generatorTask: Task<Void, Never>?

    public init(config: GeneratedAudioConfig = .standard) {
        self.config = config
    }

    /// Start generating audio frames
    public func startCapture() -> AsyncStream<AudioFrame> {
        guard !_isCapturing else {
            return AsyncStream { $0.finish() }
        }

        _isCapturing = true

        let (stream, continuation) = AsyncStream<AudioFrame>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation

        let config = self.config

        // Start generation in background task
        generatorTask = Task { [weak self] in
            guard let self = self else { return }
            await self.generateFrames(config: config)
        }

        return stream
    }

    private func generateFrames(config: GeneratedAudioConfig) async {
        let totalSamples = Int(config.durationSeconds * config.sampleRate)
        var sampleIndex = 0
        var timestampNs: UInt64 = 0

        // Pre-calculate time increment per frame in nanoseconds
        let nsPerFrame = UInt64(Double(config.samplesPerFrame) / config.sampleRate * 1_000_000_000)

        while sampleIndex < totalSamples {
            // Check cancellation
            if Task.isCancelled { break }

            let capturing = _isCapturing
            guard capturing else { break }

            // Calculate samples for this frame
            let samplesThisFrame = min(config.samplesPerFrame, totalSamples - sampleIndex)

            // Generate frame data
            var samples = [Float](repeating: 0, count: samplesThisFrame)
            if config.frequency > 0 && config.amplitude > 0 {
                let angularFreq = 2.0 * Double.pi * config.frequency / config.sampleRate
                for i in 0..<samplesThisFrame {
                    let phase = angularFreq * Double(sampleIndex + i)
                    samples[i] = config.amplitude * Float(sin(phase))
                }
            }

            let data = samples.withUnsafeBytes { Data($0) }
            let frame = AudioFrame(data: data, timestamp: timestampNs)

            continuation?.yield(frame)

            sampleIndex += samplesThisFrame
            timestampNs += nsPerFrame

            // Yield to allow other tasks to run
            await Task.yield()
        }

        // Finish the stream when done
        continuation?.finish()
        _isCapturing = false
    }

    /// Stop generating audio
    public func stopCapture() {
        generatorTask?.cancel()
        generatorTask = nil
        continuation?.finish()
        continuation = nil
        _isCapturing = false
    }

    /// Check if currently generating
    public var isCapturing: Bool {
        _isCapturing
    }
}

// MARK: - AudioCaptureClient.generated

extension AudioCaptureClient {
    /// Creates an AudioCaptureClient that generates deterministic audio
    public static func generated(config: GeneratedAudioConfig = .standard) -> Self {
        let capture = GeneratedAudioCapture(config: config)

        return Self(
            startCapture: { await capture.startCapture() },
            stopCapture: { await capture.stopCapture() },
            isCapturing: { await capture.isCapturing }
        )
    }
}
