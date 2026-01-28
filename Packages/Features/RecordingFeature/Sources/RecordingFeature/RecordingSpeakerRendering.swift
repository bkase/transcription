import DesignSystem
import SwiftUI

/// Utilities for resolving speaker types during live recording.
public enum RecordingSpeakerRendering {

    // MARK: - Segment Merging

    /// Default max characters for segment merging (approximately half screen height at typical font size).
    /// This allows for roughly 10-15 lines of text before splitting.
    public static let defaultMaxCharacters: Int = 600

    /// Merge consecutive live transcript segments from the same speaker for cleaner display.
    ///
    /// Rules:
    /// - Consecutive segments with the same `machineSpeakerId` are merged
    /// - Segments are split when combined text would exceed `maxCharacters`
    /// - Segments with nil `machineSpeakerId` are never merged (unknown speakers)
    /// - Merged segments use the earliest `startMs` and latest `endMs`
    /// - Merged segments use the first segment's `id`
    /// - For live recording, the `isFinal` flag is taken from the last merged segment
    ///
    /// - Parameters:
    ///   - segments: The live transcript segments to merge
    ///   - maxCharacters: Maximum character length before splitting (default 600)
    /// - Returns: Array of merged segments
    public static func mergeConsecutiveSegments(
        _ segments: [LiveSegment],
        maxCharacters: Int = defaultMaxCharacters
    ) -> [LiveSegment] {
        guard !segments.isEmpty else { return [] }

        var result: [LiveSegment] = []
        var currentMerge: LiveSegment? = nil

        for segment in segments {
            // Never merge segments with nil machineSpeakerId
            guard let segmentSpeakerId = segment.machineSpeakerId else {
                // Flush any pending merge
                if let pending = currentMerge {
                    result.append(pending)
                    currentMerge = nil
                }
                result.append(segment)
                continue
            }

            if let current = currentMerge,
               let currentSpeakerId = current.machineSpeakerId,
               currentSpeakerId == segmentSpeakerId {
                // Same speaker - try to merge
                let combinedText = current.text + " " + segment.text

                if combinedText.count <= maxCharacters {
                    // Merge: combine text, extend endMs, use latest isFinal
                    currentMerge = LiveSegment(
                        id: current.id,
                        machineSpeakerId: current.machineSpeakerId,
                        startMs: current.startMs,
                        endMs: segment.endMs,
                        text: combinedText,
                        isFinal: segment.isFinal
                    )
                } else {
                    // Would exceed max - emit current and start new merge
                    result.append(current)
                    currentMerge = segment
                }
            } else {
                // Different speaker - flush pending and start new merge
                if let pending = currentMerge {
                    result.append(pending)
                }
                currentMerge = segment
            }
        }

        // Flush any remaining merge
        if let pending = currentMerge {
            result.append(pending)
        }

        return result
    }

    // MARK: - Speaker Type Resolution

    /// Determine the speaker type for a live segment based on speaker tracks.
    ///
    /// Resolution logic:
    /// 1. If segment has no machineSpeakerId → `.unassigned(displayOrder: 1, color:)` (default to Speaker 1)
    /// 2. If segment's machineSpeakerId matches a track with personName → `.speaker(name:color:)`
    /// 3. If track exists but no personName → `.unassigned(displayOrder:color:)` using track's displayOrder
    /// 4. If no matching track found → `.unassigned(displayOrder: 1, color:)` (default)
    ///
    /// - Parameters:
    ///   - segment: The live transcript segment to resolve
    ///   - speakerTracks: Available speaker tracks for the session
    /// - Returns: The appropriate SpeakerType for display
    public static func speakerType(
        for segment: LiveSegment,
        speakerTracks: [LiveSpeakerTrack]
    ) -> SpeakerType {
        guard let machineSpeakerId = segment.machineSpeakerId else {
            // Unknown speaker - default to Speaker 1
            return .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
        }

        // Find the speaker track for this segment
        if let track = speakerTracks.first(where: { $0.machineSpeakerId == machineSpeakerId }) {
            let color = SpeakerColor.forIndex(track.displayOrder - 1).color
            if let personName = track.personName {
                return .speaker(name: personName, color: color)
            } else {
                // Unassigned speaker with display order
                return .unassigned(displayOrder: track.displayOrder, color: color)
            }
        }

        // No matching track - default to Speaker 1
        return .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
    }
}
