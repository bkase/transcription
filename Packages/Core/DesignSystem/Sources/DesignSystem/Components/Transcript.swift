import SwiftUI

// MARK: - Speaker Type

/// Represents different speaker types in a transcript.
public enum SpeakerType: Sendable, Equatable {
    case user
    case guest
    case speaker(name: String, color: Color)

    /// Display label for the speaker
    public var label: String {
        switch self {
        case .user:
            return "YOU"
        case .guest:
            return "GUEST"
        case .speaker(let name, _):
            return name.uppercased()
        }
    }

    /// Color for the speaker label
    public var color: Color {
        switch self {
        case .user:
            return VaporColor.sky
        case .guest:
            return VaporColor.lavender
        case .speaker(_, let color):
            return color
        }
    }
}

// MARK: - Transcript Segment

/// A single segment of transcript with speaker label, timestamp, and text.
/// Used in session detail view to display transcript in script format.
public struct TranscriptSegment: View {
    private let speaker: SpeakerType
    private let timestamp: String
    private let text: String
    private let isActive: Bool
    private let onSpeakerTap: (() -> Void)?

    @State private var breatheScale: CGFloat = 0.98

    /// Create a transcript segment.
    /// - Parameters:
    ///   - speaker: The speaker type (user, guest, or custom)
    ///   - timestamp: Timestamp string (e.g., "00:12")
    ///   - text: The transcript text content
    ///   - isActive: Whether this segment is the currently active/speaking segment (applies breathing animation)
    ///   - onSpeakerTap: Optional callback when speaker label is tapped
    public init(
        speaker: SpeakerType,
        timestamp: String,
        text: String,
        isActive: Bool = false,
        onSpeakerTap: (() -> Void)? = nil
    ) {
        self.speaker = speaker
        self.timestamp = timestamp
        self.text = text
        self.isActive = isActive
        self.onSpeakerTap = onSpeakerTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header: speaker label + timestamp
            HStack(spacing: 12) {
                speakerLabel

                Text(timestamp)
                    .font(.system(size: 10, weight: .light))
                    .tracking(0.5)
                    .foregroundColor(VaporColor.overcast)
            }

            // Transcript text
            Text(text)
                .font(.system(size: 16, weight: .light))
                .lineSpacing(6)
                .foregroundColor(VaporColor.textPrimary)
        }
        .scaleEffect(isActive ? breatheScale : 1.0)
        .accessibilityIdentifier("transcriptSegment")
        .onAppear {
            if isActive {
                startBreathingAnimation()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startBreathingAnimation()
            } else {
                breatheScale = 1.0
            }
        }
    }

    private func startBreathingAnimation() {
        breatheScale = 0.98
        withAnimation(
            VaporAnimation.breatheCurve.animation(duration: VaporAnimation.breatheDuration)
                .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.02
        }
    }

    @ViewBuilder
    private var speakerLabel: some View {
        if let onTap = onSpeakerTap {
            Button(action: onTap) {
                Text(speaker.label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(speaker.color)
            }
            .buttonStyle(SpeakerLabelButtonStyle())
            .accessibilityIdentifier("speakerLabel")
        } else {
            speakerLabelContent
        }
    }

    private var speakerLabelContent: some View {
        Text(speaker.label)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundColor(speaker.color)
    }
}

// MARK: - Speaker Label Button Style

/// Custom button style for speaker labels that preserves the text appearance
private struct SpeakerLabelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(
                VaporAnimation.appearCurve.animation(duration: VaporAnimation.microDuration),
                value: configuration.isPressed
            )
    }
}

// MARK: - Transcript Segment Preview (for snapshots)

/// Non-interactive preview variant of TranscriptSegment for snapshot testing.
public struct TranscriptSegmentPreview: View {
    private let speaker: SpeakerType
    private let timestamp: String
    private let text: String
    private let isActive: Bool

    public init(
        speaker: SpeakerType,
        timestamp: String,
        text: String,
        isActive: Bool = false
    ) {
        self.speaker = speaker
        self.timestamp = timestamp
        self.text = text
        self.isActive = isActive
    }

    public var body: some View {
        TranscriptSegment(
            speaker: speaker,
            timestamp: timestamp,
            text: text,
            isActive: isActive
        )
    }
}

// MARK: - Live Indicator

/// Indicator shown at the end of live transcript during recording.
/// Displays "Listening..." with a subtle animation effect.
public struct TranscriptLiveIndicator: View {
    public init() {}

    public var body: some View {
        HStack {
            Spacer()
            Text("Listening...")
                .font(.system(size: 14, weight: .light))
                .italic()
                .foregroundColor(VaporColor.textTertiary)
                .opacity(0.4)
            Spacer()
        }
        .padding(.vertical, 20)
    }
}

// MARK: - End of Session Indicator

/// Indicator shown at the end of a completed session transcript.
public struct TranscriptEndIndicator: View {
    public init() {}

    public var body: some View {
        HStack {
            Spacer()
            Text("END OF SESSION")
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundColor(VaporColor.textTertiary)
                .opacity(0.6)
            Spacer()
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Previews

#if DEBUG
struct TranscriptSegment_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            // User segment
            TranscriptSegment(
                speaker: .user,
                timestamp: "00:12",
                text: "So we're looking at the Vapor direction."
            )

            // Guest segment
            TranscriptSegment(
                speaker: .guest,
                timestamp: "00:18",
                text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
            )

            // Another user segment
            TranscriptSegment(
                speaker: .user,
                timestamp: "00:35",
                text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
            )

            // Live indicator
            TranscriptLiveIndicator()

            // End indicator
            TranscriptEndIndicator()
        }
        .padding(24)
        .background(VaporColor.cloud)
    }
}
#endif
