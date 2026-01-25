import ComposableArchitecture
import DesignSystem
import SwiftUI

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
        VStack(spacing: 0) {
            // Nav header
            navHeader

            // Recording header
            RecordingHeader(elapsedTime: formatElapsedTime(store.elapsedSeconds))

            // Main content area
            contentArea

            // Bottom controls
            controlsBar
        }
        .background(VaporColor.mist)
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    // MARK: - Nav Header

    private var navHeader: some View {
        HStack {
            NavButton(label: "Back", action: onBack)
            Spacer()
            Avatar(size: .large)
        }
        .padding(.top, 56)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.md)
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
            VStack {
                Spacer()
                listeningIndicator
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

    private var liveTranscriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: VaporSpacing.lg) {
                    ForEach(store.liveSegments, id: \.id) { segment in
                        TranscriptSegment(
                            speaker: speakerType(for: segment),
                            timestamp: formatTimestamp(segment.startMs),
                            text: segment.text
                        )
                        .id(segment.id)
                    }

                    // Show listening indicator at the end when recording
                    if store.isListening {
                        TranscriptLiveIndicator()
                            .id("live-indicator")
                    }
                }
                .padding(.horizontal, VaporSpacing.lg)
                .padding(.top, VaporSpacing.md)
            }
            .onChange(of: store.liveSegments.count) { _, _ in
                // Auto-scroll to bottom when new segments arrive
                if let lastSegment = store.liveSegments.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastSegment.id, anchor: .bottom)
                    }
                }
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

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack {
            // Pause/Resume button (left)
            IconButton(
                systemName: store.isPaused ? "play.fill" : "pause",
                style: .transparent,
                iconColor: VaporColor.sky
            ) {
                if store.isPaused {
                    store.send(.resumeRecording)
                } else {
                    store.send(.pauseRecording)
                }
            }
            .accessibilityIdentifier(store.isPaused ? "resumeButton" : "pauseButton")

            Spacer()

            // Stop button (center)
            RecordButton(isRecording: store.isRecording, size: .large) {
                store.send(.stopRecording)
            }

            Spacer()

            // More button (right)
            IconButton(systemName: "ellipsis", style: .transparent, iconColor: VaporColor.textSecondary) {
                // More action - not implemented yet
            }
        }
        .padding(.horizontal, VaporSpacing.xl)
        .padding(.bottom, VaporSpacing.xl)
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
    }

    private let elapsedTime: String
    private let isRecording: Bool
    private let isPaused: Bool
    private let contentState: ContentState

    public init(
        elapsedTime: String = "00:00",
        isRecording: Bool = true,
        isPaused: Bool = false,
        contentState: ContentState = .listening
    ) {
        self.elapsedTime = elapsedTime
        self.isRecording = isRecording
        self.isPaused = isPaused
        self.contentState = contentState
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
            RecordingHeaderPreview(elapsedTime: elapsedTime)

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
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            TranscriptSegmentPreview(
                                speaker: segment.speaker,
                                timestamp: segment.timestamp,
                                text: segment.text
                            )
                        }

                        // Show listening indicator at the end
                        TranscriptLiveIndicator()
                    }
                    .padding(.horizontal, VaporSpacing.lg)
                    .padding(.top, VaporSpacing.md)
                }
            }

            // Controls bar (non-interactive)
            HStack {
                // Pause/Resume button
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)

                    Image(systemName: isPaused ? "play.fill" : "pause")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(VaporColor.sky)
                }

                Spacer()

                // Stop button (static, no animation)
                ZStack {
                    Circle()
                        .fill(VaporColor.cloud)
                        .frame(width: 112, height: 112)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isRecording ? Color(hex: "#FFF5F5") : VaporColor.fog,
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isRecording
                                ? VaporColor.recording.opacity(0.2)
                                : Color.black.opacity(0.06),
                            radius: isRecording ? 24 : 16,
                            x: 0,
                            y: 4
                        )

                    if isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(VaporColor.recording.opacity(0.8))
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(VaporColor.recording.opacity(0.6))
                            .frame(width: 16, height: 16)
                    }
                }

                Spacer()

                // More button
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)

                    Image(systemName: "ellipsis")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(VaporColor.textSecondary)
                }
            }
            .padding(.horizontal, VaporSpacing.xl)
            .padding(.bottom, VaporSpacing.xl)
        }
        .background(VaporColor.mist)
    }
}

// MARK: - Previews

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
