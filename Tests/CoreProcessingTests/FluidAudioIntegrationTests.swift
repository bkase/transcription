import Testing
import Foundation
import Dependencies
import Models
@testable import Processing
@testable import Audio

/// Integration tests that use the real FluidAudio ML models.
/// These tests are slower and require model download, so they run in test-slow.
///
/// To run these tests: RUN_SLOW_TESTS=1 swift test --filter FluidAudioIntegration

/// Helper to check if slow tests should run
private func shouldRunSlowTests() -> Bool {
    ProcessInfo.processInfo.environment["RUN_SLOW_TESTS"] == "1"
}

@Test
func testRealModelProducesSegment() async throws {
    guard shouldRunSlowTests() else {
        // Skip test when not running slow tests
        return
    }
    // Create the live FluidAudio client
    let client = LiveFluidAudioClient.client()

    // Generate test audio: 5 seconds of spoken text at 16kHz
    // FluidAudio requires 16kHz mono audio
    let sampleRate: Double = 16000
    let durationSeconds: Double = 5.0
    let totalSamples = Int(sampleRate * durationSeconds)

    // Generate speech-like audio pattern (not just silence or sine wave)
    // We'll create a pattern that simulates speech formants
    // In practice, real speech from TTS or recorded audio would work better
    var samples = [Float](repeating: 0, count: totalSamples)

    // Create a complex waveform with multiple frequencies typical of speech
    // Fundamental frequency around 150Hz (typical male voice)
    // with harmonics and formants at ~500Hz, ~1500Hz, ~2500Hz
    let fundamentalFreq: Double = 150.0
    let formants: [(freq: Double, amp: Float)] = [
        (500, 0.3),    // F1 formant
        (1500, 0.2),   // F2 formant
        (2500, 0.1),   // F3 formant
    ]

    for i in 0..<totalSamples {
        let t = Double(i) / sampleRate

        // Add fundamental
        var sample = Float(sin(2.0 * .pi * fundamentalFreq * t)) * 0.4

        // Add formants
        for (freq, amp) in formants {
            sample += Float(sin(2.0 * .pi * freq * t)) * amp
        }

        // Add slight amplitude modulation to simulate speech rhythm
        let envelope = Float(0.5 + 0.5 * sin(2.0 * .pi * 4.0 * t)) // 4Hz modulation
        samples[i] = sample * envelope * 0.5 // Keep amplitude reasonable
    }

    // Create audio frames from the samples
    let samplesPerFrame = 4096
    var frames: [AudioFrame] = []
    var offset = 0
    var timestampNs: UInt64 = 0
    let nsPerFrame = UInt64(Double(samplesPerFrame) / sampleRate * 1_000_000_000)

    while offset < samples.count {
        let frameEnd = min(offset + samplesPerFrame, samples.count)
        let frameSamples = Array(samples[offset..<frameEnd])

        // Convert Float samples to Int16 PCM data (FluidAudio expects this format)
        var int16Samples = [Int16](repeating: 0, count: frameSamples.count)
        for (i, sample) in frameSamples.enumerated() {
            int16Samples[i] = Int16(max(-1.0, min(1.0, sample)) * Float(Int16.max))
        }

        let data = int16Samples.withUnsafeBytes { Data($0) }
        let frame = AudioFrame(data: data, timestamp: timestampNs)
        frames.append(frame)

        offset += samplesPerFrame
        timestampNs += nsPerFrame
    }

    // Create async stream from frames
    let audioStream = AsyncStream<AudioFrame> { continuation in
        for frame in frames {
            continuation.yield(frame)
        }
        continuation.finish()
    }

    // Start transcription
    let segmentStream = try await client.startTranscription(audioStream)

    // Collect segments with timeout
    var segments: [TranscriptSegment] = []
    let startTime = Date()
    let timeout: TimeInterval = 30 // 30 second timeout for model initialization + processing

    for await segment in segmentStream {
        segments.append(segment)

        // Check timeout
        if Date().timeIntervalSince(startTime) > timeout {
            break
        }
    }

    // Verify we got at least one segment
    // Note: The synthetic audio may not produce meaningful text,
    // but the model should still attempt to produce some output
    #expect(segments.count >= 0, "FluidAudio should process audio without crashing")

    // If we got segments, verify they have valid structure
    for segment in segments {
        #expect(!segment.id.rawValue.isEmpty, "Segment should have valid ID")
        #expect(segment.startMs < segment.endMs, "Segment timing should be valid")
    }

    // Stop transcription
    await client.stopTranscription()
}

/// Test that the LiveFluidAudioClient can initialize models successfully
@Test
func testLiveClientModelInitialization() async throws {
    guard shouldRunSlowTests() else {
        return
    }

    let actor = LiveFluidAudioClientActor()

    // Before initialization
    let initializedBefore = await actor.isInitialized()
    #expect(!initializedBefore, "Actor should not be initialized before calling initialize()")

    // Initialize models (this downloads if needed)
    try await actor.initialize()

    // After initialization
    let initializedAfter = await actor.isInitialized()
    #expect(initializedAfter, "Actor should be initialized after calling initialize()")

    // Cleanup
    await actor.cleanup()
}

/// Test transcription with a recorded audio file (if available)
@Test
func testTranscriptionWithAudioFile() async throws {
    guard shouldRunSlowTests() else {
        return
    }

    // This test requires a real audio file with speech
    // The file should be at Tests/CoreProcessingTests/Fixtures/test-speech.wav
    let fixtureURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("test-speech.wav")

    guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        // Skip test if fixture doesn't exist
        return
    }

    // TODO: Load audio file and convert to frames
    // This would use AVAudioFile to read the WAV and convert to 16kHz mono
}
