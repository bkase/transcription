import Foundation
import Models
import Persistence
import Dependencies
import DependenciesMacros

// MARK: - ExportFormat

/// Supported export formats
public enum ExportFormat: String, Sendable, CaseIterable {
    case json
    case markdown
    case vtt
}

// MARK: - ExportResult

/// Result of an export operation
public struct ExportResult: Sendable, Equatable {
    public let url: URL
    public let format: ExportFormat

    public init(url: URL, format: ExportFormat) {
        self.url = url
        self.format = format
    }
}

// MARK: - ExportClient

/// Client for exporting session data
@DependencyClient
public struct ExportClient: Sendable {
    /// Export a session to the specified format
    public var exportSession: @Sendable (_ sessionId: SessionID, _ format: ExportFormat) async throws -> ExportResult
    /// Export a session to all formats as a bundle
    public var exportBundle: @Sendable (_ sessionId: SessionID) async throws -> URL
    /// Get available export formats
    public var availableFormats: @Sendable () -> [ExportFormat] = { ExportFormat.allCases }
}

extension ExportClient: DependencyKey {
    public static let liveValue: Self = {
        // Live implementation will create export files - placeholder for now
        Self(
            exportSession: { _, format in
                ExportResult(url: URL(fileURLWithPath: "/tmp/export"), format: format)
            },
            exportBundle: { _ in URL(fileURLWithPath: "/tmp/bundle.zip") },
            availableFormats: { ExportFormat.allCases }
        )
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var exportClient: ExportClient {
        get { self[ExportClient.self] }
        set { self[ExportClient.self] = newValue }
    }
}

// MARK: - FileClient

/// Client for file system operations
@DependencyClient
public struct FileClient: Sendable {
    /// Read data from a file
    public var read: @Sendable (_ url: URL) async throws -> Data
    /// Write data to a file
    public var write: @Sendable (_ data: Data, _ url: URL) async throws -> Void
    /// Delete a file
    public var delete: @Sendable (_ url: URL) async throws -> Void
    /// Check if a file exists
    public var exists: @Sendable (_ url: URL) -> Bool = { _ in false }
    /// Create a directory
    public var createDirectory: @Sendable (_ url: URL) async throws -> Void
    /// Get temporary directory URL
    public var temporaryDirectory: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
}

extension FileClient: DependencyKey {
    public static let liveValue: Self = {
        let fileManager = FileManager.default
        return Self(
            read: { url in try Data(contentsOf: url) },
            write: { data, url in try data.write(to: url) },
            delete: { url in try fileManager.removeItem(at: url) },
            exists: { url in fileManager.fileExists(atPath: url.path) },
            createDirectory: { url in
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            },
            temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) }
        )
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var fileClient: FileClient {
        get { self[FileClient.self] }
        set { self[FileClient.self] = newValue }
    }
}
