import Testing
import Foundation

@Test func testToolsPackageBuilds() throws {
    let root = try findProjectRoot()
    let toolsDir = root.appendingPathComponent("tools")

    // Verify tools directory exists
    #expect(isDirectory(atPath: toolsDir.path), "tools directory should exist")

    // Verify Package.swift exists
    let packageSwift = toolsDir.appendingPathComponent("Package.swift")
    #expect(FileManager.default.fileExists(atPath: packageSwift.path), "tools/Package.swift should exist")

    // Build the tools package
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["build"]
    process.currentDirectoryURL = toolsDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    #expect(
        process.terminationStatus == 0,
        "tools package should build successfully. Output: \(output)"
    )
}

@Test func testTokenGenExecutableExists() throws {
    let root = try findProjectRoot()
    let toolsDir = root.appendingPathComponent("tools")

    // Build first to ensure executable exists
    let buildProcess = Process()
    buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    buildProcess.arguments = ["build"]
    buildProcess.currentDirectoryURL = toolsDir
    try buildProcess.run()
    buildProcess.waitUntilExit()

    // Run TokenGen --help to verify it's a valid executable
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["run", "TokenGen", "--help"]
    process.currentDirectoryURL = toolsDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    #expect(
        process.terminationStatus == 0,
        "TokenGen should run with --help. Output: \(output)"
    )
    #expect(
        output.contains("Generate Swift design tokens"),
        "TokenGen help should contain description"
    )
}

@Test func testDocGenExecutableExists() throws {
    let root = try findProjectRoot()
    let toolsDir = root.appendingPathComponent("tools")

    // Build first to ensure executable exists
    let buildProcess = Process()
    buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    buildProcess.arguments = ["build"]
    buildProcess.currentDirectoryURL = toolsDir
    try buildProcess.run()
    buildProcess.waitUntilExit()

    // Run DocGen --help to verify it's a valid executable
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["run", "DocGen", "--help"]
    process.currentDirectoryURL = toolsDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    #expect(
        process.terminationStatus == 0,
        "DocGen should run with --help. Output: \(output)"
    )
    #expect(
        output.contains("Generate documentation"),
        "DocGen help should contain description"
    )
}
