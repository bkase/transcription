import SwiftUI

// MARK: - Session Card

/// Card component for displaying session preview on timeline.
/// Shows title, time, preview text, and optional metadata badges on hover.
public struct SessionCard: View {
    private let title: String
    private let time: String
    private let previewText: String
    private let speakerCount: Int?
    private let duration: String?
    private let showMetadata: Bool
    private let statusPillType: StatusPillType?
    private let speakerAvatars: [SpeakerAvatarInfo]

    /// Create a session card.
    /// - Parameters:
    ///   - title: Session title (e.g., "Architecture Review")
    ///   - time: Time string (e.g., "9:41 AM")
    ///   - previewText: Preview of the transcript content
    ///   - speakerCount: Number of speakers for metadata badge (nil to hide)
    ///   - duration: Duration string for metadata badge (nil to hide)
    ///   - showMetadata: Whether to show metadata badges (hover state)
    ///   - statusPillType: Optional status pill to display processing state
    ///   - speakerAvatars: Array of speaker avatar info for displaying overlapping circles
    public init(
        title: String,
        time: String,
        previewText: String,
        speakerCount: Int? = nil,
        duration: String? = nil,
        showMetadata: Bool = false,
        statusPillType: StatusPillType? = nil,
        speakerAvatars: [SpeakerAvatarInfo] = []
    ) {
        self.title = title
        self.time = time
        self.previewText = previewText
        self.speakerCount = speakerCount
        self.duration = duration
        self.showMetadata = showMetadata
        self.statusPillType = statusPillType
        self.speakerAvatars = speakerAvatars
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: showMetadata ? 12 : 8) {
            // Header: speaker avatars + title + time + optional status
            HStack(spacing: VaporSpacing.sm) {
                // Speaker avatars (left side)
                if !speakerAvatars.isEmpty {
                    SpeakerAvatarStack(speakers: speakerAvatars)
                }

                Text(title)
                    .font(.system(size: 18, weight: .light))
                    .tracking(-0.2)
                    .foregroundColor(VaporColor.textPrimary)

                Spacer()

                // Status pill (when processing state is notable)
                if let pillType = statusPillType {
                    StatusPill(type: pillType)
                }

                Text(time)
                    .font(.system(size: 10))
                    .tracking(0.5)
                    .foregroundColor(VaporColor.textTertiary)
            }

            // Preview text
            Text(previewText)
                .font(.system(size: 14, weight: .light))
                .lineSpacing(4)
                .foregroundColor(VaporColor.textSecondary)
                .opacity(showMetadata ? 1.0 : 0.8)
                .lineLimit(2)

            // Metadata badges (shown in hover state)
            if showMetadata {
                HStack(spacing: 6) {
                    if let count = speakerCount {
                        SpeakerBadge(count: count)
                    }
                    if let dur = duration {
                        DurationBadge(durationText: dur)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("sessionCard")
        .accessibilityLabel("\(title), \(time)")
        .background(
            Group {
                if showMetadata {
                    RoundedRectangle(cornerRadius: VaporRadius.md)
                        .fill(VaporColor.cloud)
                        .shadow(
                            color: VaporColor.sky.opacity(0.1),
                            radius: 16,
                            y: 12
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: VaporRadius.md)
                                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                        )
                } else {
                    Color.clear
                }
            }
        )
    }
}

// MARK: - Session Card Preview (for snapshots)

/// Non-interactive preview variant of SessionCard for snapshot testing.
public struct SessionCardPreview: View {
    private let title: String
    private let time: String
    private let previewText: String
    private let speakerCount: Int?
    private let duration: String?
    private let showMetadata: Bool
    private let statusPillType: StatusPillType?
    private let speakerAvatars: [SpeakerAvatarInfo]

    public init(
        title: String,
        time: String,
        previewText: String,
        speakerCount: Int? = nil,
        duration: String? = nil,
        showMetadata: Bool = false,
        statusPillType: StatusPillType? = nil,
        speakerAvatars: [SpeakerAvatarInfo] = []
    ) {
        self.title = title
        self.time = time
        self.previewText = previewText
        self.speakerCount = speakerCount
        self.duration = duration
        self.showMetadata = showMetadata
        self.statusPillType = statusPillType
        self.speakerAvatars = speakerAvatars
    }

    public var body: some View {
        SessionCard(
            title: title,
            time: time,
            previewText: previewText,
            speakerCount: speakerCount,
            duration: duration,
            showMetadata: showMetadata,
            statusPillType: statusPillType,
            speakerAvatars: speakerAvatars
        )
    }
}

// MARK: - Previews

#if DEBUG
struct SessionCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            // Default state
            SessionCard(
                title: "Architecture Review",
                time: "9:41 AM",
                previewText: "So we're looking at the Vapor direction..."
            )

            // Hover state with metadata
            SessionCard(
                title: "Architecture Review",
                time: "9:41 AM",
                previewText: "So we're looking at the Vapor direction...",
                speakerCount: 2,
                duration: "42:10",
                showMetadata: true
            )

            // Another example
            SessionCard(
                title: "Morning Reflection",
                time: "7:30 AM",
                previewText: "The light in the studio was particularly interesting this morning..."
            )
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}
#endif
