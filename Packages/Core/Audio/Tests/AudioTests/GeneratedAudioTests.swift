import Testing
import Foundation
@testable import Audio

@Test func testGeneratedAudioProducesExpectedDuration() async {
    // Config: 1 second at 44.1kHz with 4096 samples per frame
    let config = GeneratedAudioConfig(
        durationSeconds: 1.0,
        sampleRate: 44100,
        samplesPerFrame: 4096,
        frequency: 440,
        amplitude: 0.5
    )

    let capture = GeneratedAudioCapture(config: config)
    let stream = await capture.startCapture()

    // Collect all frames
    var frames: [AudioFrame] = []
    for await frame in stream {
        frames.append(frame)
    }

    // Verify capture completed
    let isCapturing = await capture.isCapturing
    #expect(!isCapturing)

    // Calculate total samples received
    let bytesPerSample = MemoryLayout<Float>.size
    let totalBytes = frames.reduce(0) { $0 + $1.data.count }
    let totalSamples = totalBytes / bytesPerSample

    // Expected: 1 second * 44100 samples/second = 44100 samples
    let expectedSamples = Int(config.durationSeconds * config.sampleRate)
    #expect(totalSamples == expectedSamples)

    // Verify frame count: 44100 / 4096 = 10 full frames + 1 partial
    let expectedFrameCount = Int(ceil(Double(expectedSamples) / Double(config.samplesPerFrame)))
    #expect(frames.count == expectedFrameCount)
}

@Test func testGeneratedAudioTimestampsAreMonotonic() async {
    let config = GeneratedAudioConfig(
        durationSeconds: 0.5,
        sampleRate: 16000,
        samplesPerFrame: 1024
    )

    let capture = GeneratedAudioCapture(config: config)
    let stream = await capture.startCapture()

    var frames: [AudioFrame] = []
    for await frame in stream {
        frames.append(frame)
    }

    // Verify timestamps are strictly increasing
    for i in 1..<frames.count {
        #expect(frames[i].timestamp > frames[i - 1].timestamp,
               "Timestamp at index \(i) should be greater than previous")
    }

    // First timestamp should be 0
    if let first = frames.first {
        #expect(first.timestamp == 0)
    }
}

@Test func testGeneratedAudioStopsEarly() async {
    let config = GeneratedAudioConfig(
        durationSeconds: 10.0,  // Long duration
        sampleRate: 44100,
        samplesPerFrame: 4096
    )

    let capture = GeneratedAudioCapture(config: config)
    let stream = await capture.startCapture()

    let capturingBefore = await capture.isCapturing
    #expect(capturingBefore)

    // Only collect a few frames then stop
    var frameCount = 0
    for await _ in stream {
        frameCount += 1
        if frameCount >= 3 {
            await capture.stopCapture()
            break
        }
    }

    let capturingAfter = await capture.isCapturing
    #expect(!capturingAfter)
    #expect(frameCount >= 3)
}

@Test func testGeneratedAudioSilentConfig() async {
    let config = GeneratedAudioConfig.silent(durationSeconds: 0.1)

    let capture = GeneratedAudioCapture(config: config)
    let stream = await capture.startCapture()

    var frames: [AudioFrame] = []
    for await frame in stream {
        frames.append(frame)
    }

    // Verify we got frames
    #expect(!frames.isEmpty)

    // Verify all samples are zero (silent)
    for frame in frames {
        let samples = frame.data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
        for sample in samples {
            #expect(sample == 0, "Silent config should produce zero samples")
        }
    }
}

@Test func testGeneratedAudioClientInterface() async throws {
    let config = GeneratedAudioConfig(durationSeconds: 0.2)
    let client = AudioCaptureClient.generated(config: config)

    // Initially not capturing
    let initialCapturing = await client.isCapturing()
    #expect(!initialCapturing)

    // Start capture
    let stream = try await client.startCapture()
    let capturingAfterStart = await client.isCapturing()
    #expect(capturingAfterStart)

    // Consume stream
    var frameCount = 0
    for await _ in stream {
        frameCount += 1
    }

    // Should have produced frames
    #expect(frameCount > 0)

    // After stream completes, not capturing
    let capturingAfterComplete = await client.isCapturing()
    #expect(!capturingAfterComplete)
}

@Test func testGeneratedAudioSineWaveValues() async {
    let config = GeneratedAudioConfig(
        durationSeconds: 0.01,  // Short duration
        sampleRate: 44100,
        samplesPerFrame: 441,   // 10ms worth
        frequency: 440,
        amplitude: 0.5
    )

    let capture = GeneratedAudioCapture(config: config)
    let stream = await capture.startCapture()

    var firstFrame: AudioFrame?
    for await frame in stream {
        firstFrame = frame
        break
    }
    await capture.stopCapture()

    guard let frame = firstFrame else {
        Issue.record("Expected at least one frame")
        return
    }

    let samples = frame.data.withUnsafeBytes { buffer in
        Array(buffer.bindMemory(to: Float.self))
    }

    // First sample of 440Hz sine at 44100Hz should be 0 (sin(0) = 0)
    #expect(abs(samples[0]) < 0.001, "First sample should be near zero")

    // Verify amplitude is bounded
    for sample in samples {
        #expect(abs(sample) <= config.amplitude + 0.001,
               "Sample should not exceed amplitude")
    }
}
