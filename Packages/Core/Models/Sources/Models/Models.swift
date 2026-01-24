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
