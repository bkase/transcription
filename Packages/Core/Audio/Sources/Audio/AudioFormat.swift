import AVFoundation
import Foundation

// MARK: - AudioFormat Utilities

/// Audio format configuration for the transcription pipeline
public struct AudioFormatConfig: Sendable, Equatable {
    public let sampleRate: Double
    public let channels: UInt32
    public let isFloat: Bool

    public init(sampleRate: Double, channels: UInt32, isFloat: Bool = true) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.isFloat = isFloat
    }

    /// Standard format for ML transcription: 16kHz mono Float32
    public static let mlTranscription = AudioFormatConfig(
        sampleRate: 16000,
        channels: 1,
        isFloat: true
    )

    /// Standard recording format: 44.1kHz mono Float32
    public static let recording = AudioFormatConfig(
        sampleRate: 44100,
        channels: 1,
        isFloat: true
    )
}

// MARK: - Audio Conversion

/// Errors that can occur during audio format conversion
public enum AudioConversionError: Error, Equatable, Sendable {
    case invalidInputFormat
    case conversionFailed
    case emptyInput
}

/// Converts audio data from one format to another
public enum AudioConverter {

    /// Converts Float32 PCM audio data to 16kHz mono Float32
    /// - Parameters:
    ///   - inputData: Raw Float32 PCM audio data
    ///   - inputSampleRate: Sample rate of the input audio
    ///   - inputChannels: Number of channels in the input audio
    /// - Returns: Converted Float32 PCM audio data at 16kHz mono
    public static func convertTo16kMonoFloat32(
        inputData: Data,
        inputSampleRate: Double,
        inputChannels: UInt32
    ) throws -> Data {
        guard !inputData.isEmpty else {
            throw AudioConversionError.emptyInput
        }

        // Parse input as Float32 samples
        let inputSamples = inputData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }

        guard !inputSamples.isEmpty else {
            throw AudioConversionError.invalidInputFormat
        }

        // Convert stereo to mono if needed
        let monoSamples: [Float]
        if inputChannels == 2 {
            monoSamples = stereoToMono(inputSamples)
        } else if inputChannels == 1 {
            monoSamples = inputSamples
        } else {
            throw AudioConversionError.invalidInputFormat
        }

        // Resample if needed
        let targetSampleRate: Double = 16000
        let resampledSamples: [Float]
        if abs(inputSampleRate - targetSampleRate) > 0.001 {
            resampledSamples = resample(
                samples: monoSamples,
                fromRate: inputSampleRate,
                toRate: targetSampleRate
            )
        } else {
            resampledSamples = monoSamples
        }

        // Convert back to Data
        return resampledSamples.withUnsafeBytes { buffer in
            Data(buffer)
        }
    }

    /// Converts stereo Float32 samples to mono by averaging channels
    private static func stereoToMono(_ stereoSamples: [Float]) -> [Float] {
        let frameCount = stereoSamples.count / 2
        var monoSamples = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            let left = stereoSamples[i * 2]
            let right = stereoSamples[i * 2 + 1]
            monoSamples[i] = (left + right) / 2.0
        }

        return monoSamples
    }

    /// Simple linear interpolation resampling
    /// For production, consider using vDSP or Accelerate for better quality
    private static func resample(
        samples: [Float],
        fromRate: Double,
        toRate: Double
    ) -> [Float] {
        guard !samples.isEmpty else { return [] }

        let ratio = fromRate / toRate
        let outputLength = Int(Double(samples.count) / ratio)

        guard outputLength > 0 else { return [] }

        var output = [Float](repeating: 0, count: outputLength)

        for i in 0..<outputLength {
            let inputIndex = Double(i) * ratio
            let index0 = Int(inputIndex)
            let index1 = min(index0 + 1, samples.count - 1)
            let fraction = Float(inputIndex - Double(index0))

            output[i] = samples[index0] * (1.0 - fraction) + samples[index1] * fraction
        }

        return output
    }
}
