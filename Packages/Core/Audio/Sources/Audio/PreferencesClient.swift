import Foundation
import Dependencies
import DependenciesMacros

// MARK: - Audio Retention Mode

/// Controls what data is retained after recording
public enum AudioRetentionMode: String, Codable, Sendable, CaseIterable {
    /// Keep transcript only, delete audio after transcription
    case transcriptOnly
    /// Keep audio only, no transcription
    case audioOnly
    /// Keep both audio and transcript (default)
    case both
}

// MARK: - Preferences Client

/// Client for reading and writing app preferences
@DependencyClient
public struct PreferencesClient: Sendable {
    /// Get the current audio retention mode
    public var getAudioRetentionMode: @Sendable () -> AudioRetentionMode = { .both }
    /// Set the audio retention mode
    public var setAudioRetentionMode: @Sendable (_ mode: AudioRetentionMode) -> Void
}

// MARK: - Dependency Key

extension PreferencesClient: DependencyKey {
    private static let audioRetentionModeKey = "com.vapor.preferences.audioRetentionMode"

    public static var liveValue: Self {
        Self(
            getAudioRetentionMode: {
                guard let rawValue = UserDefaults.standard.string(forKey: audioRetentionModeKey),
                      let mode = AudioRetentionMode(rawValue: rawValue) else {
                    return .both
                }
                return mode
            },
            setAudioRetentionMode: { mode in
                UserDefaults.standard.set(mode.rawValue, forKey: audioRetentionModeKey)
            }
        )
    }

    public static var previewValue: Self {
        Self(
            getAudioRetentionMode: { .both },
            setAudioRetentionMode: { _ in }
        )
    }

    public static var testValue: Self { Self() }
}

extension DependencyValues {
    public var preferencesClient: PreferencesClient {
        get { self[PreferencesClient.self] }
        set { self[PreferencesClient.self] = newValue }
    }
}
