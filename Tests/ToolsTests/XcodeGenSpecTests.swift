import Testing
import Foundation

/// Tests to verify XcodeGen project.yml contains proper SPM package declarations
@Test func testProjectYamlContainsPackagePins() throws {
    let projectYml = try loadProjectYaml()

    // Required packages per architecture.md
    let expectedPackages = [
        "swift-composable-architecture",
        "swift-tagged",
        "swift-dependencies",
        "swift-identified-collections",
        "swift-clocks",
        "swift-url-routing",
        "swift-snapshot-testing",
        "swift-gen",
    ]

    for package in expectedPackages {
        #expect(
            projectYml.contains(package),
            "project.yml should declare package: \(package)"
        )
    }
}

@Test func testProjectYamlDeclaresAllCorePackages() throws {
    let projectYml = try loadProjectYaml()

    // Core framework targets
    let coreTargets = [
        "Models",
        "Persistence",
        "Audio",
        "Processing",
        "Export",
        "Observability",
        "Routing",
        "DesignSystem",
    ]

    for target in coreTargets {
        #expect(
            projectYml.contains("  \(target):"),
            "project.yml should declare target: \(target)"
        )
    }
}

@Test func testProjectYamlDeclaresAllFeaturePackages() throws {
    let projectYml = try loadProjectYaml()

    // Feature framework targets
    let featureTargets = [
        "TimelineFeature",
        "RecordingFeature",
        "SessionDetailFeature",
        "PeopleFeature",
        "SpeakerPickerFeature",
        "AudioPlayerFeature",
    ]

    for target in featureTargets {
        #expect(
            projectYml.contains("  \(target):"),
            "project.yml should declare feature target: \(target)"
        )
    }
}

@Test func testProjectYamlPackagesHaveVersionPins() throws {
    let projectYml = try loadProjectYaml()

    // Verify packages section has version pins (from: "X.Y.Z")
    let packageSection = extractPackagesSection(from: projectYml)

    #expect(
        packageSection.contains("from:"),
        "Packages should have version pins using 'from:'"
    )

    // Each package URL should have a corresponding version
    let urlPattern = "url: https://github.com"
    let urlCount = projectYml.components(separatedBy: urlPattern).count - 1
    let fromCount = packageSection.components(separatedBy: "from:").count - 1

    #expect(
        urlCount == fromCount,
        "Each package URL should have a version pin. URLs: \(urlCount), pins: \(fromCount)"
    )
}

// MARK: - Helpers

private func loadProjectYaml() throws -> String {
    let fileManager = FileManager.default
    let projectRoot = try findProjectRoot()
    let yamlPath = projectRoot.appendingPathComponent("xcodegen/project.yml")

    guard fileManager.fileExists(atPath: yamlPath.path) else {
        throw TestHelperError.fileNotFound("xcodegen/project.yml not found")
    }

    return try String(contentsOf: yamlPath, encoding: .utf8)
}

private func extractPackagesSection(from yaml: String) -> String {
    // Extract the packages: section from YAML
    guard let packagesStart = yaml.range(of: "packages:")?.lowerBound else {
        return ""
    }

    let fromPackages = String(yaml[packagesStart...])

    // Find the next top-level key (not indented)
    let lines = fromPackages.components(separatedBy: "\n")
    var packageLines: [String] = []
    var foundPackages = false

    for line in lines {
        if line.hasPrefix("packages:") {
            foundPackages = true
            packageLines.append(line)
            continue
        }

        if foundPackages {
            // Check if this is a new top-level key (no leading whitespace)
            if !line.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                break
            }
            packageLines.append(line)
        }
    }

    return packageLines.joined(separator: "\n")
}
