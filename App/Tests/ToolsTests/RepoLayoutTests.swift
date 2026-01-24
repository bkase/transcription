import Testing
import Foundation

@Test func testExpectedDirectoriesExist() {
    let fileManager = FileManager.default

    // Get the project root (3 levels up from this test file's directory)
    // In a built test, we need to find the project root differently
    // We'll use an environment variable or a known anchor file

    // For now, we'll check relative to the working directory when running tests
    // The Makefile will ensure we run from the project root

    let expectedDirectories = [
        // App structure
        "App/Sources",

        // Core packages
        "Packages/Core/Models/Sources/Models",
        "Packages/Core/Persistence/Sources/Persistence",
        "Packages/Core/Audio/Sources/Audio",
        "Packages/Core/Processing/Sources/Processing",
        "Packages/Core/Export/Sources/Export",
        "Packages/Core/Observability/Sources/Observability",
        "Packages/Core/Routing/Sources/Routing",
        "Packages/Core/DesignSystem/Sources/DesignSystem",

        // Feature packages
        "Packages/Features/TimelineFeature/Sources/TimelineFeature",
        "Packages/Features/RecordingFeature/Sources/RecordingFeature",
        "Packages/Features/SessionDetailFeature/Sources/SessionDetailFeature",
        "Packages/Features/PeopleFeature/Sources/PeopleFeature",
        "Packages/Features/SpeakerPickerFeature/Sources/SpeakerPickerFeature",
        "Packages/Features/AudioPlayerFeature/Sources/AudioPlayerFeature",

        // TestsSupport
        "Packages/TestsSupport/Sources/TestsSupport",

        // Tooling
        "tools/Sources/TokenGen",
        "tools/Sources/DocGen",

        // XcodeGen
        "xcodegen",
        "xcodegen/configs",

        // Documentation
        "docs",

        // Scripts
        "scripts",
    ]

    // Try to find the project root by looking for CLAUDE.md or .git
    var projectRoot: URL?

    // Start from current working directory and search upward
    var searchDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    for _ in 0..<10 {
        let claudeMD = searchDir.appendingPathComponent("CLAUDE.md")
        let gitDir = searchDir.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: claudeMD.path) || fileManager.isDirectory(atPath: gitDir.path) {
            projectRoot = searchDir
            break
        }
        searchDir = searchDir.deletingLastPathComponent()
    }

    // If we couldn't find it from current directory, try from the test bundle
    if projectRoot == nil {
        if let bundlePath = Bundle.main.resourcePath {
            searchDir = URL(fileURLWithPath: bundlePath)
            for _ in 0..<10 {
                let claudeMD = searchDir.appendingPathComponent("CLAUDE.md")
                let gitDir = searchDir.appendingPathComponent(".git")
                if fileManager.fileExists(atPath: claudeMD.path) || fileManager.isDirectory(atPath: gitDir.path) {
                    projectRoot = searchDir
                    break
                }
                searchDir = searchDir.deletingLastPathComponent()
            }
        }
    }

    guard let root = projectRoot else {
        Issue.record("Could not find project root (looking for CLAUDE.md or .git)")
        return
    }

    for dir in expectedDirectories {
        let fullPath = root.appendingPathComponent(dir)
        #expect(
            fileManager.isDirectory(atPath: fullPath.path),
            "Expected directory to exist: \(dir)"
        )
    }
}

extension FileManager {
    func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
