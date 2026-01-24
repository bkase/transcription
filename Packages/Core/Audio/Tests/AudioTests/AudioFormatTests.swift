import Foundation
import Testing
@testable import Audio

// MARK: - AudioConverter Tests

@Test func testConvertTo16kMonoFloat32FromHigherSampleRate() throws {
    // Create test audio data at 44.1kHz mono
    let inputSampleRate: Double = 44100
    let inputChannels: UInt32 = 1
    let durationSeconds: Double = 0.1

    // Generate a simple sine wave
    let sampleCount = Int(inputSampleRate * durationSeconds)
    var samples = [Float](repeating: 0, count: sampleCount)
    let frequency: Float = 440.0  // A4 note

    for i in 0..<sampleCount {
        let t = Float(i) / Float(inputSampleRate)
        samples[i] = sin(2.0 * .pi * frequency * t)
    }

    let inputData = samples.withUnsafeBytes { Data($0) }

    // Convert to 16kHz
    let outputData = try AudioConverter.convertTo16kMonoFloat32(
        inputData: inputData,
        inputSampleRate: inputSampleRate,
        inputChannels: inputChannels
    )

    // Verify output size is approximately correct for downsampling
    let expectedRatio = inputSampleRate / 16000.0
    let expectedSampleCount = Int(Double(sampleCount) / expectedRatio)
    let actualSampleCount = outputData.count / MemoryLayout<Float>.size

    // Allow some tolerance for rounding
    #expect(abs(actualSampleCount - expectedSampleCount) <= 1)

    // Verify output is valid Float32 data
    let outputSamples = outputData.withUnsafeBytes { buffer in
        Array(buffer.bindMemory(to: Float.self))
    }

    // Check that values are in valid range [-1, 1]
    for sample in outputSamples {
        #expect(sample >= -1.0 && sample <= 1.0)
    }
}

@Test func testConvertTo16kMonoFloat32FromStereo() throws {
    // Create stereo test data at 16kHz (no resampling needed)
    let inputSampleRate: Double = 16000
    let inputChannels: UInt32 = 2
    let sampleCount = 1000

    // Create stereo samples: left channel = 0.5, right channel = 0.3
    var stereoSamples = [Float](repeating: 0, count: sampleCount * 2)
    for i in 0..<sampleCount {
        stereoSamples[i * 2] = 0.5       // Left
        stereoSamples[i * 2 + 1] = 0.3   // Right
    }

    let inputData = stereoSamples.withUnsafeBytes { Data($0) }

    // Convert to mono
    let outputData = try AudioConverter.convertTo16kMonoFloat32(
        inputData: inputData,
        inputSampleRate: inputSampleRate,
        inputChannels: inputChannels
    )

    // Verify output is mono (half the sample count)
    let outputSampleCount = outputData.count / MemoryLayout<Float>.size
    #expect(outputSampleCount == sampleCount)

    // Verify mono samples are average of stereo
    let outputSamples = outputData.withUnsafeBytes { buffer in
        Array(buffer.bindMemory(to: Float.self))
    }

    let expectedAverage: Float = (0.5 + 0.3) / 2.0  // 0.4
    for sample in outputSamples {
        #expect(abs(sample - expectedAverage) < 0.001)
    }
}

@Test func testConvertTo16kMonoFloat32AlreadyCorrectFormat() throws {
    // Create test data already at 16kHz mono
    let inputSampleRate: Double = 16000
    let inputChannels: UInt32 = 1
    let sampleCount = 500

    var samples = [Float](repeating: 0, count: sampleCount)
    for i in 0..<sampleCount {
        samples[i] = Float(i) / Float(sampleCount)
    }

    let inputData = samples.withUnsafeBytes { Data($0) }

    // Convert (should be essentially a passthrough)
    let outputData = try AudioConverter.convertTo16kMonoFloat32(
        inputData: inputData,
        inputSampleRate: inputSampleRate,
        inputChannels: inputChannels
    )

    // Verify output is same size
    let outputSampleCount = outputData.count / MemoryLayout<Float>.size
    #expect(outputSampleCount == sampleCount)

    // Verify samples are unchanged
    let outputSamples = outputData.withUnsafeBytes { buffer in
        Array(buffer.bindMemory(to: Float.self))
    }

    for i in 0..<sampleCount {
        #expect(abs(outputSamples[i] - samples[i]) < 0.001)
    }
}

@Test func testConvertTo16kMonoFloat32EmptyInput() {
    let emptyData = Data()

    #expect(throws: AudioConversionError.emptyInput) {
        try AudioConverter.convertTo16kMonoFloat32(
            inputData: emptyData,
            inputSampleRate: 44100,
            inputChannels: 1
        )
    }
}

@Test func testConvertTo16kMonoFloat32InvalidChannelCount() {
    // Create data with more than 2 channels worth
    let samples = [Float](repeating: 0.5, count: 300)
    let inputData = samples.withUnsafeBytes { Data($0) }

    #expect(throws: AudioConversionError.invalidInputFormat) {
        try AudioConverter.convertTo16kMonoFloat32(
            inputData: inputData,
            inputSampleRate: 44100,
            inputChannels: 3  // Invalid: only 1 or 2 channels supported
        )
    }
}

// MARK: - AudioFormatConfig Tests

@Test func testAudioFormatConfigMLTranscription() {
    let config = AudioFormatConfig.mlTranscription

    #expect(config.sampleRate == 16000)
    #expect(config.channels == 1)
    #expect(config.isFloat == true)
}

@Test func testAudioFormatConfigRecording() {
    let config = AudioFormatConfig.recording

    #expect(config.sampleRate == 44100)
    #expect(config.channels == 1)
    #expect(config.isFloat == true)
}

@Test func testAudioFormatConfigEquality() {
    let config1 = AudioFormatConfig(sampleRate: 48000, channels: 2, isFloat: true)
    let config2 = AudioFormatConfig(sampleRate: 48000, channels: 2, isFloat: true)
    let config3 = AudioFormatConfig(sampleRate: 44100, channels: 2, isFloat: true)

    #expect(config1 == config2)
    #expect(config1 != config3)
}
