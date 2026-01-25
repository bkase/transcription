import DesignSystem
import SwiftUI

/// Utilities for resolving speaker types during live recording.
public enum RecordingSpeakerRendering {

    /// Determine the speaker type for a live segment based on speaker tracks.
    ///
    /// Resolution logic:
    /// 1. If segment has no machineSpeakerId → `.guest`
    /// 2. If segment's machineSpeakerId matches a track with personName → `.speaker(name:color:)`
    /// 3. If track exists but no personName:
    ///    - displayOrder == 1 → `.user` (primary speaker)
    ///    - otherwise → `.guest`
    /// 4. If no matching track found → `.guest`
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
            return .guest
        }

        // Find the speaker track for this segment
        if let track = speakerTracks.first(where: { $0.machineSpeakerId == machineSpeakerId }) {
            if let personName = track.personName {
                let color = SpeakerColor.forIndex(track.displayOrder - 1).color
                return .speaker(name: personName, color: color)
            } else {
                // For unassigned speakers, use displayOrder to label
                if track.displayOrder == 1 {
                    return .user
                } else {
                    return .guest
                }
            }
        }

        return .guest
    }
}
