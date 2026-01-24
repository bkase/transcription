import ComposableArchitecture
import DesignSystem
import Models
import AudioPlayerFeature
import SwiftUI

// MARK: - Session Detail View

/// Session detail screen displaying transcript in script format.
/// Matches the Session Detail screen from app.pen design.
public struct SessionDetailView: View {
    @Bindable var store: StoreOf<SessionDetailFeature>

    public init(store: StoreOf<SessionDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 0) {
                // Navigation header
                navHeader

                // Content scroll area
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Session header
                        sessionHeader
                            .padding(.top, VaporSpacing.md)
                            .padding(.horizontal, VaporSpacing.lg)

                        // Transcript segments
                        transcriptContent
                            .padding(.top, VaporSpacing.xl)
                            .padding(.horizontal, VaporSpacing.lg)

                        // End indicator
                        if store.session != nil && !store.segments.isEmpty {
                            TranscriptEndIndicator()
                                .padding(.horizontal, VaporSpacing.lg)
                        }

                        // Bottom padding for audio player
                        Spacer()
                            .frame(height: 100)
                    }
                }
            }

            // Floating audio player
            if store.audioPlayer != nil {
                audioPlayerSection
            }
        }
        .background(VaporColor.mist)
        .onAppear {
            store.send(.onAppear)
        }
    }

    // MARK: - Navigation Header

    private var navHeader: some View {
        HStack {
            NavButton(label: "Back") {
                store.send(.backTapped)
            }

            Spacer()

            Avatar(size: .large)
        }
        .padding(.top, VaporSpacing.md)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.sm)
    }

    // MARK: - Session Header

    @ViewBuilder
    private var sessionHeader: some View {
        if let session = store.session {
            VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                // Title row with action buttons
                HStack(alignment: .top) {
                    Text(session.title ?? "Untitled")
                        .font(.system(size: 28, weight: .thin))
                        .tracking(-0.5)
                        .foregroundColor(VaporColor.textPrimary)

                    Spacer()

                    // Share button
                    IconButton(systemName: "square.and.arrow.up", style: .transparent, iconColor: VaporColor.textTertiary) {}
                        .accessibilityIdentifier("shareButton")

                    // More actions button
                    IconButton(systemName: "ellipsis", style: .transparent, iconColor: VaporColor.textTertiary) {}
                        .accessibilityIdentifier("moreActionsButton")
                }

                // Metadata row
                HStack(spacing: VaporSpacing.sm) {
                    Text(formatTime(session.startedAt))
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(VaporColor.textSecondary)

                    if let durationMs = session.durationMs {
                        Circle()
                            .fill(VaporColor.textTertiary)
                            .frame(width: 3, height: 3)

                        Text(formatDuration(durationMs))
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(VaporColor.textSecondary)
                    }
                }
            }
        } else if store.isLoading {
            // Loading state
            VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(VaporColor.haze)
                    .frame(width: 200, height: 32)

                RoundedRectangle(cornerRadius: 4)
                    .fill(VaporColor.haze)
                    .frame(width: 120, height: 16)
            }
        } else if let error = store.error {
            Text(error)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.recording)
        }
    }

    // MARK: - Transcript Content

    @ViewBuilder
    private var transcriptContent: some View {
        if store.isLoading {
            // Loading placeholder
            VStack(alignment: .leading, spacing: VaporSpacing.xl) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VaporColor.haze)
                            .frame(width: 80, height: 12)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(VaporColor.haze)
                            .frame(height: 48)
                    }
                }
            }
        } else if store.segments.isEmpty && store.session != nil {
            // Empty state
            Text("No transcript available")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, VaporSpacing.xl)
        } else {
            // Transcript segments
            LazyVStack(alignment: .leading, spacing: VaporSpacing.xl) {
                ForEach(store.segments) { segment in
                    TranscriptSegment(
                        speaker: speakerType(for: segment),
                        timestamp: formatTimestamp(segment.startMs),
                        text: segment.text
                    )
                }
            }
        }
    }

    // MARK: - Audio Player Section

    @ViewBuilder
    private var audioPlayerSection: some View {
        if let audioPlayerState = store.audioPlayer {
            AudioPlayer(
                title: store.session?.title ?? "Playing Audio",
                currentTime: AudioPlayerFeature.formatTime(audioPlayerState.currentTime),
                progress: audioPlayerState.progress,
                playState: audioPlayerState.isPlaying ? .playing : .paused
            ) {
                store.send(.audioPlayer(.playPauseTapped))
            }
            .padding(.horizontal, VaporSpacing.lg)
            .padding(.bottom, VaporSpacing.lg)
        }
    }

    // MARK: - Helpers

    private func speakerType(for segment: DetailSegment) -> SpeakerType {
        guard let machineSpeakerId = segment.machineSpeakerId else {
            return .guest
        }

        // Find the speaker track for this segment
        if let track = store.speakerTracks.first(where: { $0.machineSpeakerId == machineSpeakerId }) {
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let hours = minutes / 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatTimestamp(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Session Detail View Preview (for snapshots)

/// Non-interactive preview variant for snapshot testing.
/// Uses static data instead of Store for deterministic snapshots.
public struct SessionDetailViewPreview: View {
    public struct SegmentData: Identifiable {
        public let id: String
        public let speaker: SpeakerType
        public let timestamp: String
        public let text: String

        public init(
            id: String = UUID().uuidString,
            speaker: SpeakerType,
            timestamp: String,
            text: String
        ) {
            self.id = id
            self.speaker = speaker
            self.timestamp = timestamp
            self.text = text
        }
    }

    private let title: String
    private let time: String
    private let duration: String?
    private let segments: [SegmentData]
    private let showAudioPlayer: Bool
    private let audioProgress: Double
    private let audioTime: String
    private let isPlaying: Bool

    public init(
        title: String,
        time: String,
        duration: String? = nil,
        segments: [SegmentData] = [],
        showAudioPlayer: Bool = true,
        audioProgress: Double = 0.0,
        audioTime: String = "0:00",
        isPlaying: Bool = false
    ) {
        self.title = title
        self.time = time
        self.duration = duration
        self.segments = segments
        self.showAudioPlayer = showAudioPlayer
        self.audioProgress = audioProgress
        self.audioTime = audioTime
        self.isPlaying = isPlaying
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Navigation header
                HStack {
                    // Back button (non-interactive)
                    HStack(spacing: VaporSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(VaporColor.textSecondary)

                        Text("Back")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(VaporColor.textSecondary)
                    }
                    .padding(VaporSpacing.sm)

                    Spacer()

                    Avatar(size: .large)
                }
                .padding(.top, VaporSpacing.md)
                .padding(.horizontal, VaporSpacing.lg)
                .padding(.bottom, VaporSpacing.sm)

                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Session header
                        VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                            HStack(alignment: .top) {
                                Text(title)
                                    .font(.system(size: 28, weight: .thin))
                                    .tracking(-0.5)
                                    .foregroundColor(VaporColor.textPrimary)

                                Spacer()

                                // Share icon
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(VaporColor.textTertiary)
                                    .padding(VaporSpacing.sm)

                                // More icon
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(VaporColor.textTertiary)
                                    .padding(VaporSpacing.sm)
                            }

                            HStack(spacing: VaporSpacing.sm) {
                                Text(time)
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(VaporColor.textSecondary)

                                if let duration = duration {
                                    Circle()
                                        .fill(VaporColor.textTertiary)
                                        .frame(width: 3, height: 3)

                                    Text(duration)
                                        .font(.system(size: 14, weight: .light))
                                        .foregroundColor(VaporColor.textSecondary)
                                }
                            }
                        }
                        .padding(.top, VaporSpacing.md)
                        .padding(.horizontal, VaporSpacing.lg)

                        // Transcript segments
                        LazyVStack(alignment: .leading, spacing: VaporSpacing.xl) {
                            ForEach(segments) { segment in
                                TranscriptSegmentPreview(
                                    speaker: segment.speaker,
                                    timestamp: segment.timestamp,
                                    text: segment.text
                                )
                            }
                        }
                        .padding(.top, VaporSpacing.xl)
                        .padding(.horizontal, VaporSpacing.lg)

                        // End indicator
                        if !segments.isEmpty {
                            TranscriptEndIndicator()
                                .padding(.horizontal, VaporSpacing.lg)
                        }

                        // Bottom padding
                        Spacer()
                            .frame(height: 100)
                    }
                }
            }

            // Audio player
            if showAudioPlayer {
                AudioPlayerPreview(
                    title: "Playing Audio",
                    currentTime: audioTime,
                    progress: audioProgress,
                    isPlaying: isPlaying
                )
                .padding(.horizontal, VaporSpacing.lg)
                .padding(.bottom, VaporSpacing.lg)
            }
        }
        .background(VaporColor.mist)
    }
}

// MARK: - Previews

#if DEBUG
struct SessionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SessionDetailViewPreview(
            title: "Architecture Review",
            time: "9:41 AM",
            duration: "42:10",
            segments: [
                .init(
                    speaker: .user,
                    timestamp: "00:12",
                    text: "So we're looking at the Vapor direction."
                ),
                .init(
                    speaker: .guest,
                    timestamp: "00:18",
                    text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                ),
                .init(
                    speaker: .user,
                    timestamp: "00:35",
                    text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
                ),
                .init(
                    speaker: .guest,
                    timestamp: "00:52",
                    text: "Right, and when we look at the transcript, it shouldn't feel like a messaging app. It should feel like a script. A record."
                ),
                .init(
                    speaker: .user,
                    timestamp: "01:15",
                    text: "Agreed. Let's tighten up the spacing. No bubbles, just text."
                )
            ],
            audioProgress: 0.3,
            audioTime: "12:40",
            isPlaying: true
        )
    }
}
#endif
