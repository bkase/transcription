import SwiftUI

// MARK: - Audio Player

/// Floating audio player with glass morphism style.
/// Shows play/pause button, title, progress bar, and time.
public struct AudioPlayer: View {
    /// The current playback state
    public enum PlayState {
        case playing
        case paused
    }

    private let title: String
    private let currentTime: String
    private let progress: Double  // 0.0 to 1.0
    private let playState: PlayState
    private let onPlayPause: () -> Void

    public init(
        title: String,
        currentTime: String,
        progress: Double = 0.0,
        playState: PlayState = .paused,
        onPlayPause: @escaping () -> Void
    ) {
        self.title = title
        self.currentTime = currentTime
        self.progress = max(0, min(1, progress))
        self.playState = playState
        self.onPlayPause = onPlayPause
    }

    public var body: some View {
        HStack(spacing: VaporSpacing.md) {
            // Play/Pause button
            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(VaporColor.haze)
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                    Image(systemName: playState == .playing ? "pause" : "play.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(VaporColor.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Title and progress
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VaporColor.fog)
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(VaporColor.sky)
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
            }

            // Current time
            Text(currentTime)
                .font(.system(size: 10, weight: .light))
                .tracking(0.5)
                .foregroundColor(VaporColor.textTertiary)
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .background(
            RoundedRectangle(cornerRadius: VaporRadius.md)
                .fill(Color.white.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: VaporRadius.md)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VaporRadius.md)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 2)
        )
    }
}

/// Non-interactive preview variant for snapshot testing
public struct AudioPlayerPreview: View {
    private let title: String
    private let currentTime: String
    private let progress: Double
    private let isPlaying: Bool

    public init(
        title: String,
        currentTime: String,
        progress: Double = 0.0,
        isPlaying: Bool = false
    ) {
        self.title = title
        self.currentTime = currentTime
        self.progress = max(0, min(1, progress))
        self.isPlaying = isPlaying
    }

    public var body: some View {
        HStack(spacing: VaporSpacing.md) {
            // Play/Pause button (non-interactive)
            ZStack {
                Circle()
                    .fill(VaporColor.haze)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                Image(systemName: isPlaying ? "pause" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VaporColor.textSecondary)
            }

            // Title and progress
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VaporColor.fog)
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(VaporColor.sky)
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
            }

            // Current time
            Text(currentTime)
                .font(.system(size: 10, weight: .light))
                .tracking(0.5)
                .foregroundColor(VaporColor.textTertiary)
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .background(
            RoundedRectangle(cornerRadius: VaporRadius.md)
                .fill(Color.white.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: VaporRadius.md)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VaporRadius.md)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 2)
        )
    }
}

// MARK: - Recording Header

/// Recording header bar with status indicator and timer.
/// Shows recording dot, "RECORDING" label, and elapsed time.
public struct RecordingHeader: View {
    private let elapsedTime: String

    /// Breathing animation for the recording dot
    @State private var dotOpacity: Double = 1.0

    public init(elapsedTime: String) {
        self.elapsedTime = elapsedTime
    }

    public var body: some View {
        HStack {
            // Recording status
            HStack(spacing: 12) {
                Circle()
                    .fill(VaporColor.recording)
                    .frame(width: 8, height: 8)
                    .opacity(dotOpacity)
                    .onAppear {
                        startBreathingAnimation()
                    }

                Text("RECORDING")
                    .font(.system(size: 14, weight: .light))
                    .tracking(2)
                    .foregroundColor(VaporColor.recording)
            }

            Spacer()

            // Timer
            Text(elapsedTime)
                .font(.system(size: 20, weight: .light))
                .tracking(2)
                .foregroundColor(VaporColor.textPrimary)
                .opacity(0.8)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            Rectangle()
                .fill(Color(hex: "#F7FAFC").opacity(0.8))
                .background(.ultraThinMaterial)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(VaporColor.fog.opacity(0.5))
                            .frame(height: 1)
                    }
                )
        )
    }

    private func startBreathingAnimation() {
        withAnimation(
            VaporAnimation.breatheCurve.animation(duration: VaporAnimation.breatheDuration)
                .repeatForever(autoreverses: true)
        ) {
            dotOpacity = 0.4
        }
    }
}

/// Non-interactive preview variant for snapshot testing (no animations)
public struct RecordingHeaderPreview: View {
    private let elapsedTime: String
    private let dotOpacity: Double

    public init(elapsedTime: String, dotOpacity: Double = 1.0) {
        self.elapsedTime = elapsedTime
        self.dotOpacity = dotOpacity
    }

    public var body: some View {
        HStack {
            // Recording status
            HStack(spacing: 12) {
                Circle()
                    .fill(VaporColor.recording)
                    .frame(width: 8, height: 8)
                    .opacity(dotOpacity)

                Text("RECORDING")
                    .font(.system(size: 14, weight: .light))
                    .tracking(2)
                    .foregroundColor(VaporColor.recording)
            }

            Spacer()

            // Timer
            Text(elapsedTime)
                .font(.system(size: 20, weight: .light))
                .tracking(2)
                .foregroundColor(VaporColor.textPrimary)
                .opacity(0.8)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            Rectangle()
                .fill(Color(hex: "#F7FAFC").opacity(0.8))
                .background(.ultraThinMaterial)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(VaporColor.fog.opacity(0.5))
                            .frame(height: 1)
                    }
                )
        )
    }
}

// MARK: - Previews

#if DEBUG
struct AudioPlayer_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            AudioPlayerPreview(
                title: "Playing Audio",
                currentTime: "12:40",
                progress: 0.3,
                isPlaying: true
            )

            AudioPlayerPreview(
                title: "Architecture Review",
                currentTime: "5:22",
                progress: 0.6,
                isPlaying: false
            )
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct RecordingHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            RecordingHeaderPreview(elapsedTime: "00:02")
            RecordingHeaderPreview(elapsedTime: "05:32")
            RecordingHeaderPreview(elapsedTime: "1:23:45")
        }
        .background(VaporColor.mist)
    }
}
#endif
