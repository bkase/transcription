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
