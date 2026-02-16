import ComposableArchitecture
import DesignSystem
import Models
import Observability
import SpeakerPickerFeature
import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - Recording View

/// Recording screen with listening state, recording header, and controls.
/// Matches the Recording - Listening screen from app.pen design.
public struct RecordingView: View {
    @Bindable var store: StoreOf<RecordingFeature>
    private let onBack: () -> Void

    public init(store: StoreOf<RecordingFeature>, onBack: @escaping () -> Void) {
        self.store = store
        self.onBack = onBack
    }

    public var body: some View {
        mainContent
            .discardAlert(store: store)
            .errorAlert(store: store, alertButton: alertButton)
            .actionsMenu(store: store, privacyModeLabel: privacyModeLabel)
            .speakerPickerModal(store: $store, sheetContent: speakerPickerSheet)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            navHeader
            RecordingHeader(
                elapsedTime: formatElapsedTime(store.elapsedSeconds),
                isPaused: store.isPaused,
                onPauseResume: {
                    if store.isPaused {
                        store.send(.resumeRecording)
                    } else {
                        store.send(.pauseRecording)
                    }
                }
            )
            contentArea
            speakerSetupCard
        }
        .background(VaporColor.mist)
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    @ViewBuilder
    private func speakerPickerSheet(store speakerPickerStore: StoreOf<SpeakerPickerFeature>) -> some View {
        NavigationStack {
            SpeakerPickerView(store: speakerPickerStore)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.speakerPicker(.presented(.closeModal)))
                        }
                    }
                }
        }
    }

    private func privacyModeLabel(for mode: AudioRetentionMode) -> String {
        let isSelected = store.audioRetentionMode == mode
        let checkmark = isSelected ? "✓ " : "   "
        switch mode {
        case .both:
            return "\(checkmark)Keep Audio & Transcript"
        case .transcriptOnly:
            return "\(checkmark)Transcript Only (Delete Audio)"
        case .audioOnly:
            return "\(checkmark)Audio Only (No Transcript)"
        }
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

    // MARK: - Nav Header

    private var navHeader: some View {
        HStack {
            NavButton(label: "Back", action: onBack)
            Spacer()
            if store.isRecording {
                Button {
                    store.send(.moreButtonTapped)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(VaporColor.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityIdentifier("moreButton")
            }
            avatarView
        }
        .padding(.top, 56)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.md)
    }

    @ViewBuilder
    private var avatarView: some View {
        #if os(iOS)
        if let imageData = store.userProfile.avatar.imageData,
           let uiImage = UIImage(data: imageData) {
            Avatar(image: Image(uiImage: uiImage), size: .large)
        } else if !store.initials.isEmpty {
            Avatar(initials: store.initials, size: .large)
        } else {
            Avatar(size: .large)
        }
        #else
        if !store.initials.isEmpty {
            Avatar(initials: store.initials, size: .large)
        } else {
            Avatar(size: .large)
        }
        #endif
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if store.isPermissionDenied {
            // Permission denied state with Settings button
            VStack(spacing: VaporSpacing.lg) {
                Spacer()
                Text(store.error ?? "Microphone access is required to record.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(VaporColor.recording)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VaporSpacing.xl)

                Button {
                    store.send(.openSettingsTapped)
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(VaporColor.cloud)
                        .padding(.horizontal, VaporSpacing.xl)
                        .padding(.vertical, VaporSpacing.md)
                        .background(VaporColor.sky)
                        .cornerRadius(VaporRadius.md)
                }
                .accessibilityIdentifier("openSettingsButton")

                Spacer()
            }
        } else if let error = store.error {
            // Error state (non-permission errors)
            VStack {
                Spacer()
                Text(error)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(VaporColor.recording)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VaporSpacing.xl)
                Spacer()
            }
        } else if !store.liveSegments.isEmpty {
            // Live transcript segments
            liveTranscriptView
        } else if store.isPaused {
            // Paused state
            VStack {
                Spacer()
                Text("Paused")
                    .font(.system(size: 24, weight: .thin))
                    .tracking(1)
                    .foregroundColor(VaporColor.textTertiary)
                    .accessibilityIdentifier("pausedIndicator")
                Spacer()
            }
        } else if store.isListening {
            // Listening but no segments yet
            VStack(spacing: VaporSpacing.md) {
                Spacer()
                if store.isTranscriptionAvailable {
                    listeningIndicator
                } else {
                    transcriptionUnavailableIndicator
                }
                Spacer()
            }
        } else if store.isRecording {
            // Recording in progress, waiting for audio...
            VStack {
                Spacer()
                Text("Starting...")
                    .font(.system(size: 24, weight: .thin))
                    .tracking(1)
                    .foregroundColor(VaporColor.textTertiary)
                Spacer()
            }
        } else {
            // Idle state
            Spacer()
        }
    }

    private var listeningIndicator: some View {
        Text("Listening...")
            .font(.system(size: 24, weight: .thin))
            .tracking(1)
            .foregroundColor(VaporColor.textTertiary)
    }

    private var transcriptionUnavailableIndicator: some View {
        VStack(spacing: VaporSpacing.sm) {
            Text("Recording audio...")
                .font(.system(size: 20, weight: .thin))
                .tracking(1)
                .foregroundColor(VaporColor.textSecondary)

            Text("Live transcription unavailable")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textTertiary)

            Text("Transcription will run when recording stops")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(VaporColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VaporSpacing.xl)
        }
    }

    private var liveTranscriptView: some View {
        ScrollViewReader { proxy in
            liveTranscriptScrollView(proxy: proxy)
        }
    }

    private func liveTranscriptScrollView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            liveTranscriptContent
        }
        .onChange(of: store.liveSegments.count) { _, _ in
            scrollToLastSegment(proxy: proxy)
        }
    }

    private var liveTranscriptContent: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.lg) {
            liveSegmentsList
            liveIndicatorIfListening
        }
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.top, VaporSpacing.md)
    }

    private var liveSegmentsList: some View {
        ForEach(Array(store.liveSegments.enumerated()), id: \.element.id) { index, segment in
            liveSegmentRow(index: index, segment: segment)
        }
    }

    private func liveSegmentRow(index: Int, segment: LiveSegment) -> some View {
        let isLastSegment = index == store.liveSegments.count - 1
        return TranscriptSegment(
            speaker: speakerType(for: segment),
            timestamp: formatTimestamp(segment.startMs),
            text: segment.text,
            isActive: isLastSegment && store.isListening,
            onSpeakerTap: {
                store.send(.speakerLabelTapped(segmentId: segment.id, machineSpeakerId: segment.machineSpeakerId))
            }
        )
        .vaporAppear(index: index)
        .id(segment.id)
    }

    @ViewBuilder
    private var liveIndicatorIfListening: some View {
        if store.isListening {
            TranscriptLiveIndicator()
                .vaporAppear()
                .id("live-indicator")
        }
    }

    private func scrollToLastSegment(proxy: ScrollViewProxy) {
        if let lastSegment = store.liveSegments.last {
            withAnimation(VaporAnimation.driftCurve.animation(duration: VaporAnimation.normalDuration)) {
                proxy.scrollTo(lastSegment.id, anchor: .bottom)
            }
        }
    }

    private func speakerType(for segment: LiveSegment) -> SpeakerType {
        RecordingSpeakerRendering.speakerType(for: segment, speakerTracks: store.speakerTracks)
    }

    private func formatTimestamp(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Speaker Setup Card

    private var speakerSetupCard: some View {
        VStack(spacing: 0) {
            if store.speakerSetupExpanded {
                speakerSetupExpanded
            } else {
                speakerSetupCollapsed
            }
        }
    }

    private var speakerSetupCollapsed: some View {
        VStack(spacing: 12) {
            // "Assign speakers & finish" bar row
            Button {
                store.send(.toggleSpeakerSetup)
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 16))
                            .foregroundColor(VaporColor.textSecondary)
                        Text("Assign speakers & finish")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(VaporColor.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14))
                        .foregroundColor(VaporColor.textTertiary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("speakerSetupToggle")

            // Disabled Stop & Save button
            stopAndSaveButton(enabled: false)
        }
        .padding(.top, 16)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(
            speakerSetupCardBackground
        )
    }

    private var speakerSetupExpanded: some View {
        VStack(spacing: 16) {
            // "Who's speaking?" title row with chevron-down
            Button {
                store.send(.toggleSpeakerSetup)
            } label: {
                HStack {
                    Text("Who's speaking?")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(VaporColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(VaporColor.textTertiary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("speakerSetupToggle")

            // Description
            Text("Pick a count, then tap to name them.")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(VaporColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Pill row: [1] [2] [3] [4+]
            speakerCountPillRow

            // Speaker names section (only when count is selected)
            if let count = store.selectedSpeakerCount {
                // Divider
                Rectangle()
                    .fill(VaporColor.fog)
                    .frame(height: 1)

                // Speaker rows
                speakerNamesSection(count: count)
            }

            // Stop & Save button
            stopAndSaveButton(enabled: store.selectedSpeakerCount != nil)
        }
        .padding(24)
        .background(
            speakerSetupCardBackground
        )
    }

    private var speakerCountPillRow: some View {
        HStack(spacing: 8) {
            ForEach([1, 2, 3, 4], id: \.self) { count in
                speakerCountPill(count: count)
            }
        }
    }

    private func speakerCountPill(count: Int) -> some View {
        let isSelected = store.selectedSpeakerCount == count
        let label = count == 4 ? "4+" : "\(count)"

        return Button {
            store.send(.selectSpeakerCount(count))
        } label: {
            Text(label)
                .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? VaporColor.cloud : VaporColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? VaporColor.sky : VaporColor.haze)
                )
                .overlay(
                    isSelected ? nil :
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(VaporColor.fog, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("speakerCount\(count)")
    }

    private func speakerNamesSection(count: Int) -> some View {
        VStack(spacing: 10) {
            Text("Speakers")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(VaporColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<count, id: \.self) { index in
                speakerNameRow(index: index)
            }
        }
    }

    private func speakerNameRow(index: Int) -> some View {
        let color = SpeakerColor.forIndex(index).color
        let trackForIndex = store.speakerTracks.first { $0.displayOrder == index + 1 }
        let displayName = trackForIndex?.personName ?? "Speaker \(index + 1)"

        return Button {
            if let track = trackForIndex,
               let sessionId = store.sessionID {
                store.send(.speakerLabelTapped(
                    segmentId: TranscriptSegmentID("speaker-setup-\(index)"),
                    machineSpeakerId: track.machineSpeakerId
                ))
            }
        } label: {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(displayName)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(VaporColor.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(VaporColor.textTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(VaporColor.haze)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(VaporColor.fog, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("speakerRow\(index)")
    }

    private func stopAndSaveButton(enabled: Bool) -> some View {
        Button {
            store.send(.stopAndSave)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(enabled ? VaporColor.cloud : VaporColor.textTertiary)
                    .frame(width: 12, height: 12)
                Text("Stop & Save")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(enabled ? VaporColor.cloud : VaporColor.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(enabled ? VaporColor.recording : VaporColor.fog)
            )
            .opacity(enabled ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
        .accessibilityIdentifier("stopAndSaveButton")
    }

    private var speakerSetupCardBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 16
        )
        .fill(VaporColor.cloud)
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16
            )
            .strokeBorder(VaporColor.fog, lineWidth: 1)
        )
        .shadow(color: Color(hex: "#2D3748").opacity(0.063), radius: 16, x: 0, y: -4)
    }

    // MARK: - Helpers

    private func formatElapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        let hours = minutes / 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

// MARK: - Recording View Preview (for snapshots)

/// Data for a live transcript segment in preview.
public struct LiveSegmentData: Equatable {
    public let speaker: SpeakerType
    public let timestamp: String
    public let text: String

    public init(speaker: SpeakerType, timestamp: String, text: String) {
        self.speaker = speaker
        self.timestamp = timestamp
        self.text = text
    }
}

/// Speaker setup card state for previews
public enum SpeakerSetupState: Equatable {
    /// Accordion collapsed
    case closed
    /// Accordion open, no count selected
    case openUnselected
    /// Accordion open, count selected
    case openSelected(Int)
}

/// Non-interactive preview variant for snapshot testing.
/// Uses static data instead of Store for deterministic snapshots.
public struct RecordingViewPreview: View {
    public enum ContentState: Equatable {
        case listening
        case starting
        case paused
        case error(String)
        case permissionDenied(String)
        case liveSegments([LiveSegmentData])
        case transcriptionUnavailable(message: String?)
        case processingError(segments: [LiveSegmentData])
    }

    private let elapsedTime: String
    private let isRecording: Bool
    private let isPaused: Bool
    private let contentState: ContentState
    private let headerStatus: RecordingHeaderStatus?
    private let speakerSetup: SpeakerSetupState

    public init(
        elapsedTime: String = "00:00",
        isRecording: Bool = true,
        isPaused: Bool = false,
        contentState: ContentState = .listening,
        headerStatus: RecordingHeaderStatus? = nil,
        speakerSetup: SpeakerSetupState = .closed
    ) {
        self.elapsedTime = elapsedTime
        self.isRecording = isRecording
        self.isPaused = isPaused
        self.contentState = contentState
        self.headerStatus = headerStatus
        self.speakerSetup = speakerSetup
    }

    private var effectiveHeaderStatus: RecordingHeaderStatus {
        if let headerStatus = headerStatus {
            return headerStatus
        }
        switch contentState {
        case .paused:
            return .paused
        case .processingError:
            return .processingFailed
        case .transcriptionUnavailable:
            return .transcriptionUnavailable
        default:
            return .recording
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Nav header
            HStack {
                NavButton(label: "Back") {}
                Spacer()
                Avatar(size: .large)
            }
            .padding(.top, 56)
            .padding(.horizontal, VaporSpacing.lg)
            .padding(.bottom, VaporSpacing.md)

            // Recording header (non-animated)
            RecordingHeaderPreview(elapsedTime: elapsedTime, status: effectiveHeaderStatus)

            // Content area
            switch contentState {
            case .listening:
                VStack {
                    Spacer()
                    Text("Listening...")
                        .font(.system(size: 24, weight: .thin))
                        .tracking(1)
                        .foregroundColor(VaporColor.textTertiary)
                    Spacer()
                }

            case .starting:
                VStack {
                    Spacer()
                    Text("Starting...")
                        .font(.system(size: 24, weight: .thin))
                        .tracking(1)
                        .foregroundColor(VaporColor.textTertiary)
                    Spacer()
                }

            case .paused:
                VStack {
                    Spacer()
                    Text("Paused")
                        .font(.system(size: 24, weight: .thin))
                        .tracking(1)
                        .foregroundColor(VaporColor.textTertiary)
                    Spacer()
                }

            case .error(let message):
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(VaporColor.recording)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VaporSpacing.xl)
                    Spacer()
                }

            case .permissionDenied(let message):
                VStack(spacing: VaporSpacing.lg) {
                    Spacer()
                    Text(message)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(VaporColor.recording)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VaporSpacing.xl)

                    Text("Open Settings")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(VaporColor.cloud)
                        .padding(.horizontal, VaporSpacing.xl)
                        .padding(.vertical, VaporSpacing.md)
                        .background(VaporColor.sky)
                        .cornerRadius(VaporRadius.md)

                    Spacer()
                }

            case .liveSegments(let segments):
                ScrollView {
                    VStack(alignment: .leading, spacing: VaporSpacing.lg) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                            let isLastSegment = index == segments.count - 1
                            TranscriptSegmentPreview(
                                speaker: segment.speaker,
                                timestamp: segment.timestamp,
                                text: segment.text,
                                isActive: isLastSegment
                            )
                        }

                        // Show listening indicator at the end
                        TranscriptLiveIndicator()
                    }
                    .padding(.horizontal, VaporSpacing.lg)
                    .padding(.top, VaporSpacing.md)
                }

            case .transcriptionUnavailable(let message):
                VStack(spacing: VaporSpacing.sm) {
                    Spacer()
                    Text("Recording audio...")
                        .font(.system(size: 20, weight: .thin))
                        .tracking(1)
                        .foregroundColor(VaporColor.textSecondary)

                    Text("Live transcription unavailable")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(VaporColor.textTertiary)

                    if let message = message {
                        Text(message)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(VaporColor.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, VaporSpacing.xl)
                    } else {
                        Text("Transcription will run when recording stops")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(VaporColor.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, VaporSpacing.xl)
                    }
                    Spacer()
                }

            case .processingError(let segments):
                VStack(spacing: 0) {
                    // Show existing segments if any
                    if !segments.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: VaporSpacing.lg) {
                                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                                    TranscriptSegmentPreview(
                                        speaker: segment.speaker,
                                        timestamp: segment.timestamp,
                                        text: segment.text
                                    )
                                }
                            }
                            .padding(.horizontal, VaporSpacing.lg)
                            .padding(.top, VaporSpacing.md)
                        }
                        .frame(maxHeight: 200)
                    }

                    // Error state view
                    ErrorStateView(
                        type: .transcriptionFailed,
                        primaryLabel: "Retry Processing",
                        primaryAction: {},
                        secondaryLabel: "Save Without Transcript",
                        secondaryAction: {}
                    )

                    Spacer()
                }
            }

            // Speaker setup card (non-interactive)
            speakerSetupCardPreview
        }
        .background(VaporColor.mist)
    }

    @ViewBuilder
    private var speakerSetupCardPreview: some View {
        let cardBg = UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 16
        )

        switch speakerSetup {
        case .closed:
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 16))
                            .foregroundColor(VaporColor.textSecondary)
                        Text("Assign speakers & finish")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(VaporColor.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14))
                        .foregroundColor(VaporColor.textTertiary)
                }
                previewStopButton(enabled: false)
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(
                cardBg.fill(VaporColor.cloud)
                    .overlay(cardBg.strokeBorder(VaporColor.fog, lineWidth: 1))
                    .shadow(color: Color(hex: "#2D3748").opacity(0.063), radius: 16, x: 0, y: -4)
            )

        case .openUnselected:
            VStack(spacing: 16) {
                HStack {
                    Text("Who's speaking?")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(VaporColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(VaporColor.textTertiary)
                }
                Text("Pick a count, then tap to name them.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                previewPillRow(selected: nil)
                previewStopButton(enabled: false)
            }
            .padding(24)
            .background(
                cardBg.fill(VaporColor.cloud)
                    .overlay(cardBg.strokeBorder(VaporColor.fog, lineWidth: 1))
                    .shadow(color: Color(hex: "#2D3748").opacity(0.063), radius: 16, x: 0, y: -4)
            )

        case .openSelected(let count):
            VStack(spacing: 16) {
                HStack {
                    Text("Who's speaking?")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(VaporColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(VaporColor.textTertiary)
                }
                Text("Pick a count, then tap to name them.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                previewPillRow(selected: count)
                Rectangle().fill(VaporColor.fog).frame(height: 1)
                previewSpeakerNames(count: count)
                previewStopButton(enabled: true)
            }
            .padding(24)
            .background(
                cardBg.fill(VaporColor.cloud)
                    .overlay(cardBg.strokeBorder(VaporColor.fog, lineWidth: 1))
                    .shadow(color: Color(hex: "#2D3748").opacity(0.063), radius: 16, x: 0, y: -4)
            )
        }
    }

    private func previewPillRow(selected: Int?) -> some View {
        HStack(spacing: 8) {
            ForEach([1, 2, 3, 4], id: \.self) { count in
                let isSelected = selected == count
                let label = count == 4 ? "4+" : "\(count)"
                Text(label)
                    .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? VaporColor.cloud : VaporColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? VaporColor.sky : VaporColor.haze)
                    )
                    .overlay(
                        isSelected ? nil :
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(VaporColor.fog, lineWidth: 1)
                    )
            }
        }
    }

    private func previewSpeakerNames(count: Int) -> some View {
        VStack(spacing: 10) {
            Text("Speakers")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(VaporColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<count, id: \.self) { index in
                let color = SpeakerColor.forIndex(index).color
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text("Speaker \(index + 1)")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(VaporColor.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(VaporColor.textTertiary)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(VaporColor.haze)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(VaporColor.fog, lineWidth: 1)
                )
            }
        }
    }

    private func previewStopButton(enabled: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(enabled ? VaporColor.cloud : VaporColor.textTertiary)
                .frame(width: 12, height: 12)
            Text("Stop & Save")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(enabled ? VaporColor.cloud : VaporColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(enabled ? VaporColor.recording : VaporColor.fog)
        )
        .opacity(enabled ? 1.0 : 0.5)
    }
}

// MARK: - Previews

// MARK: - Recording View Modifiers

private extension View {
    func discardAlert(store: StoreOf<RecordingFeature>) -> some View {
        self.alert(
            "Discard Recording?",
            isPresented: .dismiss(store.isShowingDiscardConfirmation) { store.send(.discardCancelled) }
        ) {
            Button("Cancel", role: .cancel) {
                store.send(.discardCancelled)
            }
            Button("Discard", role: .destructive) {
                store.send(.discardConfirmed)
            }
        } message: {
            Text("This will permanently delete the recording and all transcript data.")
        }
    }

    func errorAlert(
        store: StoreOf<RecordingFeature>,
        alertButton: @escaping (AlertInfo.AlertButton) -> Alert.Button
    ) -> some View {
        self.alert(
            item: .onNilDismiss(store.alertInfo) { store.send(.alertDismissed) }
        ) { alertInfo in
            Alert(
                title: Text(alertInfo.title),
                message: Text(alertInfo.message),
                primaryButton: alertButton(alertInfo.primaryButton),
                secondaryButton: alertInfo.secondaryButton.map { alertButton($0) } ?? .cancel()
            )
        }
    }

    func actionsMenu(
        store: StoreOf<RecordingFeature>,
        privacyModeLabel: @escaping (AudioRetentionMode) -> String
    ) -> some View {
        self.confirmationDialog(
            "Recording Options",
            isPresented: .dismiss(store.isShowingActionsMenu) { store.send(.actionsMenuDismissed) },
            titleVisibility: .visible
        ) {
            Button(privacyModeLabel(.both)) {
                store.send(.setAudioRetentionMode(.both))
            }
            Button(privacyModeLabel(.transcriptOnly)) {
                store.send(.setAudioRetentionMode(.transcriptOnly))
            }
            Button(privacyModeLabel(.audioOnly)) {
                store.send(.setAudioRetentionMode(.audioOnly))
            }
            Button("Discard Recording", role: .destructive) {
                store.send(.discardTapped)
            }
            Button("Cancel", role: .cancel) {
                store.send(.actionsMenuDismissed)
            }
        }
    }

    #if os(iOS)
    func speakerPickerModal<Content: View>(
        store: Bindable<StoreOf<RecordingFeature>>,
        @ViewBuilder sheetContent: @escaping (StoreOf<SpeakerPickerFeature>) -> Content
    ) -> some View {
        self.fullScreenCover(
            item: store.scope(state: \.speakerPicker, action: \.speakerPicker)
        ) { speakerPickerStore in
            sheetContent(speakerPickerStore)
        }
    }
    #else
    func speakerPickerModal<Content: View>(
        store: Bindable<StoreOf<RecordingFeature>>,
        @ViewBuilder sheetContent: @escaping (StoreOf<SpeakerPickerFeature>) -> Content
    ) -> some View {
        // macOS doesn't support fullScreenCover; use sheet instead
        self.sheet(
            item: store.scope(state: \.speakerPicker, action: \.speakerPicker)
        ) { speakerPickerStore in
            sheetContent(speakerPickerStore)
        }
    }
    #endif
}

#if DEBUG
struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingViewPreview(
            elapsedTime: "00:02",
            isRecording: true,
            contentState: .listening
        )
    }
}
#endif
