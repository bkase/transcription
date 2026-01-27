import DesignSystem
import SwiftUI

/// Utilities for resolving speaker types during live recording.
public enum RecordingSpeakerRendering {

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
