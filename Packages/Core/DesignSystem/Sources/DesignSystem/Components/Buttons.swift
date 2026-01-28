import SwiftUI

// MARK: - Record Button

/// Recording button with idle, recording, and disabled states.
/// - Idle: White circle with red dot (12pt)
/// - Recording: White circle with rounded red square (24pt), breathing animation
/// - Disabled: Haze background with overcast dot at 0.4 opacity, softened shadow
public struct RecordButton: View {
    public enum Size {
        case regular  // 72pt
        case large    // 112pt

        var diameter: CGFloat {
            switch self {
            case .regular: return 72
            case .large: return 112
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .regular: return 24
            case .large: return 32
            }
        }

        var idleDotSize: CGFloat {
            switch self {
            case .regular: return 12
            case .large: return 16
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .regular: return 4
            case .large: return 6
            }
        }
    }

    private let isRecording: Bool
    private let isEnabled: Bool
    private let size: Size
    private let action: () -> Void

    @State private var breatheScale: CGFloat = 0.98

    public init(
        isRecording: Bool,
        isEnabled: Bool = true,
        size: Size = .regular,
        action: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self.isEnabled = isEnabled
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                Circle()
                    .fill(isEnabled ? VaporColor.cloud : VaporColor.haze)
                    .frame(width: size.diameter, height: size.diameter)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isEnabled && isRecording ? Color(hex: "#FFF5F5") : VaporColor.fog,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: !isEnabled
                            ? Color.black.opacity(0.04)
                            : (isRecording
                                ? VaporColor.recording.opacity(0.2)
                                : Color.black.opacity(0.06)),
                        radius: !isEnabled ? 8 : (isRecording ? 24 : 16),
                        x: 0,
                        y: !isEnabled ? 2 : 4
                    )

                // Icon
                if isEnabled && isRecording {
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(VaporColor.recording.opacity(0.8))
                        .frame(width: size.iconSize, height: size.iconSize)
                        .scaleEffect(breatheScale)
                } else {
                    Circle()
                        .fill(isEnabled ? VaporColor.recording.opacity(0.6) : VaporColor.overcast.opacity(0.4))
                        .frame(width: size.idleDotSize, height: size.idleDotSize)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .accessibilityIdentifier(isRecording ? "stopRecordingButton" : "startRecordingButton")
        .accessibilityLabel(isRecording ? "Stop Recording" : "Start Recording")
        .onChange(of: isRecording) { _, newValue in
            if newValue && isEnabled {
                startBreathingAnimation()
            } else {
                // Use exit curve to smoothly transition to final scale
                withAnimation(VaporAnimation.exitCurve.animation(duration: VaporAnimation.normalDuration)) {
                    breatheScale = 1.0
                }
            }
        }
        .onAppear {
            if isRecording && isEnabled {
                startBreathingAnimation()
            }
        }
    }

    private func startBreathingAnimation() {
        // Reset to animation start value first
        breatheScale = 0.98
        withAnimation(
            VaporAnimation.breatheCurve.animation(duration: VaporAnimation.breatheDuration)
                .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.02
        }
    }
}

// MARK: - Icon Button

/// Circular icon button with transparent or filled background.
/// Used for secondary actions like pause, more options, etc.
public struct IconButton: View {
    public enum Style {
        case transparent  // No background, icon only
        case filled       // Cloud background with shadow (hover/active state)
    }

    private let systemName: String
    private let style: Style
    private let iconColor: Color
    private let action: () -> Void

    public init(
        systemName: String,
        style: Style = .transparent,
        iconColor: Color = VaporColor.sky,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.style = style
        self.iconColor = iconColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(style == .filled ? VaporColor.cloud : Color.clear)
                    .frame(width: 40, height: 40)
                    .shadow(
                        color: style == .filled ? Color.black.opacity(0.08) : Color.clear,
                        radius: style == .filled ? 8 : 0,
                        x: 0,
                        y: 2
                    )

                Image(systemName: systemName)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Nav Button

/// Navigation back button with chevron icon and label.
/// Uses secondary text color for subtle appearance.
public struct NavButton: View {
    private let label: String
    private let action: () -> Void

    public init(label: String = "Back", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: VaporSpacing.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)

                Text(label)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }
            .padding(VaporSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("backButton")
        .accessibilityLabel(label)
    }
}

// MARK: - Previews

#if DEBUG
struct RecordButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            RecordButton(isRecording: false) {}
            RecordButton(isRecording: true) {}
            RecordButton(isRecording: true, size: .large) {}
            RecordButton(isRecording: false, isEnabled: false) {}
            RecordButton(isRecording: false, isEnabled: false, size: .large) {}
        }
        .padding()
        .background(VaporColor.mist)
    }
}

struct IconButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            IconButton(systemName: "pause", style: .transparent) {}
            IconButton(systemName: "ellipsis", style: .filled, iconColor: VaporColor.textSecondary) {}
        }
        .padding()
        .background(VaporColor.mist)
    }
}

struct NavButton_Previews: PreviewProvider {
    static var previews: some View {
        NavButton(label: "Back") {}
            .padding()
            .background(VaporColor.mist)
    }
}
#endif
