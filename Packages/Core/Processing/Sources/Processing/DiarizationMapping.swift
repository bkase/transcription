import Foundation

// MARK: - DiarizationMapping

/// Utilities for mapping diarization results to speaker tracks and segments.
/// These are extracted for testability without FluidAudio SDK dependency.
public enum DiarizationMapping {

    /// A speaker segment with timing information for dominant speaker calculation
    public struct SpeakerSegment: Sendable, Equatable {
        public let speakerId: String
        public let startTimeSeconds: Float
        public let endTimeSeconds: Float

        public init(speakerId: String, startTimeSeconds: Float, endTimeSeconds: Float) {
            self.speakerId = speakerId
            self.startTimeSeconds = startTimeSeconds
            self.endTimeSeconds = endTimeSeconds
        }

        public var durationSeconds: Float {
            max(0, endTimeSeconds - startTimeSeconds)
        }
    }

    /// Finds the dominant speaker in a set of speaker segments.
    /// The dominant speaker is the one with the longest total duration.
    /// - Parameter segments: The speaker segments to analyze
    /// - Returns: The speaker ID with the longest total duration, or nil if no segments
    public static func findDominantSpeaker(in segments: [SpeakerSegment]) -> String? {
        guard !segments.isEmpty else { return nil }

        var speakerDurations: [String: Float] = [:]

        for segment in segments {
            speakerDurations[segment.speakerId, default: 0] += segment.durationSeconds
        }

        return speakerDurations.max(by: { $0.value < $1.value })?.key
    }

    /// Maps speaker IDs to display orders based on discovery order.
    /// First speaker encountered gets order 1, second gets 2, etc.
    /// - Parameter speakerIds: The speaker IDs in order of discovery
    /// - Returns: A dictionary mapping speaker ID to display order
    public static func assignDisplayOrders(speakerIds: [String]) -> [String: Int] {
        var orders: [String: Int] = [:]
        var nextOrder = 1

        for speakerId in speakerIds {
            if orders[speakerId] == nil {
                orders[speakerId] = nextOrder
                nextOrder += 1
            }
        }

        return orders
    }
}
