import Models
import Dependencies
import DependenciesMacros

// MARK: - DatabaseClient

/// Client for database operations (SQLite persistence layer)
@DependencyClient
public struct DatabaseClient: Sendable {
    /// Fetch all sessions ordered by creation date
    public var fetchSessions: @Sendable () async throws -> [SessionID]
    /// Fetch a single session by ID
    public var fetchSession: @Sendable (_ id: SessionID) async throws -> SessionID?
    /// Create a new session
    public var createSession: @Sendable (_ id: SessionID) async throws -> Void
    /// Delete a session
    public var deleteSession: @Sendable (_ id: SessionID) async throws -> Void
}

extension DatabaseClient: DependencyKey {
    public static let liveValue: Self = {
        // Live implementation will connect to SQLite - placeholder for now
        Self(
            fetchSessions: { [] },
            fetchSession: { _ in nil },
            createSession: { _ in },
            deleteSession: { _ in }
        )
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}
