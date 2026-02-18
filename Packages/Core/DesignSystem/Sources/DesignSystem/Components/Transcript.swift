import SwiftUI

// MARK: - Speaker Type

/// Represents different speaker types in a transcript.
public enum SpeakerType: Sendable, Equatable {
    /// Unassigned speaker with display order and color
    case unassigned(displayOrder: Int, color: Color)
    /// Assigned speaker with name and color
    case speaker(name: String, color: Color)

    /// Display label for the speaker
    public var label: String {
        switch self {
        case .unassigned(let displayOrder, _):
            return "Speaker \(displayOrder)"
        case .speaker(let name, _):
            return name.uppercased()
        }
    }

    /// Color for the speaker label
    public var color: Color {
        switch self {
        case .unassigned(_, let color):
            return color
        case .speaker(_, let color):
            return color
        }
    }

    /// Whether this speaker is unassigned
    public var isUnassigned: Bool {
        switch self {
        case .unassigned:
            return true
        case .speaker:
            return false
        }
    }
}

// MARK: - Transcript Segment

/// A single segment of transcript with speaker label, timestamp, and text.
/// Used in session detail view to display transcript in script format.
public struct TranscriptSegment: View {
    private let speaker: SpeakerType?
    private let timestamp: String
    private let text: String
    private let isActive: Bool
    private let animateTextReveal: Bool
    private let onSpeakerTap: (() -> Void)?

    /// Create a transcript segment.
    /// - Parameters:
    ///   - speaker: The speaker type, or nil to hide the speaker label entirely
    ///   - timestamp: Timestamp string (e.g., "00:12")
    ///   - text: The transcript text content
    ///   - isActive: Whether this segment is the currently active/speaking segment
    ///   - animateTextReveal: Whether to animate the text reveal with staggered word blur effect (default false)
    ///   - onSpeakerTap: Optional callback when speaker label is tapped
    public init(
        speaker: SpeakerType? = nil,
        timestamp: String,
        text: String,
        isActive: Bool = false,
        animateTextReveal: Bool = false,
        onSpeakerTap: (() -> Void)? = nil
    ) {
        self.speaker = speaker
        self.timestamp = timestamp
        self.text = text
        self.isActive = isActive
        self.animateTextReveal = animateTextReveal
        self.onSpeakerTap = onSpeakerTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header: speaker label on left, timestamp on right
            HStack(spacing: 12) {
                if let speaker {
                    speakerLabel(speaker)
                }

                Spacer()

                // Timestamp with monospaced digits for alignment
                Text(timestamp)
                    .font(.system(size: 10, weight: .light).monospacedDigit())
                    .tracking(0.5)
                    .foregroundColor(VaporColor.overcast)
            }

            // Transcript text - animated or static based on flag
            if animateTextReveal {
                StaggeredTextRevealView(
                    text: text,
                    font: .system(size: 16, weight: .light),
                    foregroundColor: VaporColor.textPrimary,
                    lineSpacing: 6
                )
            } else {
                Text(text)
                    .font(.system(size: 16, weight: .light))
                    .lineSpacing(6)
                    .foregroundColor(VaporColor.textPrimary)
            }
        }
        .accessibilityIdentifier("transcriptSegment")
    }

    @ViewBuilder
    private func speakerLabel(_ speaker: SpeakerType) -> some View {
        if let onTap = onSpeakerTap {
            Button(action: onTap) {
                speakerLabelContent(speaker)
            }
            .buttonStyle(SpeakerLabelButtonStyle())
            .accessibilityIdentifier(speaker.isUnassigned ? "speakerUnassignedChip" : "speakerLabel")
        } else {
            speakerLabelContent(speaker)
        }
    }

    @ViewBuilder
    private func speakerLabelContent(_ speaker: SpeakerType) -> some View {
        switch speaker {
        case .unassigned(_, let color):
            // Bordered chip with icon for unassigned speakers
            HStack(spacing: 6) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(speaker.label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(color)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(color, lineWidth: 1)
            )

        case .speaker(_, let color):
            // Minimal dot + name for assigned speakers
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)

                Text(speaker.label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(color)
            }
        }
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
    private let animateTextReveal: Bool

    public init(
        speaker: SpeakerType,
        timestamp: String,
        text: String,
        isActive: Bool = false,
        animateTextReveal: Bool = false
    ) {
        self.speaker = speaker
        self.timestamp = timestamp
        self.text = text
        self.isActive = isActive
        self.animateTextReveal = animateTextReveal
    }

    public var body: some View {
        TranscriptSegment(
            speaker: speaker,
            timestamp: timestamp,
            text: text,
            isActive: isActive,
            animateTextReveal: animateTextReveal
        )
    }
}

// MARK: - Live Indicator

/// Indicator shown at the end of live transcript during recording.
/// Displays "Listening..." with a subtle breathing animation effect.
public struct TranscriptLiveIndicator: View {
    @State private var breatheOpacity: Double = 0.4

    public init() {}

    public var body: some View {
        HStack {
            Spacer()
            Text("Listening...")
                .font(.system(size: 14, weight: .light))
                .italic()
                .foregroundColor(VaporColor.textTertiary)
                .opacity(breatheOpacity)
            Spacer()
        }
        .padding(.vertical, 20)
        .onAppear {
            withAnimation(
                VaporAnimation.breatheCurve.animation(duration: VaporAnimation.breatheDuration)
                    .repeatForever(autoreverses: true)
            ) {
                breatheOpacity = 0.7
            }
        }
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
            // Unassigned Speaker 1
            TranscriptSegment(
                speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                timestamp: "00:12",
                text: "So we're looking at the Vapor direction."
            )

            // Unassigned Speaker 2
            TranscriptSegment(
                speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                timestamp: "00:18",
                text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
            )

            // Assigned speaker
            TranscriptSegment(
                speaker: .speaker(name: "Sarah", color: SpeakerColor.forIndex(0).color),
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
