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

    private var contentArea: some View {
        VStack {
            Spacer()

            if store.isListening {
                listeningIndicator
            } else if store.isRecording {
                // Recording in progress, waiting for audio...
                Text("Starting...")
                    .font(.system(size: 24, weight: .thin))
                    .tracking(1)
                    .foregroundColor(VaporColor.textTertiary)
            } else if let error = store.error {
                // Error state
                Text(error)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(VaporColor.recording)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VaporSpacing.xl)
            }

            Spacer()
        }
    }

    private var listeningIndicator: some View {
        Text("Listening...")
            .font(.system(size: 24, weight: .thin))
            .tracking(1)
            .foregroundColor(VaporColor.textTertiary)
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack {
            // Pause button (left)
            IconButton(systemName: "pause", style: .transparent, iconColor: VaporColor.sky) {
                // Pause action - not implemented yet
            }

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

/// Non-interactive preview variant for snapshot testing.
/// Uses static data instead of Store for deterministic snapshots.
public struct RecordingViewPreview: View {
    public enum ContentState {
        case listening
        case starting
        case error(String)
    }

    private let elapsedTime: String
    private let isRecording: Bool
    private let contentState: ContentState

    public init(
        elapsedTime: String = "00:00",
        isRecording: Bool = true,
        contentState: ContentState = .listening
    ) {
        self.elapsedTime = elapsedTime
        self.isRecording = isRecording
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
            VStack {
                Spacer()

                switch contentState {
                case .listening:
                    Text("Listening...")
                        .font(.system(size: 24, weight: .thin))
                        .tracking(1)
                        .foregroundColor(VaporColor.textTertiary)

                case .starting:
                    Text("Starting...")
                        .font(.system(size: 24, weight: .thin))
                        .tracking(1)
                        .foregroundColor(VaporColor.textTertiary)

                case .error(let message):
                    Text(message)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(VaporColor.recording)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VaporSpacing.xl)
                }

                Spacer()
            }

            // Controls bar (non-interactive)
            HStack {
                // Pause button
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)

                    Image(systemName: "pause")
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
