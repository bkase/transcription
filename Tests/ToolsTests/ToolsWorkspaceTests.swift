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
