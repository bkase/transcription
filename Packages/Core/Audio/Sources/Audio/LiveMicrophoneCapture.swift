import AVFoundation
import Foundation

// MARK: - LiveMicrophoneCapture

/// Captures audio from the microphone using AVAudioEngine
public final class LiveMicrophoneCapture: @unchecked Sendable {
    private let engine: AudioEngineProtocol
    private let lock = NSLock()
    private var _isCapturing = false
    private var continuation: AsyncStream<AudioFrame>.Continuation?

    public init(engine: AudioEngineProtocol = AVAudioEngine()) {
        self.engine = engine
    }

    /// Start capturing audio frames
    public func startCapture() throws -> AsyncStream<AudioFrame> {
        lock.lock()

        guard !_isCapturing else {
            lock.unlock()
            // Return an empty stream that finishes immediately
            return AsyncStream { continuation in
                continuation.finish()
            }
        }

        _isCapturing = true

        // Create stream using makeStream for immediate access to continuation
        // Use unbounded buffering to ensure frames aren't dropped
        let (stream, continuation) = AsyncStream<AudioFrame>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation

        // Get format from input node
        let inputNode = engine.audioInputNode
        let format = inputNode.outputFormat(0)

        // Install tap to capture audio buffers
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            guard let self = self else { return }

            // Convert buffer to Data
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let data = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Float>.size)

            let frame = AudioFrame(
                data: data,
                timestamp: time.hostTime
            )

            self.lock.lock()
            let cont = self.continuation
            self.lock.unlock()

            cont?.yield(frame)
        }

        lock.unlock()

        // Prepare and start the engine
        engine.prepare()
        try engine.start()

        return stream
    }

    /// Stop capturing audio
    public func stopCapture() {
        lock.lock()
        defer { lock.unlock() }
        stopCaptureInternal()
    }

    private func stopCaptureInternal() {
        guard _isCapturing else { return }

        engine.audioInputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        continuation = nil
        _isCapturing = false
    }

    /// Check if currently capturing
    public var isCapturing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCapturing
    }

    /// Get the input format from the microphone
    /// Returns the actual sample rate and channel count from the audio engine's input node
    public func getInputFormat() -> AudioFormatConfig {
        let inputNode = engine.audioInputNode
        let format = inputNode.outputFormat(0)
        return AudioFormatConfig(
            sampleRate: format.sampleRate,
            channels: UInt32(format.channelCount),
            isFloat: true
        )
    }
}

// MARK: - AudioCaptureClient.live

extension AudioCaptureClient {
    /// Creates a live AudioCaptureClient using AVAudioEngine
    public static func live(engine: AudioEngineProtocol = AVAudioEngine()) -> Self {
        let capture = LiveMicrophoneCapture(engine: engine)

        return Self(
            startCapture: { try capture.startCapture() },
            stopCapture: { capture.stopCapture() },
            isCapturing: { capture.isCapturing },
            getInputFormat: { capture.getInputFormat() }
        )
    }
}
