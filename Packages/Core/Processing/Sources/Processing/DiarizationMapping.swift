import Foundation

// MARK: - DiarizationMapping

/// Utilities for mapping diarization results to speaker tracks and segments.
/// These are extracted for testability without FluidAudio SDK dependency.
///
/// ## Mapping Algorithm
///
/// The core mapping assigns a speaker to each transcript segment by computing
/// overlap between the transcript interval and all diarization speaker segments.
/// The speaker with the greatest total overlap duration wins.
///
/// ### Tie-breaking
/// When two or more speakers have exactly equal overlap with a transcript segment,
/// the speaker whose ID is lexicographically smallest is chosen. This ensures
/// deterministic, reproducible results across runs.
///
/// ### No-overlap fallback
/// When a transcript segment has zero overlap with every speaker segment, the
/// assigned speaker is `nil`. Callers decide how to handle this (e.g. keep the
/// segment unlabeled, assign nearest speaker, etc.).
///
/// ### Display order
/// Speaker display order is assigned by first appearance in transcript order:
/// the first speaker assigned to any segment gets order 1, the next new speaker
/// gets order 2, etc. This is stable for the same input.
public enum DiarizationMapping {

    // MARK: - Types

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

    /// A transcript interval to be mapped to a speaker.
    /// Generic over an ID type so callers can use their own identifier.
    public struct TranscriptInterval<ID: Hashable & Sendable>: Sendable, Equatable where ID: Equatable {
        public let id: ID
        public let startTimeSeconds: Float
        public let endTimeSeconds: Float

        public init(id: ID, startTimeSeconds: Float, endTimeSeconds: Float) {
            self.id = id
            self.startTimeSeconds = startTimeSeconds
            self.endTimeSeconds = endTimeSeconds
        }
    }

    /// The result of mapping a single transcript interval to a speaker.
    public struct SpeakerAssignment<ID: Hashable & Sendable>: Sendable, Equatable where ID: Equatable {
        /// The transcript interval ID this assignment is for.
        public let intervalId: ID
        /// The assigned speaker ID, or `nil` if no speaker segment overlapped.
        public let speakerId: String?
        /// Total overlap duration in seconds between the interval and the assigned speaker.
        /// Zero when `speakerId` is nil.
        public let overlapSeconds: Float

        public init(intervalId: ID, speakerId: String?, overlapSeconds: Float) {
            self.intervalId = intervalId
            self.speakerId = speakerId
            self.overlapSeconds = overlapSeconds
        }
    }

    /// Full result of mapping transcript intervals to speakers.
    public struct MappingResult<ID: Hashable & Sendable>: Sendable, Equatable where ID: Equatable {
        /// One assignment per input transcript interval, in the same order.
        public let assignments: [SpeakerAssignment<ID>]
        /// Speaker display orders keyed by speaker ID, assigned by first appearance
        /// in transcript order (1-based).
        public let displayOrders: [String: Int]

        public init(assignments: [SpeakerAssignment<ID>], displayOrders: [String: Int]) {
            self.assignments = assignments
            self.displayOrders = displayOrders
        }
    }

    // MARK: - Mapping API

    /// Maps transcript intervals to speakers using overlap-based assignment.
    ///
    /// For each transcript interval, computes the total overlap duration with every
    /// speaker segment. The speaker with the greatest overlap wins. Ties are broken
    /// by lexicographic order of speaker ID (smallest wins). Intervals with zero
    /// overlap get `speakerId = nil`.
    ///
    /// Display orders are assigned by first-appearance order across the resulting
    /// assignments (only non-nil speakers are counted).
    ///
    /// - Parameters:
    ///   - intervals: Transcript intervals to assign speakers to, in presentation order.
    ///   - speakerSegments: Diarization speaker segments (may be unsorted).
    /// - Returns: A `MappingResult` with one assignment per interval and display orders.
    public static func mapSpeakers<ID>(
        intervals: [TranscriptInterval<ID>],
        speakerSegments: [SpeakerSegment]
    ) -> MappingResult<ID> {
        var assignments: [SpeakerAssignment<ID>] = []
        assignments.reserveCapacity(intervals.count)

        for interval in intervals {
            let assignment = assignSpeaker(to: interval, from: speakerSegments)
            assignments.append(assignment)
        }

        // Build display orders from first-appearance in assignment order
        let speakerSequence = assignments.compactMap(\.speakerId)
        let displayOrders = assignDisplayOrders(speakerIds: speakerSequence)

        return MappingResult(assignments: assignments, displayOrders: displayOrders)
    }

    /// Assigns a single speaker to a transcript interval based on overlap.
    ///
    /// - Parameters:
    ///   - interval: The transcript interval.
    ///   - speakerSegments: All diarization speaker segments.
    /// - Returns: A `SpeakerAssignment` for the interval.
    public static func assignSpeaker<ID>(
        to interval: TranscriptInterval<ID>,
        from speakerSegments: [SpeakerSegment]
    ) -> SpeakerAssignment<ID> {
        // Accumulate total overlap per speaker
        var overlapBySpeaker: [String: Float] = [:]

        for segment in speakerSegments {
            let overlap = computeOverlap(
                aStart: interval.startTimeSeconds, aEnd: interval.endTimeSeconds,
                bStart: segment.startTimeSeconds, bEnd: segment.endTimeSeconds
            )
            if overlap > 0 {
                overlapBySpeaker[segment.speakerId, default: 0] += overlap
            }
        }

        guard !overlapBySpeaker.isEmpty else {
            return SpeakerAssignment(intervalId: interval.id, speakerId: nil, overlapSeconds: 0)
        }

        // Find maximum overlap, breaking ties by lexicographic speaker ID
        let best = overlapBySpeaker
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value  // higher overlap first
                }
                return lhs.key < rhs.key  // lexicographic tie-break
            }
            .first!

        return SpeakerAssignment(
            intervalId: interval.id,
            speakerId: best.key,
            overlapSeconds: best.value
        )
    }

    // MARK: - Overlap Computation

    /// Computes the overlap duration in seconds between two time intervals.
    /// Returns 0 if the intervals do not overlap.
    public static func computeOverlap(
        aStart: Float, aEnd: Float,
        bStart: Float, bEnd: Float
    ) -> Float {
        let overlapStart = max(aStart, bStart)
        let overlapEnd = min(aEnd, bEnd)
        return max(0, overlapEnd - overlapStart)
    }

    // MARK: - Existing Helpers

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

        // Use same tie-breaking as mapSpeakers: lexicographic order on equal duration
        return speakerDurations
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
            .first?.key
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
