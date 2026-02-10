/// Controls what data is retained after recording
public enum AudioRetentionMode: String, Codable, Sendable, CaseIterable {
    /// Keep transcript only, delete audio after transcription
    case transcriptOnly
    /// Keep audio only, no transcription
    case audioOnly
    /// Keep both audio and transcript (default)
    case both
}
