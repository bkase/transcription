import Foundation
import Testing
import Dependencies
import Models
@testable import Persistence

/// Tests for privacy mode / audio retention preferences
@Test func testPrivacyModePersists() async throws {
    // Test that audio retention mode can be set and retrieved through the preferences client
    // Uses a custom UserDefaults suite to avoid polluting real defaults

    let testSuite = UserDefaults(suiteName: "com.vapor.test.privacyMode")!
    // Clean up any previous test data
    testSuite.removeObject(forKey: "com.vapor.preferences.audioRetentionMode")

    // Create a test preferences client backed by test UserDefaults
    let testKey = "com.vapor.preferences.audioRetentionMode"

    let testClient = PreferencesClient(
        getAudioRetentionMode: {
            guard let rawValue = testSuite.string(forKey: testKey),
                  let mode = AudioRetentionMode(rawValue: rawValue) else {
                return .both
            }
            return mode
        },
        setAudioRetentionMode: { mode in
            testSuite.set(mode.rawValue, forKey: testKey)
        }
    )

    try await withDependencies {
        $0.preferencesClient = testClient
    } operation: {
        @Dependency(\.preferencesClient) var preferencesClient

        // Default should be .both
        let defaultMode = preferencesClient.getAudioRetentionMode()
        #expect(defaultMode == .both, "Default audio retention mode should be .both")

        // Set to transcript only
        preferencesClient.setAudioRetentionMode(.transcriptOnly)
        let transcriptMode = preferencesClient.getAudioRetentionMode()
        #expect(transcriptMode == .transcriptOnly, "Should persist transcriptOnly mode")

        // Set to audio only
        preferencesClient.setAudioRetentionMode(.audioOnly)
        let audioMode = preferencesClient.getAudioRetentionMode()
        #expect(audioMode == .audioOnly, "Should persist audioOnly mode")

        // Set back to both
        preferencesClient.setAudioRetentionMode(.both)
        let bothMode = preferencesClient.getAudioRetentionMode()
        #expect(bothMode == .both, "Should persist both mode")
    }

    // Clean up
    testSuite.removeObject(forKey: testKey)
}

/// Tests that all AudioRetentionMode cases have valid raw values for serialization
@Test func testAudioRetentionModeCodable() throws {
    // Test encoding/decoding roundtrip for all cases
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for mode in AudioRetentionMode.allCases {
        let encoded = try encoder.encode(mode)
        let decoded = try decoder.decode(AudioRetentionMode.self, from: encoded)
        #expect(decoded == mode, "AudioRetentionMode.\(mode) should roundtrip through JSON")
    }
}

/// Tests that the default preferences client can be instantiated
@Test func testPreferencesClientInstantiation() async {
    await withDependencies { deps in
        deps.preferencesClient = .liveValue
    } operation: {
        @Dependency(\.preferencesClient) var preferencesClient

        // Should not crash when accessing the live client
        let mode = preferencesClient.getAudioRetentionMode()
        // Mode should be one of the valid cases
        #expect(AudioRetentionMode.allCases.contains(mode), "Mode should be a valid case")
    }
}
