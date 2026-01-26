import AVFoundation
import Foundation

// MARK: - AudioPlayerProtocol

/// Protocol abstracting AVAudioPlayer for testing
public protocol AudioPlayerProtocol: AnyObject, Sendable {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    func play() -> Bool
    func pause()
    func stop()
    func prepareToPlay() -> Bool
}

// MARK: - AVAudioPlayer Conformance

extension AVAudioPlayer: @retroactive @unchecked Sendable {}

extension AVAudioPlayer: AudioPlayerProtocol {}

// MARK: - AudioPlayerFactory

/// Factory protocol for creating audio players from URLs
public protocol AudioPlayerFactoryProtocol: Sendable {
    func createPlayer(url: URL) throws -> AudioPlayerProtocol
}

/// Default factory that creates AVAudioPlayer instances
public struct AVAudioPlayerFactory: AudioPlayerFactoryProtocol {
    public init() {}

    public func createPlayer(url: URL) throws -> AudioPlayerProtocol {
        try AVAudioPlayer(contentsOf: url)
    }
}

// MARK: - LiveAudioPlayer

/// Manages audio playback using AVAudioPlayer
public final class LiveAudioPlayer: @unchecked Sendable {
    private let lock = NSLock()
    private let factory: AudioPlayerFactoryProtocol
    private var player: AudioPlayerProtocol?
    private var _currentURL: URL?

    public init(factory: AudioPlayerFactoryProtocol = AVAudioPlayerFactory()) {
        self.factory = factory
    }

    /// Play audio from a file URL
    public func play(url: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        // If already playing this URL, just resume
        if let existing = player, _currentURL == url {
            _ = existing.play()
            return
        }

        // Stop any existing playback
        player?.stop()

        // Create new player
        let newPlayer = try factory.createPlayer(url: url)
        _ = newPlayer.prepareToPlay()
        _ = newPlayer.play()

        player = newPlayer
        _currentURL = url
    }

    /// Pause playback
    public func pause() {
        lock.lock()
        defer { lock.unlock() }
        player?.pause()
    }

    /// Stop playback
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        player?.stop()
        player = nil
        _currentURL = nil
    }

    /// Seek to a specific time
    public func seek(to time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        player?.currentTime = time
    }

    /// Get current playback time
    public var currentTime: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return player?.currentTime ?? 0
    }

    /// Check if currently playing
    public var isPlaying: Bool {
        lock.lock()
        defer { lock.unlock() }
        return player?.isPlaying ?? false
    }

    /// Get the duration of the current audio file
    public var duration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return player?.duration ?? 0
    }
}

// MARK: - AudioPlayerClient.live

extension AudioPlayerClient {
    /// Creates a live AudioPlayerClient using AVAudioPlayer
    public static func live(factory: AudioPlayerFactoryProtocol = AVAudioPlayerFactory()) -> Self {
        let player = LiveAudioPlayer(factory: factory)

        return Self(
            play: { url in try player.play(url: url) },
            pause: { player.pause() },
            stop: { player.stop() },
            seek: { time in player.seek(to: time) },
            currentTime: { player.currentTime },
            isPlaying: { player.isPlaying }
        )
    }
}
