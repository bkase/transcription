import DesignSystem
import SwiftUI

/// Utilities for formatting transcript segments for display.
/// These functions handle speaker label mapping and timestamp formatting.
public enum TranscriptRendering {

    // MARK: - Timestamp Formatting

    /// Format milliseconds as MM:SS timestamp string.
    /// - Parameter milliseconds: Time in milliseconds
    /// - Returns: Formatted string like "00:12" or "05:30"
    public static func formatTimestamp(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Speaker Type Resolution

    /// Determine the speaker type for a segment based on speaker tracks.
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
    ///   - segment: The transcript segment to resolve
    ///   - speakerTracks: Available speaker tracks for the session
    /// - Returns: The appropriate SpeakerType for display
    public static func speakerType(
        for segment: DetailSegment,
        speakerTracks: [DetailSpeakerTrack]
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
