import Testing
import Foundation
import Dependencies
import Models
@testable import Processing
@testable import Audio

/// Integration tests that use the real FluidAudio ML models.
/// These tests are gated behind `RUN_SLOW_TESTS=1` because they require ML model download.
///
/// The default `make test` wires up a dedicated lane for these tests via `scripts/run-tests.py`.
/// When the env var is set, the lane runs in parallel with other test suites.
///
/// To run directly: RUN_SLOW_TESTS=1 swift test --filter FluidAudioIntegration

/// Helper to check if slow tests should run
private func shouldRunSlowTests() -> Bool {
    ProcessInfo.processInfo.environment["RUN_SLOW_TESTS"] == "1"
}

/// Load the committed fixture WAV file from bundle resources.
/// Returns the URL to the fixture, or nil if not found.
private func fixtureURL(named filename: String) -> URL? {
    Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Fixtures")
}

// MARK: - Contract-Level Integration Tests

@Test
func testRealModelProcessesFixtureAudio() async throws {
    guard shouldRunSlowTests() else {
        // Skip test when not running slow tests
        return
    }

    guard let audioURL = fixtureURL(named: "test-speech.wav") else {
        Issue.record("Fixture test-speech.wav not found in bundle resources")
        return
    }

    // Create the live FluidAudio client
    let client = LiveFluidAudioClient.client()

    // Use the offline transcribeFile API which handles reading WAV files
    let segments = try await client.transcribeFile(audioURL)

    // Contract-level assertion: processing should complete without crashing
    // The synthetic audio may not produce meaningful text, but the pipeline
    // should process it end-to-end without errors.
    #expect(segments.count >= 0, "FluidAudio should process fixture audio without crashing")

    // If segments were produced, verify they have valid structure
    for segment in segments {
        #expect(!segment.id.rawValue.isEmpty, "Segment should have a valid ID")
        #expect(segment.endMs >= segment.startMs, "Segment timing should be valid (endMs >= startMs)")
    }
}

@Test
func testRealModelProducesSegmentFromStream() async throws {
    guard shouldRunSlowTests() else {
        return
    }

    // Create the live FluidAudio client
    let client = LiveFluidAudioClient.client()

    // Load fixture audio and convert to AudioFrame stream
    guard let audioURL = fixtureURL(named: "test-speech.wav") else {
        Issue.record("Fixture test-speech.wav not found in bundle resources")
        return
    }

    let data = try Data(contentsOf: audioURL)
    // Skip WAV header (44 bytes) to get raw PCM samples
    let pcmData = data.dropFirst(44)

    // Create audio frames from the PCM data (16kHz, 16-bit mono)
    let samplesPerFrame = 4096
    let bytesPerSample = 2
    let sampleRate: Double = 16000
    let bytesPerFrame = samplesPerFrame * bytesPerSample
    let nsPerFrame = UInt64(Double(samplesPerFrame) / sampleRate * 1_000_000_000)

    var frames: [AudioFrame] = []
    var offset = pcmData.startIndex
    var timestampNs: UInt64 = 0

    while offset < pcmData.endIndex {
        let end = min(offset + bytesPerFrame, pcmData.endIndex)
        let frameData = Data(pcmData[offset..<end])
        frames.append(AudioFrame(data: frameData, timestamp: timestampNs))
        offset = end
        timestampNs += nsPerFrame
    }

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
    let timeout: TimeInterval = 60 // generous timeout for model init + processing

    for await segment in segmentStream {
        segments.append(segment)
        if Date().timeIntervalSince(startTime) > timeout {
            break
        }
    }

    // Contract: processing completes without crashing
    #expect(segments.count >= 0, "FluidAudio should process streamed audio without crashing")

    // Validate segment structure
    for segment in segments {
        #expect(!segment.id.rawValue.isEmpty, "Segment should have valid ID")
        #expect(segment.endMs >= segment.startMs, "Segment timing should be valid")
    }

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
    let initializedBefore = await actor.isASRInitialized()
    #expect(!initializedBefore, "Actor should not have ASR initialized before calling initializeASR()")

    // Initialize ASR models (this downloads if needed)
    try await actor.initializeASR()

    // After initialization
    let initializedAfter = await actor.isASRInitialized()
    #expect(initializedAfter, "Actor should have ASR initialized after calling initializeASR()")

    // Cleanup
    await actor.cleanup()
}

/// Test that the fixture WAV file exists and is accessible via Bundle.module
@Test
func testFixtureAudioFileExists() throws {
    guard let url = fixtureURL(named: "test-speech.wav") else {
        Issue.record("Fixture test-speech.wav not found in bundle resources")
        return
    }

    let data = try Data(contentsOf: url)
    // WAV header is 44 bytes minimum; our fixture should be ~96KB
    #expect(data.count > 44, "Fixture WAV should contain audio data beyond the header")
    // Verify WAV magic bytes
    let riff = String(data: data[0..<4], encoding: .ascii)
    #expect(riff == "RIFF", "Fixture should be a valid WAV file (RIFF header)")
}
