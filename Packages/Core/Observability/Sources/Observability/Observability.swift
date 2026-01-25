import Foundation
import Dependencies
import DependenciesMacros

// MARK: - TraceID

/// A unique identifier for tracing operations across the system.
/// TraceIDs propagate through async boundaries to correlate logs.
public struct TraceID: Sendable, Equatable, Hashable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a new unique trace ID.
    public static func generate() -> TraceID {
        TraceID(UUID().uuidString)
    }

    public var description: String { rawValue }
}

// MARK: - LogLevel

/// Severity level for log entries.
public enum LogLevel: String, Sendable, Equatable, Comparable {
    case debug
    case info
    case warning
    case error

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - LogEntry

/// A structured log entry with trace context and optional metadata.
public struct LogEntry: Sendable, Equatable {
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let traceId: TraceID?
    public let sessionId: String?
    public let event: String?
    public let latencyMs: Int?
    public let metadata: [String: String]

    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        message: String,
        traceId: TraceID? = nil,
        sessionId: String? = nil,
        event: String? = nil,
        latencyMs: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.traceId = traceId
        self.sessionId = sessionId
        self.event = event
        self.latencyMs = latencyMs
        self.metadata = metadata
    }
}

// MARK: - LoggingClient

/// Dependency client for structured logging with trace ID propagation.
@DependencyClient
public struct LoggingClient: Sendable {
    /// Log a structured entry.
    public var log: @Sendable (_ entry: LogEntry) async -> Void

    /// Get the current trace ID for propagation.
    public var currentTraceId: @Sendable () async -> TraceID? = { nil }

    /// Set or update the current trace ID.
    public var setTraceId: @Sendable (_ traceId: TraceID?) async -> Void

    /// Create a new trace ID and set it as current.
    public var startTrace: @Sendable () async -> TraceID = { TraceID.generate() }

    /// Clear the current trace ID.
    public var endTrace: @Sendable () async -> Void
}

// MARK: - Live Implementation

/// Actor to manage trace ID state in a thread-safe manner.
private actor TraceContext {
    private var currentTraceId: TraceID?

    func getTraceId() -> TraceID? {
        currentTraceId
    }

    func setTraceId(_ traceId: TraceID?) {
        currentTraceId = traceId
    }

    func startTrace() -> TraceID {
        let traceId = TraceID.generate()
        currentTraceId = traceId
        return traceId
    }

    func endTrace() {
        currentTraceId = nil
    }
}

extension LoggingClient {
    /// Creates a live logging client that outputs to os_log.
    public static func live() -> LoggingClient {
        let context = TraceContext()

        return LoggingClient(
            log: { entry in
                // Format the log entry
                var components: [String] = []

                if let traceId = entry.traceId {
                    components.append("[\(traceId.rawValue)]")
                }

                if let sessionId = entry.sessionId {
                    components.append("session:\(sessionId)")
                }

                if let event = entry.event {
                    components.append("event:\(event)")
                }

                components.append(entry.message)

                if let latencyMs = entry.latencyMs {
                    components.append("(\(latencyMs)ms)")
                }

                if !entry.metadata.isEmpty {
                    let metaStr = entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                    components.append("{\(metaStr)}")
                }

                let formattedMessage = components.joined(separator: " ")

                // In production, this would use os_log
                // For now, we print with level prefix for testing
                print("[\(entry.level.rawValue.uppercased())] \(formattedMessage)")
            },
            currentTraceId: {
                await context.getTraceId()
            },
            setTraceId: { traceId in
                await context.setTraceId(traceId)
            },
            startTrace: {
                await context.startTrace()
            },
            endTrace: {
                await context.endTrace()
            }
        )
    }
}

extension LoggingClient: DependencyKey {
    public static let liveValue = LoggingClient.live()
    public static let testValue = LoggingClient()
}

extension DependencyValues {
    public var loggingClient: LoggingClient {
        get { self[LoggingClient.self] }
        set { self[LoggingClient.self] = newValue }
    }
}

// MARK: - ErrorCode

/// Internal error codes for categorizing failures.
/// These codes are stable and can be used for debugging and analytics.
public enum ErrorCode: String, Sendable, Equatable {
    // Database errors
    case databaseRead = "DB_READ"
    case databaseWrite = "DB_WRITE"
    case databaseMigration = "DB_MIGRATION"

    // Audio errors
    case audioCaptureFailed = "AUDIO_CAPTURE"
    case audioFileWriteFailed = "AUDIO_FILE_WRITE"
    case audioPermissionDenied = "AUDIO_PERMISSION"

    // ML errors
    case mlModelLoad = "ML_MODEL_LOAD"
    case mlTranscription = "ML_TRANSCRIPTION"
    case mlDiarization = "ML_DIARIZATION"

    // Recording errors
    case recordingStart = "RECORDING_START"
    case recordingInterrupted = "RECORDING_INTERRUPTED"
    case recordingFinalization = "RECORDING_FINALIZE"

    // Session errors
    case sessionLoad = "SESSION_LOAD"
    case sessionNotFound = "SESSION_NOT_FOUND"

    // Export errors
    case exportFailed = "EXPORT_FAILED"

    // Network errors (future)
    case networkTimeout = "NETWORK_TIMEOUT"
    case networkOffline = "NETWORK_OFFLINE"

    // Generic errors
    case unknown = "UNKNOWN"
}

// MARK: - RecoveryAction

/// Suggested recovery actions that features can offer to users.
public enum RecoveryAction: String, Sendable, Equatable {
    /// Retry the failed operation.
    case retry

    /// Retry the finalization step for a recording.
    case retryFinalize

    /// Keep the partial/incomplete data.
    case keepPartial

    /// Delete the session and associated data.
    case deleteSession

    /// Open app settings (e.g., for permissions).
    case openSettings

    /// Dismiss the error and continue.
    case dismiss
}

// MARK: - ErrorEnvelope

/// A typed error envelope with user-facing message, internal code, and recovery options.
/// All failures in the app should propagate as ErrorEnvelope for consistent handling.
public struct ErrorEnvelope: Error, Sendable, Equatable {
    /// The internal error code for categorization and debugging.
    public let code: ErrorCode

    /// A user-facing message describing what went wrong.
    public let userMessage: String

    /// The trace ID from when the error occurred, for debugging.
    public let traceId: TraceID?

    /// The session ID if the error is related to a specific session.
    public let sessionId: String?

    /// Optional recovery actions the user can take.
    public let recoveryActions: [RecoveryAction]

    /// The underlying error, if any.
    public let underlyingError: String?

    /// Timestamp when the error occurred.
    public let timestamp: Date

    public init(
        code: ErrorCode,
        userMessage: String,
        traceId: TraceID? = nil,
        sessionId: String? = nil,
        recoveryActions: [RecoveryAction] = [.dismiss],
        underlyingError: String? = nil,
        timestamp: Date = Date()
    ) {
        self.code = code
        self.userMessage = userMessage
        self.traceId = traceId
        self.sessionId = sessionId
        self.recoveryActions = recoveryActions
        self.underlyingError = underlyingError
        self.timestamp = timestamp
    }
}

// MARK: - ErrorEnvelope Factories

extension ErrorEnvelope {
    /// Create an error envelope for database read failures.
    public static func databaseRead(
        message: String = "Unable to load data. Please try again.",
        traceId: TraceID? = nil,
        sessionId: String? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .databaseRead,
            userMessage: message,
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: [.retry, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope for database write failures.
    public static func databaseWrite(
        message: String = "Unable to save data. Please try again.",
        traceId: TraceID? = nil,
        sessionId: String? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .databaseWrite,
            userMessage: message,
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: [.retry, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope for audio capture failures.
    public static func audioCapture(
        message: String = "Unable to access the microphone.",
        traceId: TraceID? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .audioCaptureFailed,
            userMessage: message,
            traceId: traceId,
            recoveryActions: [.openSettings, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope for recording start failures.
    public static func recordingStart(
        message: String = "Unable to start recording. Please try again.",
        traceId: TraceID? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .recordingStart,
            userMessage: message,
            traceId: traceId,
            recoveryActions: [.retry, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope for interrupted recordings.
    public static func recordingInterrupted(
        sessionId: String,
        message: String = "Recording was interrupted. You can keep the partial recording or delete it.",
        traceId: TraceID? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .recordingInterrupted,
            userMessage: message,
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: [.keepPartial, .deleteSession, .dismiss]
        )
    }

    /// Create an error envelope for recording finalization failures.
    public static func recordingFinalization(
        sessionId: String,
        message: String = "Unable to finish processing the recording. Retry or keep the partial data.",
        traceId: TraceID? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .recordingFinalization,
            userMessage: message,
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: [.retryFinalize, .keepPartial, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope for session load failures.
    public static func sessionLoad(
        sessionId: String? = nil,
        message: String = "Unable to load the session.",
        traceId: TraceID? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .sessionLoad,
            userMessage: message,
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: [.retry, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope for ML/transcription failures.
    public static func transcription(
        message: String = "Transcription failed. The recording is saved.",
        traceId: TraceID? = nil,
        sessionId: String? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .mlTranscription,
            userMessage: message,
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: [.retry, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope for export failures.
    public static func exportFailed(
        message: String = "Unable to export the session.",
        traceId: TraceID? = nil,
        sessionId: String? = nil,
        underlyingError: Error? = nil
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: .exportFailed,
            userMessage: message,
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: [.retry, .dismiss],
            underlyingError: underlyingError?.localizedDescription
        )
    }

    /// Create an error envelope from any error with default handling.
    public static func from(
        _ error: Error,
        code: ErrorCode = .unknown,
        userMessage: String? = nil,
        traceId: TraceID? = nil,
        sessionId: String? = nil,
        recoveryActions: [RecoveryAction] = [.dismiss]
    ) -> ErrorEnvelope {
        ErrorEnvelope(
            code: code,
            userMessage: userMessage ?? "An unexpected error occurred.",
            traceId: traceId,
            sessionId: sessionId,
            recoveryActions: recoveryActions,
            underlyingError: error.localizedDescription
        )
    }
}

// MARK: - AlertInfo

/// Information for displaying an error as a SwiftUI alert.
public struct AlertInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let message: String
    public let primaryButton: AlertButton
    public let secondaryButton: AlertButton?

    public init(
        id: String = UUID().uuidString,
        title: String,
        message: String,
        primaryButton: AlertButton,
        secondaryButton: AlertButton? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }

    /// A button in an alert.
    public struct AlertButton: Sendable, Equatable {
        public let title: String
        public let action: RecoveryAction
        public let isDestructive: Bool

        public init(title: String, action: RecoveryAction, isDestructive: Bool = false) {
            self.title = title
            self.action = action
            self.isDestructive = isDestructive
        }
    }
}

// MARK: - ErrorEnvelope to AlertInfo Mapping

extension ErrorEnvelope {
    /// Convert this error envelope to an AlertInfo for SwiftUI display.
    public func toAlertInfo() -> AlertInfo {
        let title = alertTitle(for: code)
        let primaryButton = primaryAlertButton(from: recoveryActions)
        let secondaryButton = secondaryAlertButton(from: recoveryActions)

        return AlertInfo(
            title: title,
            message: userMessage,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
    }

    private func alertTitle(for code: ErrorCode) -> String {
        switch code {
        case .databaseRead, .databaseWrite, .databaseMigration:
            return "Data Error"
        case .audioCaptureFailed, .audioFileWriteFailed, .audioPermissionDenied:
            return "Audio Error"
        case .mlModelLoad, .mlTranscription, .mlDiarization:
            return "Transcription Error"
        case .recordingStart, .recordingInterrupted, .recordingFinalization:
            return "Recording Error"
        case .sessionLoad, .sessionNotFound:
            return "Session Error"
        case .exportFailed:
            return "Export Error"
        case .networkTimeout, .networkOffline:
            return "Network Error"
        case .unknown:
            return "Error"
        }
    }

    private func primaryAlertButton(from actions: [RecoveryAction]) -> AlertInfo.AlertButton {
        // Choose the most actionable recovery as primary
        if actions.contains(.retry) {
            return AlertInfo.AlertButton(title: "Retry", action: .retry)
        } else if actions.contains(.retryFinalize) {
            return AlertInfo.AlertButton(title: "Retry", action: .retryFinalize)
        } else if actions.contains(.openSettings) {
            return AlertInfo.AlertButton(title: "Open Settings", action: .openSettings)
        } else if actions.contains(.keepPartial) {
            return AlertInfo.AlertButton(title: "Keep Partial", action: .keepPartial)
        } else {
            return AlertInfo.AlertButton(title: "OK", action: .dismiss)
        }
    }

    private func secondaryAlertButton(from actions: [RecoveryAction]) -> AlertInfo.AlertButton? {
        // Add a secondary button for dismissal or destructive actions
        if actions.contains(.deleteSession) && actions.count > 1 {
            return AlertInfo.AlertButton(title: "Delete", action: .deleteSession, isDestructive: true)
        } else if actions.contains(.dismiss) && actions.count > 1 {
            return AlertInfo.AlertButton(title: "Cancel", action: .dismiss)
        }
        return nil
    }
}

// MARK: - Convenience Extensions

extension LoggingClient {
    /// Log a debug message.
    public func debug(
        _ message: String,
        sessionId: String? = nil,
        event: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        let traceId = await currentTraceId()
        await log(LogEntry(
            level: .debug,
            message: message,
            traceId: traceId,
            sessionId: sessionId,
            event: event,
            metadata: metadata
        ))
    }

    /// Log an info message.
    public func info(
        _ message: String,
        sessionId: String? = nil,
        event: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        let traceId = await currentTraceId()
        await log(LogEntry(
            level: .info,
            message: message,
            traceId: traceId,
            sessionId: sessionId,
            event: event,
            metadata: metadata
        ))
    }

    /// Log a warning message.
    public func warning(
        _ message: String,
        sessionId: String? = nil,
        event: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        let traceId = await currentTraceId()
        await log(LogEntry(
            level: .warning,
            message: message,
            traceId: traceId,
            sessionId: sessionId,
            event: event,
            metadata: metadata
        ))
    }

    /// Log an error message.
    public func error(
        _ message: String,
        sessionId: String? = nil,
        event: String? = nil,
        latencyMs: Int? = nil,
        metadata: [String: String] = [:]
    ) async {
        let traceId = await currentTraceId()
        await log(LogEntry(
            level: .error,
            message: message,
            traceId: traceId,
            sessionId: sessionId,
            event: event,
            latencyMs: latencyMs,
            metadata: metadata
        ))
    }
}
