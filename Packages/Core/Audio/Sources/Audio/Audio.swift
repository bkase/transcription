import Foundation
import Models
import Dependencies
import DependenciesMacros

// MARK: - AudioFrame

/// Represents a chunk of PCM audio data
public struct AudioFrame: Sendable, Equatable {
    public let data: Data
    public let timestamp: UInt64

    public init(data: Data, timestamp: UInt64) {
        self.data = data
        self.timestamp = timestamp
    }
}

// MARK: - AudioCaptureClient

/// Client for audio capture operations
@DependencyClient
public struct AudioCaptureClient: Sendable {
    /// Start capturing audio, returns a stream of audio frames
    public var startCapture: @Sendable () async throws -> AsyncStream<AudioFrame>
    /// Stop capturing audio
    public var stopCapture: @Sendable () async -> Void
    /// Check if currently capturing
    public var isCapturing: @Sendable () async -> Bool = { false }
    /// Get the input format (sample rate, channels) from the microphone
    /// Must be called after audio session is configured
    public var getInputFormat: @Sendable () -> AudioFormatConfig = { .recording }
}

extension AudioCaptureClient: DependencyKey {
    public static var liveValue: Self { .live() }

    public static let testValue = Self()
}

extension DependencyValues {
    public var audioCaptureClient: AudioCaptureClient {
        get { self[AudioCaptureClient.self] }
        set { self[AudioCaptureClient.self] = newValue }
    }
}

// MARK: - AudioPlayerClient

/// Client for audio playback operations
@DependencyClient
public struct AudioPlayerClient: Sendable {
    /// Play audio from a file URL
    public var play: @Sendable (_ url: URL) async throws -> Void
    /// Pause playback
    public var pause: @Sendable () async -> Void
    /// Stop playback
    public var stop: @Sendable () async -> Void
    /// Seek to a specific time
    public var seek: @Sendable (_ time: TimeInterval) async -> Void
    /// Get current playback time
    public var currentTime: @Sendable () async -> TimeInterval = { 0 }
    /// Check if currently playing
    public var isPlaying: @Sendable () async -> Bool = { false }
}

extension AudioPlayerClient: DependencyKey {
    public static var liveValue: Self { .live() }

    public static let testValue = Self()
}

extension DependencyValues {
    public var audioPlayerClient: AudioPlayerClient {
        get { self[AudioPlayerClient.self] }
        set { self[AudioPlayerClient.self] = newValue }
    }
}
