import Foundation
import Dependencies
import DependenciesMacros

#if os(iOS)
import UIKit
import AVFoundation
#endif

/// Client for audio and haptic feedback during recording lifecycle
@DependencyClient
public struct FeedbackClient: Sendable {
    /// Play the recording start sound (soft rising tone C5→E5)
    public var playStartSound: @Sendable () async -> Void
    /// Play the recording stop sound (gentle falling tone E5→C5)
    public var playStopSound: @Sendable () async -> Void
    /// Trigger haptic feedback for recording start (soft tap)
    public var triggerStartHaptic: @Sendable () async -> Void
    /// Trigger haptic feedback for recording stop (soft tap)
    public var triggerStopHaptic: @Sendable () async -> Void
}

#if os(iOS)
/// Actor managing audio tone generation for feedback sounds
private actor ToneGenerator {
    private var audioEngine: AVAudioEngine?
    private var toneNode: AVAudioSourceNode?

    /// Play a sine wave tone sweep from startFreq to endFreq over duration
    func playSineTone(startFreq: Float, endFreq: Float, duration: TimeInterval, volume: Float) async {
        let sampleRate: Float = 44100
        let totalSamples = Int(sampleRate * Float(duration))
        var currentSample = 0
        var phase: Float = 0

        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                if currentSample >= totalSamples {
                    // Fill with silence
                    for buffer in ablPointer {
                        let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                        buf?[frame] = 0
                    }
                    continue
                }

                // Linear interpolation of frequency
                let progress = Float(currentSample) / Float(totalSamples)
                let currentFreq = startFreq + (endFreq - startFreq) * progress

                // Generate sine wave
                let value = sinf(phase * 2.0 * Float.pi) * volume

                // Apply envelope (fade in/out)
                let envelope: Float
                let fadeLength = 0.1 // 10% fade
                if progress < Float(fadeLength) {
                    envelope = progress / Float(fadeLength)
                } else if progress > Float(1.0 - fadeLength) {
                    envelope = (1.0 - progress) / Float(fadeLength)
                } else {
                    envelope = 1.0
                }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = value * envelope
                }

                phase += currentFreq / sampleRate
                if phase >= 1.0 { phase -= 1.0 }
                currentSample += 1
            }

            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            self.audioEngine = engine
            self.toneNode = sourceNode

            // Wait for tone to complete
            try await Task.sleep(for: .milliseconds(Int(duration * 1000) + 50))

            engine.stop()
            self.audioEngine = nil
            self.toneNode = nil
        } catch {
            // Silently fail - feedback is non-critical
        }
    }

    /// Play a triangle wave tone sweep from startFreq to endFreq over duration
    func playTriangleTone(startFreq: Float, endFreq: Float, duration: TimeInterval, volume: Float) async {
        let sampleRate: Float = 44100
        let totalSamples = Int(sampleRate * Float(duration))
        var currentSample = 0
        var phase: Float = 0

        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                if currentSample >= totalSamples {
                    for buffer in ablPointer {
                        let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                        buf?[frame] = 0
                    }
                    continue
                }

                let progress = Float(currentSample) / Float(totalSamples)
                let currentFreq = startFreq + (endFreq - startFreq) * progress

                // Generate triangle wave
                let value = (2.0 * abs(2.0 * phase - 1.0) - 1.0) * volume

                // Apply envelope
                let envelope: Float
                let fadeLength = 0.1
                if progress < Float(fadeLength) {
                    envelope = progress / Float(fadeLength)
                } else if progress > Float(1.0 - fadeLength) {
                    envelope = (1.0 - progress) / Float(fadeLength)
                } else {
                    envelope = 1.0
                }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = value * envelope
                }

                phase += currentFreq / sampleRate
                if phase >= 1.0 { phase -= 1.0 }
                currentSample += 1
            }

            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            self.audioEngine = engine
            self.toneNode = sourceNode

            try await Task.sleep(for: .milliseconds(Int(duration * 1000) + 50))

            engine.stop()
            self.audioEngine = nil
            self.toneNode = nil
        } catch {
            // Silently fail
        }
    }
}

/// Actor managing haptic feedback generation
private actor HapticGenerator {
    private var impactGenerator: UIImpactFeedbackGenerator?

    func triggerSoftTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
}
#endif

extension FeedbackClient: DependencyKey {
    public static let liveValue: Self = {
        #if os(iOS)
        let toneGenerator = ToneGenerator()
        let hapticGenerator = HapticGenerator()

        // Note frequencies: C5 ≈ 523.25 Hz, E5 ≈ 659.25 Hz
        let c5: Float = 523.25
        let e5: Float = 659.25

        // Volume levels from brand.md: -18dB ≈ 0.126, -20dB ≈ 0.1
        let startVolume: Float = 0.126
        let stopVolume: Float = 0.1

        return Self(
            playStartSound: {
                await toneGenerator.playSineTone(
                    startFreq: c5,
                    endFreq: e5,
                    duration: 0.2, // 200ms
                    volume: startVolume
                )
            },
            playStopSound: {
                await toneGenerator.playTriangleTone(
                    startFreq: e5,
                    endFreq: c5,
                    duration: 0.3, // 300ms
                    volume: stopVolume
                )
            },
            triggerStartHaptic: {
                await hapticGenerator.triggerSoftTap()
            },
            triggerStopHaptic: {
                await hapticGenerator.triggerSoftTap()
            }
        )
        #else
        // macOS fallback - no haptics, no sounds
        return Self(
            playStartSound: { },
            playStopSound: { },
            triggerStartHaptic: { },
            triggerStopHaptic: { }
        )
        #endif
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var feedbackClient: FeedbackClient {
        get { self[FeedbackClient.self] }
        set { self[FeedbackClient.self] = newValue }
    }
}
