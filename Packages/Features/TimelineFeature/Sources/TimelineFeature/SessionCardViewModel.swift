import DesignSystem
import Foundation
import Persistence

// MARK: - Session Card View Model

/// View model representing the data needed to render a SessionCard.
/// Maps from SessionRecord database model to presentation-ready values.
public struct SessionCardViewModel: Equatable, Sendable {
    public let title: String
    public let time: String
    public let previewText: String
    public let speakerCount: Int?
    public let duration: String?
    public let isTranscribed: Bool
    /// Optional status pill type for displaying session processing state
    public let statusPillType: StatusPillType?

    public init(
        title: String,
        time: String,
        previewText: String,
        speakerCount: Int?,
        duration: String?,
        isTranscribed: Bool,
        statusPillType: StatusPillType? = nil
    ) {
        self.title = title
        self.time = time
        self.previewText = previewText
        self.speakerCount = speakerCount
        self.duration = duration
        self.isTranscribed = isTranscribed
        self.statusPillType = statusPillType
    }
}

// MARK: - Mapping from SessionRecord

extension SessionCardViewModel {
    /// Create a view model from a database session record.
    /// - Parameters:
    ///   - session: The session record from the database.
    ///   - timeFormatter: Date formatter for formatting the session start time.
    /// - Returns: A view model ready for rendering.
    public static func from(
        session: SessionRecord,
        timeFormatter: DateFormatter = Self.defaultTimeFormatter
    ) -> SessionCardViewModel {
        SessionCardViewModel(
            title: session.title ?? "Untitled",
            time: timeFormatter.string(from: session.startedAt),
            previewText: session.previewText ?? "",
            speakerCount: session.speakerCount > 0 ? session.speakerCount : nil,
            duration: session.durationMs.map { formatDuration($0) },
            isTranscribed: session.processingState == .processed,
            statusPillType: statusPillType(for: session.processingState)
        )
    }

    /// Map processing state to status pill type.
    /// Returns nil for states that don't need a status indicator.
    private static func statusPillType(for state: ProcessingState) -> StatusPillType? {
        switch state {
        case .transcribing:
            return .transcribing
        case .partial:
            return .partial
        case .failed:
            return .failed
        case .processed, .recording:
            return nil
        }
    }

    /// Default time formatter using "h:mm a" format (e.g., "9:41 AM").
    public static var defaultTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    /// Format duration from milliseconds to a display string.
    /// - Parameter milliseconds: Duration in milliseconds.
    /// - Returns: Formatted string like "1:30" or "1:02:30" for longer durations.
    private static func formatDuration(_ milliseconds: Int) -> String {
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
}
