import Testing
import Foundation

@Test func testExpectedDirectoriesExist() {
    let fileManager = FileManager.default

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
        if fileManager.fileExists(atPath: claudeMD.path) || isDirectory(atPath: gitDir.path) {
            projectRoot = searchDir
            break
        }
        searchDir = searchDir.deletingLastPathComponent()
    }

    guard let root = projectRoot else {
        Issue.record("Could not find project root (looking for CLAUDE.md or .git)")
        return
    }

    for dir in expectedDirectories {
        let fullPath = root.appendingPathComponent(dir)
        #expect(
            isDirectory(atPath: fullPath.path),
            "Expected directory to exist: \(dir)"
        )
    }
}

func isDirectory(atPath path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}
