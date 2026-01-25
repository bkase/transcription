import AVFoundation
import Dependencies
import DependenciesMacros
#if canImport(UIKit)
import UIKit
#endif

// MARK: - MicrophonePermissionStatus

/// Represents the current state of microphone permission
public enum MicrophonePermissionStatus: Sendable, Equatable {
    /// Permission has not been requested yet
    case undetermined
    /// Permission has been granted
    case authorized
    /// Permission has been denied by the user
    case denied
    /// Permission is restricted (e.g., parental controls)
    case restricted

    /// Whether audio recording is allowed
    public var isAuthorized: Bool {
        self == .authorized
    }

    /// Whether the user can potentially grant permission (not restricted)
    public var canRequestPermission: Bool {
        self == .undetermined
    }
}

// MARK: - MicrophonePermissionClient

/// Client for managing microphone permissions
@DependencyClient
public struct MicrophonePermissionClient: Sendable {
    /// Get the current permission status
    public var getStatus: @Sendable () -> MicrophonePermissionStatus = { .undetermined }

    /// Request microphone permission. Returns true if granted, false otherwise.
    public var requestPermission: @Sendable () async -> Bool = { false }

    /// Open app settings for the user to change permissions
    public var openSettings: @Sendable () async -> Void
}

// MARK: - Live Implementation

#if os(iOS)
extension MicrophonePermissionClient {
    /// Creates a live permission client that interacts with AVAudioSession
    public static func live() -> MicrophonePermissionClient {
        MicrophonePermissionClient(
            getStatus: {
                let status = AVAudioApplication.shared.recordPermission
                switch status {
                case .undetermined:
                    return .undetermined
                case .granted:
                    return .authorized
                case .denied:
                    return .denied
                @unknown default:
                    return .denied
                }
            },
            requestPermission: {
                await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            },
            openSettings: {
                await MainActor.run {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            }
        )
    }
}
#endif

// MARK: - DependencyKey

extension MicrophonePermissionClient: DependencyKey {
    #if os(iOS)
    public static let liveValue = MicrophonePermissionClient.live()
    #else
    public static let liveValue = MicrophonePermissionClient()
    #endif
    public static let testValue = MicrophonePermissionClient()
}

extension DependencyValues {
    public var microphonePermissionClient: MicrophonePermissionClient {
        get { self[MicrophonePermissionClient.self] }
        set { self[MicrophonePermissionClient.self] = newValue }
    }
}
