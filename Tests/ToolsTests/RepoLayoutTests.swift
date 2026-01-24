import Testing
import Foundation

@Test func testExpectedDirectoriesExist() throws {
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

    let root = try findProjectRoot()

    for dir in expectedDirectories {
        let fullPath = root.appendingPathComponent(dir)
        #expect(
            isDirectory(atPath: fullPath.path),
            "Expected directory to exist: \(dir)"
        )
    }
}
