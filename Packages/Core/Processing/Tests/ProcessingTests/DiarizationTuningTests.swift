import Testing
import Foundation
import FluidAudio
@testable import Processing

/// Diarization parameter tuning test — run on macOS for fast iteration.
/// Compare output against AssemblyAI ground truth.
///
/// Usage: cd Packages/Core/Processing && swift test --filter DiarizationTuningTests
@Suite(.serialized)
struct DiarizationTuningTests {

    // Path to the 103MB test audio file
    static let audioPath = URL(fileURLWithPath: "/Users/bkase/Documents/transcription2/App/Resources/test-diarization-audio.caf")
    // Path to AssemblyAI ground truth
    static let groundTruthPath = URL(fileURLWithPath: "/Users/bkase/Documents/transcription2/test-data/assemblyai-ground-truth.json")

    struct GroundTruthUtterance: Decodable {
        let speaker: String
        let start: Int  // ms
        let end: Int    // ms
        let text: String
    }

    /// Load AssemblyAI ground truth utterances
    static func loadGroundTruth() throws -> [GroundTruthUtterance] {
        let data = try Data(contentsOf: groundTruthPath)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let utterancesJSON = json["utterances"] as! [[String: Any]]
        return utterancesJSON.map { u in
            GroundTruthUtterance(
                speaker: u["speaker"] as! String,
                start: u["start"] as! Int,
                end: u["end"] as! Int,
                text: u["text"] as! String
            )
        }
    }

    /// Score diarization output against ground truth.
    /// Returns (correct_time_ms, total_time_ms, accuracy_pct)
    static func scoreDiarization(
        segments: [DiarizationMapping.SpeakerSegment],
        groundTruth: [GroundTruthUtterance]
    ) -> (correct: Int, total: Int, accuracy: Double) {
        // Map AssemblyAI speakers (A, B) to FluidAudio speakers (spk_0, spk_1) by majority overlap
        let fluidSpeakers = Set(segments.map(\.speakerId))
        let gtSpeakers = Set(groundTruth.map(\.speaker))

        guard fluidSpeakers.count >= 2, gtSpeakers.count >= 2 else {
            return (0, 0, 0)
        }

        // Try both mappings and pick the one with higher accuracy
        let gtList = Array(gtSpeakers.sorted())
        let fluidList = Array(fluidSpeakers.sorted())

        var bestCorrect = 0
        var bestTotal = 0

        // Generate all permutations of fluid speakers mapped to GT speakers
        let mappings: [[(String, String)]] = [
            Array(zip(gtList, fluidList)),
            Array(zip(gtList, fluidList.reversed())),
        ]

        for mapping in mappings {
            let speakerMap = Dictionary(uniqueKeysWithValues: mapping)  // GT -> Fluid
            var correct = 0
            var total = 0

            // For each 100ms window, check if the assigned speaker matches
            let totalDurationMs = max(
                groundTruth.map(\.end).max() ?? 0,
                Int(segments.map(\.endTimeSeconds).max().map { $0 * 1000 } ?? 0)
            )

            for windowStart in stride(from: 0, to: totalDurationMs, by: 100) {
                let windowEnd = windowStart + 100
                let windowMidS = Float(windowStart + 50) / 1000.0

                // Find GT speaker at this time
                let gtSpeaker = groundTruth.first { u in
                    windowStart >= u.start && windowStart < u.end
                }?.speaker

                // Find Fluid speaker at this time
                let fluidSpeaker = segments.first { s in
                    windowMidS >= s.startTimeSeconds && windowMidS < s.endTimeSeconds
                }?.speakerId

                guard let gt = gtSpeaker else { continue }  // skip silence in GT
                total += 100

                if let fluid = fluidSpeaker, speakerMap[gt] == fluid {
                    correct += 100
                }
            }

            if correct > bestCorrect {
                bestCorrect = correct
                bestTotal = total
            }
        }

        let accuracy = bestTotal > 0 ? Double(bestCorrect) / Double(bestTotal) * 100.0 : 0
        return (bestCorrect, bestTotal, accuracy)
    }

    /// Print segment distribution for debugging
    static func printDistribution(_ segments: [DiarizationMapping.SpeakerSegment]) {
        let bySpeaker = Dictionary(grouping: segments, by: \.speakerId)
        for (speaker, segs) in bySpeaker.sorted(by: { $0.key < $1.key }) {
            let totalDuration = segs.reduce(0.0) { $0 + $1.durationSeconds }
            print("  \(speaker): \(segs.count) segments, \(String(format: "%.1f", totalDuration))s total")
        }
    }

    /// Run diarization with given config and return segments
    static func runDiarization(config: OfflineDiarizerConfig) async throws -> [DiarizationMapping.SpeakerSegment] {
        let manager = OfflineDiarizerManager(config: config)
        try await manager.prepareModels()
        let result = try await manager.process(audioPath)
        return result.segments.map { seg in
            DiarizationMapping.SpeakerSegment(
                speakerId: seg.speakerId,
                startTimeSeconds: seg.startTimeSeconds,
                endTimeSeconds: seg.endTimeSeconds
            )
        }
    }

    // MARK: - Parameter Sweep

    @Test func tuneParameters() async throws {
        guard FileManager.default.fileExists(atPath: Self.audioPath.path) else {
            print("⚠️ Test audio not found, skipping")
            return
        }
        guard FileManager.default.fileExists(atPath: Self.groundTruthPath.path) else {
            print("⚠️ Ground truth not found, skipping")
            return
        }

        let groundTruth = try Self.loadGroundTruth()
        print("Ground truth: \(groundTruth.count) utterances")
        let gtBySpeaker = Dictionary(grouping: groundTruth, by: \.speaker)
        for (speaker, utts) in gtBySpeaker.sorted(by: { $0.key < $1.key }) {
            let totalMs = utts.reduce(0) { $0 + ($1.end - $1.start) }
            print("  GT \(speaker): \(utts.count) utterances, \(totalMs/1000)s")
        }

        // Parameter combinations to test
        struct ConfigSet {
            let name: String
            let stepRatio: Double
            let onsetThreshold: Float
            let offsetThreshold: Float
            let excludeOverlap: Bool
            let minSegmentDuration: Double
            let minGapDuration: Double
            let clusteringThreshold: Double
            let fa: Double
            let fb: Double
        }

        // Focused sweep around stepRatio 0.3 (best from round 1: 75.6%)
        var configs: [ConfigSet] = []

        // Fine-tune stepRatio around 0.3
        for step in [0.25, 0.28, 0.3, 0.32, 0.35, 0.4] {
            configs.append(ConfigSet(
                name: "step\(String(format: "%.2f", step))",
                stepRatio: step, onsetThreshold: 0.5, offsetThreshold: 0.5,
                excludeOverlap: true, minSegmentDuration: 1.0, minGapDuration: 0.1,
                clusteringThreshold: 0.6, fa: 0.07, fb: 0.8))
        }

        // stepRatio 0.3 + excludeOverlap variations
        for (exOvl, minSeg) in [(true, 0.5), (true, 1.0), (true, 1.5), (false, 0.5), (false, 1.0), (false, 1.5)] {
            configs.append(ConfigSet(
                name: "s3_ovl\(exOvl ? "T" : "F")_ms\(String(format: "%.1f", minSeg))",
                stepRatio: 0.3, onsetThreshold: 0.5, offsetThreshold: 0.5,
                excludeOverlap: exOvl, minSegmentDuration: minSeg, minGapDuration: 0.1,
                clusteringThreshold: 0.6, fa: 0.07, fb: 0.8))
        }

        // stepRatio 0.3 + clustering threshold variations
        for ct in [0.4, 0.5, 0.6, 0.7] {
            configs.append(ConfigSet(
                name: "s3_ct\(String(format: "%.1f", ct))",
                stepRatio: 0.3, onsetThreshold: 0.5, offsetThreshold: 0.5,
                excludeOverlap: true, minSegmentDuration: 1.0, minGapDuration: 0.1,
                clusteringThreshold: ct, fa: 0.07, fb: 0.8))
        }

        // stepRatio 0.3 + Fa variations
        for fa in [0.03, 0.07, 0.15, 0.30] {
            configs.append(ConfigSet(
                name: "s3_fa\(String(format: "%.2f", fa))",
                stepRatio: 0.3, onsetThreshold: 0.5, offsetThreshold: 0.5,
                excludeOverlap: true, minSegmentDuration: 1.0, minGapDuration: 0.1,
                clusteringThreshold: 0.6, fa: fa, fb: 0.8))
        }

        // stepRatio 0.3 + speech threshold variations
        for (on, off) in [(Float(0.3), Float(0.25)), (Float(0.4), Float(0.35)), (Float(0.5), Float(0.5)), (Float(0.6), Float(0.55))] {
            configs.append(ConfigSet(
                name: "s3_sp\(String(format: "%.1f", on))/\(String(format: "%.1f", off))",
                stepRatio: 0.3, onsetThreshold: on, offsetThreshold: off,
                excludeOverlap: true, minSegmentDuration: 1.0, minGapDuration: 0.1,
                clusteringThreshold: 0.6, fa: 0.07, fb: 0.8))
        }

        // Best combos: stepRatio 0.3 + excludeOverlap false + minSeg 1.0 + varying ct/fa
        for ct in [0.5, 0.6, 0.7] {
            for fa in [0.07, 0.15] {
                configs.append(ConfigSet(
                    name: "best_ct\(String(format: "%.1f", ct))_fa\(String(format: "%.2f", fa))",
                    stepRatio: 0.3, onsetThreshold: 0.5, offsetThreshold: 0.5,
                    excludeOverlap: false, minSegmentDuration: 1.0, minGapDuration: 0.1,
                    clusteringThreshold: ct, fa: fa, fb: 0.8))
            }
        }

        print("\n========== DIARIZATION PARAMETER SWEEP ==========\n")

        var results: [(name: String, accuracy: Double, segments: Int)] = []

        for c in configs {
            print("--- Config: \(c.name) ---")
            var config = OfflineDiarizerConfig.default
            config.segmentationStepRatio = c.stepRatio
            config.speechOnsetThreshold = c.onsetThreshold
            config.speechOffsetThreshold = c.offsetThreshold
            config.embeddingExcludeOverlap = c.excludeOverlap
            config.minSegmentDuration = c.minSegmentDuration
            config.minGapDuration = c.minGapDuration
            config.clusteringThreshold = c.clusteringThreshold
            config.Fa = c.fa
            config.Fb = c.fb
            config = config.withSpeakers(exactly: 2)

            let start = Date()
            let segments = try await Self.runDiarization(config: config)
            let elapsed = Date().timeIntervalSince(start)

            Self.printDistribution(segments)

            let (correct, total, accuracy) = Self.scoreDiarization(segments: segments, groundTruth: groundTruth)
            print("  Score: \(String(format: "%.1f", accuracy))% (\(correct/1000)s/\(total/1000)s correct)")
            print("  Time: \(String(format: "%.1f", elapsed))s")
            print()

            results.append((c.name, accuracy, segments.count))
        }

        print("\n========== RESULTS SUMMARY ==========\n")
        for r in results.sorted(by: { $0.accuracy > $1.accuracy }) {
            print("  \(String(format: "%6.1f%%", r.accuracy))  \(r.name) (\(r.segments) segments)")
        }
    }
}
