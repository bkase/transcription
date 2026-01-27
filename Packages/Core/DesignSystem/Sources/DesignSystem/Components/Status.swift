import SwiftUI

// MARK: - Status Banner Types

/// Status type for banner variants
public enum StatusBannerType: Equatable, Sendable {
    case downloadError
    case connectionError
    case processingError
    case custom(icon: String, title: String, description: String)

    var icon: String {
        switch self {
        case .downloadError:
            return "exclamationmark.circle"
        case .connectionError:
            return "wifi.slash"
        case .processingError:
            return "xmark.circle"
        case .custom(let icon, _, _):
            return icon
        }
    }

    var title: String {
        switch self {
        case .downloadError:
            return "Download failed"
        case .connectionError:
            return "No connection"
        case .processingError:
            return "Processing failed"
        case .custom(_, let title, _):
            return title
        }
    }

    var description: String {
        switch self {
        case .downloadError:
            return "Could not download speech models"
        case .connectionError:
            return "Check your internet and try again"
        case .processingError:
            return "Could not process the recording"
        case .custom(_, _, let description):
            return description
        }
    }
}

// MARK: - Status Banner Colors

private enum StatusBannerColors {
    static let background = Color(hex: "#FEF2F2")
    static let icon = VaporColor.recording
    static let titleText = Color(hex: "#991B1B")
    static let descriptionText = Color(hex: "#B91C1C")
    static let retryBackground = Color(hex: "#FEE2E2")
}

// MARK: - Status Banner

/// Full-width error banner with icon, title, description, and optional retry button.
/// Used for critical errors that require user attention (e.g., download failed, no connection).
public struct StatusBanner: View {
    private let type: StatusBannerType
    private let retryAction: (() -> Void)?

    public init(type: StatusBannerType, onRetry: (() -> Void)? = nil) {
        self.type = type
        self.retryAction = onRetry
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Left side: icon + text
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(StatusBannerColors.icon)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(StatusBannerColors.titleText)

                    Text(type.description)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(StatusBannerColors.descriptionText)
                }
            }

            Spacer()

            // Right side: retry button (if action provided)
            if let action = retryAction {
                Button(action: action) {
                    Text("Retry")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(StatusBannerColors.titleText)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(StatusBannerColors.retryBackground)
                )
                .accessibilityIdentifier("statusBannerRetry")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(StatusBannerColors.background)
        .accessibilityIdentifier("statusBanner")
    }
}

// MARK: - Status Pill Type

/// Status type for pill variants
public enum StatusPillType: Equatable, Sendable {
    case downloading
    case transcribing
    case partial
    case failed
    case ready

    var icon: String {
        switch self {
        case .downloading:
            return "icloud.and.arrow.down"
        case .transcribing:
            return "waveform"
        case .partial:
            return "exclamationmark.triangle"
        case .failed:
            return "xmark.circle"
        case .ready:
            return "checkmark.circle"
        }
    }

    var label: String {
        switch self {
        case .downloading:
            return "Downloading"
        case .transcribing:
            return "Transcribing"
        case .partial:
            return "Partial"
        case .failed:
            return "Failed"
        case .ready:
            return "Ready"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .downloading, .transcribing:
            return VaporColor.textSecondary
        case .partial:
            return Color(hex: "#B45309") // amber-700
        case .failed:
            return VaporColor.recording
        case .ready:
            return VaporColor.success
        }
    }

    var backgroundColor: Color {
        switch self {
        case .downloading, .transcribing:
            return VaporColor.haze
        case .partial:
            return Color(hex: "#FEF3C7") // amber-100
        case .failed:
            return Color(hex: "#FEE2E2") // red-100
        case .ready:
            return Color(hex: "#DCFCE7") // green-100
        }
    }
}

// MARK: - Status Pill

/// Compact status indicator pill showing processing state.
/// Used inline with session cards or other list items.
public struct StatusPill: View {
    private let type: StatusPillType

    public init(type: StatusPillType) {
        self.type = type
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.system(size: 10))
                .foregroundColor(type.foregroundColor)

            Text(type.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(type.foregroundColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(type.backgroundColor)
        )
        .accessibilityIdentifier("statusPill_\(type.label.lowercased())")
    }
}

// MARK: - Error State Type

/// Error state variants for centered error displays
public enum ErrorStateType: Equatable, Sendable {
    case transcriptionFailed
    case transcriptionUnavailable
    case processingFailed
    case custom(icon: String, title: String, description: String)

    var icon: String {
        switch self {
        case .transcriptionFailed, .processingFailed:
            return "xmark.circle"
        case .transcriptionUnavailable:
            return "xmark.circle"
        case .custom(let icon, _, _):
            return icon
        }
    }

    var title: String {
        switch self {
        case .transcriptionFailed:
            return "Transcription failed"
        case .transcriptionUnavailable:
            return "Transcription unavailable"
        case .processingFailed:
            return "Processing failed"
        case .custom(_, let title, _):
            return title
        }
    }

    var description: String {
        switch self {
        case .transcriptionFailed:
            return "The audio was saved but couldn't be processed. You can retry or save without transcription."
        case .transcriptionUnavailable:
            return "This recording couldn't be transcribed. The audio file is still available to play."
        case .processingFailed:
            return "Something went wrong while processing. Please try again."
        case .custom(_, _, let description):
            return description
        }
    }
}

// MARK: - Error State View

/// Centered error state with icon, title, description, and optional CTA button.
/// Used in session detail, recording completion, and other full-screen error states.
public struct ErrorStateView: View {
    private let type: ErrorStateType
    private let primaryAction: (() -> Void)?
    private let primaryLabel: String?
    private let secondaryAction: (() -> Void)?
    private let secondaryLabel: String?

    public init(
        type: ErrorStateType,
        primaryLabel: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryLabel: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.type = type
        self.primaryLabel = primaryLabel
        self.primaryAction = primaryAction
        self.secondaryLabel = secondaryLabel
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: type.icon)
                .font(.system(size: 48))
                .foregroundColor(VaporColor.recording.opacity(0.6))

            // Title
            Text(type.title)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(VaporColor.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text(type.description)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textTertiary)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .frame(width: 260)

            // CTA buttons
            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: 12) {
                    if let action = primaryAction, let label = primaryLabel {
                        Button(action: action) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16))
                                Text(label)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(VaporColor.cloud)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(VaporColor.sky)
                        )
                        .accessibilityIdentifier("errorStatePrimaryButton")
                    }

                    if let action = secondaryAction, let label = secondaryLabel {
                        Button(action: action) {
                            Text(label)
                                .font(.system(size: 15))
                                .foregroundColor(VaporColor.textSecondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VaporColor.overcast, lineWidth: 1)
                        )
                        .accessibilityIdentifier("errorStateSecondaryButton")
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
        .accessibilityIdentifier("errorStateView")
    }
}

// MARK: - Processing Status Header

/// Inline processing status indicator used in recording/session headers.
/// Shows a dot + status label (e.g., "PROCESSING FAILED").
public struct ProcessingStatusIndicator: View {
    public enum Status: Equatable, Sendable {
        case recording
        case processing
        case processingFailed
        case partial

        var label: String {
            switch self {
            case .recording:
                return "RECORDING"
            case .processing:
                return "PROCESSING"
            case .processingFailed:
                return "PROCESSING FAILED"
            case .partial:
                return "PARTIAL TRANSCRIPT"
            }
        }

        var color: Color {
            switch self {
            case .recording, .processingFailed:
                return VaporColor.recording
            case .processing:
                return VaporColor.sky
            case .partial:
                return Color(hex: "#B45309") // amber-700
            }
        }
    }

    private let status: Status

    public init(status: Status) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            Text(status.label)
                .font(.system(size: 14, weight: .light))
                .tracking(2)
                .foregroundColor(status.color)
        }
        .accessibilityIdentifier("processingStatusIndicator")
    }
}

// MARK: - Previews

#if DEBUG
struct StatusBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            StatusBanner(type: .downloadError, onRetry: {})
            StatusBanner(type: .connectionError, onRetry: {})
            StatusBanner(type: .processingError, onRetry: {})
            StatusBanner(type: .downloadError) // No retry button
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct StatusPill_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            StatusPill(type: .downloading)
            StatusPill(type: .transcribing)
            StatusPill(type: .partial)
            StatusPill(type: .failed)
            StatusPill(type: .ready)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct ErrorStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            ErrorStateView(
                type: .transcriptionFailed,
                primaryLabel: "Retry Processing",
                primaryAction: {},
                secondaryLabel: "Save Without Transcript",
                secondaryAction: {}
            )

            ErrorStateView(
                type: .transcriptionUnavailable,
                primaryLabel: "Retry Transcription",
                primaryAction: {}
            )

            ErrorStateView(type: .processingFailed)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct ProcessingStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ProcessingStatusIndicator(status: .recording)
            ProcessingStatusIndicator(status: .processing)
            ProcessingStatusIndicator(status: .processingFailed)
            ProcessingStatusIndicator(status: .partial)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}
#endif
