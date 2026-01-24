import Testing
import Foundation

@Test func testSchemaDocsGenerated() throws {
    let root = try findProjectRoot()
    let toolsDir = root.appendingPathComponent("tools")

    // Build first to ensure executable exists
    let buildProcess = Process()
    buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    buildProcess.arguments = ["build"]
    buildProcess.currentDirectoryURL = toolsDir
    try buildProcess.run()
    buildProcess.waitUntilExit()

    #expect(buildProcess.terminationStatus == 0, "Tools should build")

    // Create a temp directory for output
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let inputDir = root
        .appendingPathComponent("Packages")
        .appendingPathComponent("Core")
        .appendingPathComponent("Persistence")
        .appendingPathComponent("Sources")
        .appendingPathComponent("Persistence")

    // Run DocGen
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["run", "DocGen", "--input", inputDir.path, "--output", tempDir.path]
    process.currentDirectoryURL = toolsDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    #expect(
        process.terminationStatus == 0,
        "DocGen should run successfully. Output: \(output)"
    )

    // Verify SCHEMA.md was generated
    let schemaPath = tempDir.appendingPathComponent("SCHEMA.md")
    #expect(
        FileManager.default.fileExists(atPath: schemaPath.path),
        "DocGen should create SCHEMA.md"
    )

    // Verify EXPORT_FORMAT.md was generated
    let exportPath = tempDir.appendingPathComponent("EXPORT_FORMAT.md")
    #expect(
        FileManager.default.fileExists(atPath: exportPath.path),
        "DocGen should create EXPORT_FORMAT.md"
    )

    // Verify SCHEMA.md contains expected content
    let schemaContent = try String(contentsOf: schemaPath, encoding: .utf8)

    // Check for expected table names
    #expect(schemaContent.contains("sessions"), "SCHEMA.md should document sessions table")
    #expect(schemaContent.contains("people"), "SCHEMA.md should document people table")
    #expect(schemaContent.contains("speaker_tracks"), "SCHEMA.md should document speaker_tracks table")
    #expect(schemaContent.contains("transcript_segments"), "SCHEMA.md should document transcript_segments table")
    #expect(schemaContent.contains("speaker_segments"), "SCHEMA.md should document speaker_segments table")

    // Check for migration names
    #expect(schemaContent.contains("v1_initial_schema"), "SCHEMA.md should document v1 migration")
    #expect(schemaContent.contains("v2_fts5_search"), "SCHEMA.md should document v2 migration")

    // Check for FTS table
    #expect(schemaContent.contains("transcript_fts"), "SCHEMA.md should document FTS table")
    #expect(schemaContent.contains("FTS5"), "SCHEMA.md should mention FTS5")

    // Check for foreign key references
    #expect(schemaContent.contains("CASCADE"), "SCHEMA.md should document CASCADE on delete")
    #expect(schemaContent.contains("SET NULL"), "SCHEMA.md should document SET NULL on delete")

    // Check for indexes
    #expect(schemaContent.contains("idx_sessions_startedAt"), "SCHEMA.md should document indexes")

    // Check for triggers
    #expect(schemaContent.contains("transcript_fts_ai"), "SCHEMA.md should document triggers")

    // Verify EXPORT_FORMAT.md contains expected content
    let exportContent = try String(contentsOf: exportPath, encoding: .utf8)

    #expect(exportContent.contains("JSON Export"), "EXPORT_FORMAT.md should document JSON export")
    #expect(exportContent.contains("Markdown Export"), "EXPORT_FORMAT.md should document Markdown export")
    #expect(exportContent.contains("VTT"), "EXPORT_FORMAT.md should document VTT export")
    #expect(exportContent.contains("Database Tables Used"), "EXPORT_FORMAT.md should list tables")
}

@Test func testDocGenFailsWithMissingInput() throws {
    let root = try findProjectRoot()
    let toolsDir = root.appendingPathComponent("tools")

    // Build first to ensure executable exists
    let buildProcess = Process()
    buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    buildProcess.arguments = ["build"]
    buildProcess.currentDirectoryURL = toolsDir
    try buildProcess.run()
    buildProcess.waitUntilExit()

    // Create a temp directory for output
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Run DocGen with non-existent input
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["run", "DocGen", "--input", "/nonexistent/path", "--output", tempDir.path]
    process.currentDirectoryURL = toolsDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    #expect(
        process.terminationStatus != 0,
        "DocGen should fail with non-existent input"
    )
}
