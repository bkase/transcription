import ComposableArchitecture
import DesignSystem
import Models
import AudioPlayerFeature
import Observability
import SpeakerPickerFeature
import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - Session Detail View

/// Session detail screen displaying transcript in script format.
/// Matches the Session Detail screen from app.pen design.
public struct SessionDetailView: View {
    @Bindable var store: StoreOf<SessionDetailFeature>

    public init(store: StoreOf<SessionDetailFeature>) {
        self.store = store
    }

    /// Whether the session can be continued (has audio and is in a completed state)
    private var canContinueRecording: Bool {
        guard let session = store.session else { return false }
        let isCompletedState = session.processingState == .processed || session.processingState == .partial
        let hasAudio = session.audioPath != nil
        return isCompletedState && hasAudio
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
                                .vaporAppear(delay: Double(store.segments.count) * 0.05)
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
        .onDisappear {
            store.send(.onDisappear)
        }
        #if os(iOS)
        .fullScreenCover(
            item: $store.scope(state: \.speakerPicker, action: \.speakerPicker)
        ) { speakerPickerStore in
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.send(.speakerPicker(.presented(.closeModal)))
                    }

                SpeakerPickerView(store: speakerPickerStore)
                    .padding(VaporSpacing.lg)
            }
            .presentationBackground(.clear)
        }
        .sheet(
            isPresented: Binding(
                get: { store.shareURL != nil },
                set: { if !$0 { store.send(.shareSheetDismissed) } }
            )
        ) {
            if let shareURL = store.shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { store.isShowingActionsMenu },
                set: { if !$0 { store.send(.actionsMenuDismissed) } }
            )
        ) {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.send(.actionsMenuDismissed)
                    }

                SessionActionsModal(
                    onShare: { store.send(.shareTapped) },
                    onExport: { store.send(.exportTapped) },
                    onContinueRecording: canContinueRecording ? { store.send(.continueRecordingTapped) } : nil,
                    onDelete: { store.send(.deleteTapped) },
                    onDismiss: { store.send(.actionsMenuDismissed) }
                )
                .frame(width: 260)
                .padding(.top, 100)
                .padding(.trailing, VaporSpacing.lg)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
            .presentationBackground(.clear)
        }
        .confirmationDialog(
            "Delete Recording",
            isPresented: Binding(
                get: { store.isShowingDeleteConfirmation },
                set: { if !$0 { store.send(.deleteCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteConfirmed)
            }
            Button("Cancel", role: .cancel) {
                store.send(.deleteCancelled)
            }
        } message: {
            Text("This will permanently delete this recording and its transcript. This action cannot be undone.")
        }
        .alert(
            item: Binding(
                get: { store.alertInfo },
                set: { if $0 == nil { store.send(.alertDismissed) } }
            )
        ) { alertInfo in
            Alert(
                title: Text(alertInfo.title),
                message: Text(alertInfo.message),
                primaryButton: alertButton(for: alertInfo.primaryButton),
                secondaryButton: alertInfo.secondaryButton.map { alertButton(for: $0) } ?? .cancel()
            )
        }
        #endif
    }

    // MARK: - Navigation Header

    private var navHeader: some View {
        HStack {
            NavButton(label: "Back") {
                store.send(.backTapped)
            }

            Spacer()

            avatarView
        }
        .padding(.top, 56)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.sm)
    }

    @ViewBuilder
    private var avatarView: some View {
        #if os(iOS)
        if let imageData = store.userProfile.avatar.imageData,
           let uiImage = UIImage(data: imageData) {
            Avatar(image: Image(uiImage: uiImage), size: .large)
                .accessibilityIdentifier("sessionDetailAvatarWithPhoto")
        } else if !store.initials.isEmpty {
            Avatar(initials: store.initials, size: .large)
                .accessibilityIdentifier("sessionDetailAvatarWithInitials")
        } else {
            Avatar(size: .large)
                .accessibilityIdentifier("sessionDetailAvatarEmpty")
        }
        #else
        if !store.initials.isEmpty {
            Avatar(initials: store.initials, size: .large)
                .accessibilityIdentifier("sessionDetailAvatarWithInitials")
        } else {
            Avatar(size: .large)
                .accessibilityIdentifier("sessionDetailAvatarEmpty")
        }
        #endif
    }

    // MARK: - Session Header

    /// Convert speaker tracks to avatar info for display
    private var speakerAvatars: [SpeakerAvatarInfo] {
        store.speakerTracks.map { track -> SpeakerAvatarInfo in
            if let personId = track.personId, let personName = track.personName {
                // Assigned speaker - use person data
                return SpeakerAvatarInfo.from(
                    id: personId,
                    name: personName,
                    imageData: nil, // TODO: Add imageData to DetailSpeakerTrack if needed
                    colorIndex: track.displayOrder - 1
                )
            } else {
                // Unassigned speaker - use display order
                return SpeakerAvatarInfo(
                    id: track.machineSpeakerId,
                    imageData: nil,
                    initials: "S\(track.displayOrder)",
                    color: SpeakerColor.forIndex(track.displayOrder - 1)
                )
            }
        }
    }

    @ViewBuilder
    private var sessionHeader: some View {
        if let session = store.session {
            VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                // Title row with speaker avatars and action buttons
                HStack(alignment: .center, spacing: VaporSpacing.sm) {
                    // Speaker avatars
                    if !speakerAvatars.isEmpty {
                        SpeakerAvatarStack(speakers: speakerAvatars)
                    }

                    if store.isEditingTitle {
                        // Editing mode - show text field
                        HStack(spacing: VaporSpacing.sm) {
                            TextField(
                                "Session title",
                                text: Binding(
                                    get: { store.editedTitle },
                                    set: { store.send(.titleChanged($0)) }
                                )
                            )
                            .font(.system(size: 28, weight: .thin))
                            .tracking(-0.5)
                            .foregroundColor(VaporColor.textPrimary)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit {
                                store.send(.saveTitle)
                            }
                            .accessibilityIdentifier("titleTextField")

                            // Cancel button
                            Button {
                                store.send(.cancelTitleEdit)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(VaporColor.textTertiary)
                            }
                            .accessibilityIdentifier("cancelTitleEdit")

                            // Save button
                            Button {
                                store.send(.saveTitle)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(VaporColor.sky)
                            }
                            .accessibilityIdentifier("saveTitleEdit")
                        }
                    } else {
                        // Display mode - tappable title
                        Text(session.title ?? "Untitled")
                            .font(.system(size: 28, weight: .thin))
                            .tracking(-0.5)
                            .foregroundColor(VaporColor.textPrimary)
                            .onTapGesture {
                                store.send(.titleTapped)
                            }
                            .accessibilityIdentifier("sessionTitle")
                    }

                    Spacer()

                    // More actions button (ellipsis) - hidden during title edit
                    // Use opacity instead of conditional to prevent slide-in animation
                    IconButton(
                        systemName: "ellipsis",
                        style: .transparent,
                        iconColor: VaporColor.textTertiary
                    ) {
                        store.send(.moreButtonTapped)
                    }
                    .accessibilityIdentifier("moreButton")
                    .opacity(store.isEditingTitle ? 0 : (store.isExporting || store.isDeleting ? 0.5 : 1.0))
                    .disabled(store.isEditingTitle || store.isExporting || store.isDeleting)
                    .animation(nil, value: store.isEditingTitle)
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
        } else if store.isRetrying {
            // Retrying transcription
            VStack(spacing: VaporSpacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(VaporColor.sky)

                Text("Retrying transcription...")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, VaporSpacing.xxl)
            .accessibilityIdentifier("retryingIndicator")
        } else if let session = store.session, session.processingState == .transcribing {
            // Processing state - transcription in progress
            VStack(spacing: VaporSpacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(VaporColor.sky)

                Text("Processing transcription...")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, VaporSpacing.xxl)
            .accessibilityIdentifier("transcribingIndicator")

            // Still show any segments that have been transcribed so far
            if !store.segments.isEmpty {
                transcriptSegmentsList
                    .padding(.top, VaporSpacing.xl)
            }
        } else if let session = store.session, session.processingState == .failed {
            // Failed state - show error UI with retry CTA
            VStack(spacing: VaporSpacing.lg) {
                ErrorStateView(
                    type: store.segments.isEmpty ? .transcriptionUnavailable : .transcriptionFailed,
                    primaryLabel: "Retry Transcription",
                    primaryAction: {
                        store.send(.retryTranscriptionTapped)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let session = store.session, session.processingState == .partial {
            // Partial state - show segments with a partial banner
            VStack(alignment: .leading, spacing: VaporSpacing.md) {
                StatusBanner(
                    type: .custom(
                        icon: "exclamationmark.triangle",
                        title: "Partial transcript",
                        description: "Some parts couldn't be processed"
                    ),
                    onRetry: {
                        store.send(.retryTranscriptionTapped)
                    }
                )
                .accessibilityIdentifier("partialBanner")

                transcriptSegmentsList
            }
        } else if store.segments.isEmpty && store.session != nil {
            // Empty state - processed but no segments
            Text("No transcript available")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, VaporSpacing.xl)
        } else {
            // Normal state - show transcript segments
            transcriptSegmentsList
        }
    }

    @ViewBuilder
    private var transcriptSegmentsList: some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.xl) {
            ForEach(Array(store.segments.enumerated()), id: \.element.id) { index, segment in
                TranscriptSegment(
                    speaker: segment.speakerType,
                    timestamp: formatTimestamp(segment.startMs),
                    text: segment.text,
                    onSpeakerTap: {
                        store.send(.speakerLabelTapped(
                            segmentId: segment.id,
                            machineSpeakerId: segment.machineSpeakerId
                        ))
                    }
                )
                .vaporAppear(index: index)
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
            .vaporAppear()
            .padding(.horizontal, VaporSpacing.lg)
            .padding(.bottom, VaporSpacing.lg)
        }
    }

    // MARK: - Helpers

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
        TranscriptRendering.formatTimestamp(milliseconds)
    }

    private func alertButton(for button: AlertInfo.AlertButton) -> Alert.Button {
        if button.isDestructive {
            return .destructive(Text(button.title)) {
                store.send(.alertActionTapped(button.action))
            }
        } else if button.action == .dismiss {
            return .cancel(Text(button.title)) {
                store.send(.alertActionTapped(button.action))
            }
        } else {
            return .default(Text(button.title)) {
                store.send(.alertActionTapped(button.action))
            }
        }
    }
}

// MARK: - Session Detail View Preview (for snapshots)

/// Non-interactive preview variant for snapshot testing.
/// Uses static data instead of Store for deterministic snapshots.
public struct SessionDetailViewPreview: View {
    public struct SegmentData: Identifiable, Sendable {
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

    /// Display mode for different processing states
    public enum DisplayMode: Sendable {
        /// Normal state with transcript segments
        case normal
        /// Transcription in progress
        case transcribing
        /// Retrying transcription
        case retrying
        /// Failed transcription with no segments
        case failed
        /// Partial transcription with some segments
        case partial(segments: [SegmentData])
    }

    private let title: String
    private let time: String
    private let duration: String?
    private let segments: [SegmentData]
    private let displayMode: DisplayMode
    private let showAudioPlayer: Bool
    private let audioProgress: Double
    private let audioTime: String
    private let isPlaying: Bool

    public init(
        title: String,
        time: String,
        duration: String? = nil,
        segments: [SegmentData] = [],
        displayMode: DisplayMode = .normal,
        showAudioPlayer: Bool = true,
        audioProgress: Double = 0.0,
        audioTime: String = "0:00",
        isPlaying: Bool = false
    ) {
        self.title = title
        self.time = time
        self.duration = duration
        self.segments = segments
        self.displayMode = displayMode
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
                .padding(.top, 56)
                .padding(.horizontal, VaporSpacing.lg)
                .padding(.bottom, VaporSpacing.sm)

                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Session header
                        VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                            HStack(alignment: .center) {
                                Text(title)
                                    .font(.system(size: 28, weight: .thin))
                                    .tracking(-0.5)
                                    .foregroundColor(VaporColor.textPrimary)

                                Spacer()

                                // More actions button (ellipsis)
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

                        // Transcript content based on display mode
                        transcriptArea
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

    @ViewBuilder
    private var transcriptArea: some View {
        switch displayMode {
        case .transcribing:
            VStack(spacing: VaporSpacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(VaporColor.sky)

                Text("Processing transcription...")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, VaporSpacing.xxl)
            .padding(.horizontal, VaporSpacing.lg)

            // Still show any segments if present
            if !segments.isEmpty {
                segmentsList
                    .padding(.top, VaporSpacing.xl)
            }

            Spacer().frame(height: 100)

        case .retrying:
            VStack(spacing: VaporSpacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(VaporColor.sky)

                Text("Retrying transcription...")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, VaporSpacing.xxl)
            .padding(.horizontal, VaporSpacing.lg)

            Spacer().frame(height: 100)

        case .failed:
            VStack(spacing: VaporSpacing.lg) {
                ErrorStateView(
                    type: .transcriptionUnavailable,
                    primaryLabel: "Retry Transcription",
                    primaryAction: {}
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, VaporSpacing.lg)

        case .partial(let partialSegments):
            VStack(alignment: .leading, spacing: VaporSpacing.md) {
                StatusBanner(
                    type: .custom(
                        icon: "exclamationmark.triangle",
                        title: "Partial transcript",
                        description: "Some parts couldn't be processed"
                    ),
                    onRetry: {}
                )

                LazyVStack(alignment: .leading, spacing: VaporSpacing.xl) {
                    ForEach(partialSegments) { segment in
                        TranscriptSegmentPreview(
                            speaker: segment.speaker,
                            timestamp: segment.timestamp,
                            text: segment.text
                        )
                    }
                }

                if !partialSegments.isEmpty {
                    TranscriptEndIndicator()
                }
            }
            .padding(.top, VaporSpacing.xl)
            .padding(.horizontal, VaporSpacing.lg)

            Spacer().frame(height: 100)

        case .normal:
            segmentsList
                .padding(.top, VaporSpacing.xl)

            // End indicator
            if !segments.isEmpty {
                TranscriptEndIndicator()
                    .padding(.horizontal, VaporSpacing.lg)
            }

            Spacer().frame(height: 100)
        }
    }

    private var segmentsList: some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.xl) {
            ForEach(segments) { segment in
                TranscriptSegmentPreview(
                    speaker: segment.speaker,
                    timestamp: segment.timestamp,
                    text: segment.text
                )
            }
        }
        .padding(.horizontal, VaporSpacing.lg)
    }
}

// MARK: - Previews

// MARK: - Share Sheet (UIActivityViewController wrapper)

#if os(iOS)
import UIKit

/// A SwiftUI wrapper for UIActivityViewController to share files
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if DEBUG
struct SessionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SessionDetailViewPreview(
            title: "Architecture Review",
            time: "9:41 AM",
            duration: "42:10",
            segments: [
                .init(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:12",
                    text: "So we're looking at the Vapor direction."
                ),
                .init(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:18",
                    text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                ),
                .init(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:35",
                    text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
                ),
                .init(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:52",
                    text: "Right, and when we look at the transcript, it shouldn't feel like a messaging app. It should feel like a script. A record."
                ),
                .init(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
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
