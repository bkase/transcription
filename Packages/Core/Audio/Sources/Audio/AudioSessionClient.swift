import AVFoundation
import Foundation
import Dependencies
import DependenciesMacros

// MARK: - AudioSessionEvent

/// Events emitted by the audio session observer
public enum AudioSessionEvent: Sendable, Equatable {
    /// Audio session was interrupted (e.g., phone call, Siri)
    case interrupted(InterruptionType)
    /// Audio route changed (e.g., headphones connected/disconnected)
    case routeChanged(RouteChangeReason)
}

/// Type of audio session interruption
public enum InterruptionType: Sendable, Equatable {
    case began
    case ended(shouldResume: Bool)
}

/// Reason for audio route change
public enum RouteChangeReason: Sendable, Equatable {
    case newDeviceAvailable
    case oldDeviceUnavailable
    case categoryChange
    case override
    case wakeFromSleep
    case noSuitableRouteForCategory
    case routeConfigurationChange
    case unknown

    #if os(iOS)
    init(from avReason: AVAudioSession.RouteChangeReason) {
        switch avReason {
        case .newDeviceAvailable:
            self = .newDeviceAvailable
        case .oldDeviceUnavailable:
            self = .oldDeviceUnavailable
        case .categoryChange:
            self = .categoryChange
        case .override:
            self = .override
        case .wakeFromSleep:
            self = .wakeFromSleep
        case .noSuitableRouteForCategory:
            self = .noSuitableRouteForCategory
        case .routeConfigurationChange:
            self = .routeConfigurationChange
        case .unknown:
            self = .unknown
        @unknown default:
            self = .unknown
        }
    }
    #endif
}

// MARK: - AudioSessionClient

/// Client for observing audio session events (interruptions, route changes)
@DependencyClient
public struct AudioSessionClient: Sendable {
    /// Start observing audio session events
    public var startObserving: @Sendable () async -> AsyncStream<AudioSessionEvent> = { AsyncStream { $0.finish() } }
    /// Stop observing audio session events
    public var stopObserving: @Sendable () async -> Void
    /// Configure audio session for recording
    public var configureForRecording: @Sendable () async throws -> Void
}

extension AudioSessionClient: DependencyKey {
    #if os(iOS)
    public static var liveValue: Self {
        let observer = LiveAudioSessionObserver()
        return Self(
            startObserving: { await observer.startObserving() },
            stopObserving: { await observer.stopObserving() },
            configureForRecording: { try await observer.configureForRecording() }
        )
    }
    #else
    // macOS fallback - no audio session management needed
    public static var liveValue: Self {
        Self(
            startObserving: { AsyncStream { $0.finish() } },
            stopObserving: { },
            configureForRecording: { }
        )
    }
    #endif

    public static let testValue = Self()
}

extension DependencyValues {
    public var audioSessionClient: AudioSessionClient {
        get { self[AudioSessionClient.self] }
        set { self[AudioSessionClient.self] = newValue }
    }
}

// MARK: - LiveAudioSessionObserver

#if os(iOS)
/// Live implementation of audio session observation
actor LiveAudioSessionObserver {
    private var continuation: AsyncStream<AudioSessionEvent>.Continuation?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var isObserving = false

    init() {}

    /// Configure the audio session for recording
    func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setActive(true)
    }

    /// Start observing audio session events
    func startObserving() -> AsyncStream<AudioSessionEvent> {
        guard !isObserving else {
            // Return empty stream if already observing
            return AsyncStream { $0.finish() }
        }

        isObserving = true

        let (stream, continuation) = AsyncStream<AudioSessionEvent>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation

        // Capture self weakly for notification handlers
        let notificationCenter = NotificationCenter.default

        // Observe interruptions
        interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task { await self.handleInterruption(notification) }
        }

        // Observe route changes
        routeChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task { await self.handleRouteChange(notification) }
        }

        return stream
    }

    /// Stop observing audio session events
    func stopObserving() {
        guard isObserving else { return }

        let notificationCenter = NotificationCenter.default

        if let observer = interruptionObserver {
            notificationCenter.removeObserver(observer)
            interruptionObserver = nil
        }

        if let observer = routeChangeObserver {
            notificationCenter.removeObserver(observer)
            routeChangeObserver = nil
        }

        continuation?.finish()
        continuation = nil
        isObserving = false
    }

    // MARK: - Private Handlers

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            continuation?.yield(.interrupted(.began))

        case .ended:
            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }
            continuation?.yield(.interrupted(.ended(shouldResume: shouldResume)))

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let avReason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        let reason = RouteChangeReason(from: avReason)
        continuation?.yield(.routeChanged(reason))
    }
}
#endif
