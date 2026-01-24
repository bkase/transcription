import Tagged

// MARK: - Typed IDs

public enum SessionIDTag {}
public typealias SessionID = Tagged<SessionIDTag, String>

public enum PersonIDTag {}
public typealias PersonID = Tagged<PersonIDTag, String>

public enum SpeakerTrackIDTag {}
public typealias SpeakerTrackID = Tagged<SpeakerTrackIDTag, String>

public enum TranscriptSegmentIDTag {}
public typealias TranscriptSegmentID = Tagged<TranscriptSegmentIDTag, String>

// MARK: - Time Types

public struct Milliseconds: Sendable, Equatable, Codable, Hashable, Comparable {
    public let rawValue: Int

    public init(_ value: Int) {
        self.rawValue = value
    }

    public static func < (lhs: Milliseconds, rhs: Milliseconds) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TimeRangeMs: Sendable, Equatable, Codable, Hashable {
    public let start: Milliseconds
    public let end: Milliseconds

    public init?(start: Milliseconds, end: Milliseconds) {
        guard start < end else { return nil }
        self.start = start
        self.end = end
    }

    public var durationMs: Milliseconds {
        Milliseconds(end.rawValue - start.rawValue)
    }
}

// MARK: - Speaker ID Wrapper

public struct MachineSpeakerID: Sendable, Equatable, Codable, Hashable {
    public let rawValue: String

    public init?(_ value: String) {
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }
}
