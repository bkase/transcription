import SwiftUI

// MARK: - Speaker Badge

/// Badge showing speaker count with colored dots.
/// Dots use speaker colors (sky, lavender, etc.) to represent different speakers.
public struct SpeakerBadge: View {
    private let count: Int
    private let colors: [Color]

    /// Default speaker colors used when not explicitly provided
    private static let defaultColors: [Color] = [
        VaporColor.sky,
        VaporColor.lavender,
        VaporColor.deep,
        VaporColor.dusk
    ]

    public init(count: Int, colors: [Color]? = nil) {
        self.count = max(1, count)
        self.colors = colors ?? Array(Self.defaultColors.prefix(self.count))
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Speaker dots
            HStack(spacing: 3) {
                ForEach(0..<min(count, 4), id: \.self) { index in
                    Circle()
                        .fill(colors.indices.contains(index) ? colors[index] : VaporColor.sky)
                        .opacity(0.6)
                        .frame(width: 6, height: 6)
                }
            }

            // Count text
            Text("\(count)")
                .font(.system(size: 11, weight: .light))
                .tracking(0.5)
                .foregroundColor(VaporColor.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VaporColor.haze.opacity(0.8))
        )
    }
}

// MARK: - Duration Badge

/// Badge showing duration in HH:MM or MM:SS format.
public struct DurationBadge: View {
    private let durationText: String

    public init(durationText: String) {
        self.durationText = durationText
    }

    /// Create a duration badge from milliseconds
    public init(milliseconds: Int) {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let hours = minutes / 60

        if hours > 0 {
            self.durationText = String(format: "%d:%02d:%02d", hours, minutes % 60, seconds)
        } else {
            self.durationText = String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Create a duration badge from seconds
    public init(seconds: Int) {
        self.init(milliseconds: seconds * 1000)
    }

    public var body: some View {
        Text(durationText)
            .font(.system(size: 11, weight: .light))
            .tracking(0.5)
            .foregroundColor(VaporColor.textSecondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(VaporColor.haze.opacity(0.8))
            )
    }
}

// MARK: - Session Badges Container

/// Container for session metadata badges (speaker count + duration).
public struct SessionBadges: View {
    private let speakerCount: Int
    private let durationText: String?
    private let speakerColors: [Color]?

    public init(speakerCount: Int, durationText: String? = nil, speakerColors: [Color]? = nil) {
        self.speakerCount = speakerCount
        self.durationText = durationText
        self.speakerColors = speakerColors
    }

    public init(speakerCount: Int, durationMilliseconds: Int, speakerColors: [Color]? = nil) {
        self.speakerCount = speakerCount
        self.speakerColors = speakerColors

        let totalSeconds = durationMilliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let hours = minutes / 60

        if hours > 0 {
            self.durationText = String(format: "%d:%02d:%02d", hours, minutes % 60, seconds)
        } else {
            self.durationText = String(format: "%d:%02d", minutes, seconds)
        }
    }

    public var body: some View {
        HStack(spacing: 6) {
            SpeakerBadge(count: speakerCount, colors: speakerColors)

            if let duration = durationText {
                DurationBadge(durationText: duration)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct SpeakerBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SpeakerBadge(count: 1)
            SpeakerBadge(count: 2)
            SpeakerBadge(count: 3)
            SpeakerBadge(count: 4)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct DurationBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            DurationBadge(durationText: "5:30")
            DurationBadge(durationText: "42:10")
            DurationBadge(durationText: "1:30:45")
            DurationBadge(milliseconds: 153000)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct SessionBadges_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SessionBadges(speakerCount: 2, durationText: "42:10")
            SessionBadges(speakerCount: 3, durationMilliseconds: 5430000)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}
#endif
