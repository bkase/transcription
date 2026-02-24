import Testing
import FluidAudio
import Foundation

@Suite
struct DiarizationComparisonTest {

    static let audioURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Downloads/export-1067C856-9E7C-4FFC-AAAD-3684679384C6/audio.caf")

    static let transcriptURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Downloads/export-1067C856-9E7C-4FFC-AAAD-3684679384C6/transcript.json")

    static let modelsDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/FluidAudio/Models")

    @Test func exactSpeakers2Transcript() async throws {
        let config = OfflineDiarizerConfig.default.withSpeakers(exactly: 2)
        let manager = OfflineDiarizerManager(config: config)
        try await manager.prepareModels(directory: Self.modelsDir)
        let diarResult = try await manager.process(Self.audioURL)

        // Load transcript
        let data = try Data(contentsOf: Self.transcriptURL)
        let transcript = try JSONDecoder().decode(TranscriptFile.self, from: data)

        // For each transcript segment, find overlapping diarization segment with most overlap
        var lines: [String] = []
        var currentSpeaker: String? = nil
        var currentText: String = ""

        for seg in transcript.segments {
            let segStartSec = Float(seg.startMs) / 1000.0
            let segEndSec = Float(seg.endMs) / 1000.0

            // Find diarization segment with most overlap
            var bestSpeaker = "?"
            var bestOverlap: Float = 0
            for dSeg in diarResult.segments {
                let overlapStart = max(segStartSec, dSeg.startTimeSeconds)
                let overlapEnd = min(segEndSec, dSeg.endTimeSeconds)
                let overlap = max(0, overlapEnd - overlapStart)
                if overlap > bestOverlap {
                    bestOverlap = overlap
                    bestSpeaker = dSeg.speakerId
                }
            }

            if bestSpeaker == currentSpeaker {
                currentText += " " + seg.text
            } else {
                if !currentText.isEmpty {
                    lines.append("\(currentSpeaker ?? "?"): \(currentText)\n")
                }
                currentSpeaker = bestSpeaker
                currentText = seg.text
            }
        }
        if !currentText.isEmpty {
            lines.append("\(currentSpeaker ?? "?"): \(currentText)\n")
        }

        let output = lines.joined(separator: "\n")
        let outputURL = URL(fileURLWithPath: "/tmp/diarized_transcript.txt")
        try output.write(to: outputURL, atomically: true, encoding: .utf8)
        print("Wrote diarized transcript to \(outputURL.path)")
        print(output)
    }
}

private struct TranscriptFile: Decodable {
    let segments: [Segment]
    struct Segment: Decodable {
        let startMs: Int
        let endMs: Int
        let text: String
        let speakerId: String
    }
}
