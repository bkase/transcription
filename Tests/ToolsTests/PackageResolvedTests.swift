import Testing
import Foundation

/// Tests to verify Package.resolved lockfile exists and is tracked for reproducible builds
@Test func testPackageResolvedExists() throws {
    let projectRoot = try findProjectRoot()

    // The Package.resolved should be tracked in xcodegen/ (source of truth)
    // and copied into the generated project during make gen
    let resolvedPath = projectRoot.appendingPathComponent("xcodegen/Package.resolved")

    #expect(
        FileManager.default.fileExists(atPath: resolvedPath.path),
        "xcodegen/Package.resolved should exist for reproducible dependency resolution"
    )
}

@Test func testPackageResolvedContainsExpectedPackages() throws {
    let resolvedContent = try loadPackageResolved()

    // Verify it's valid JSON with expected structure
    guard let data = resolvedContent.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let pins = json["pins"] as? [[String: Any]] else {
        Issue.record("Package.resolved should be valid JSON with 'pins' array")
        return
    }

    // Extract package identities
    let identities = pins.compactMap { $0["identity"] as? String }

    // Key Point-Free packages that should be pinned
    let expectedIdentities = [
        "swift-composable-architecture",
        "swift-tagged",
        "swift-dependencies",
        "swift-identified-collections",
        "swift-clocks",
    ]

    for expected in expectedIdentities {
        #expect(
            identities.contains(expected),
            "Package.resolved should pin \(expected)"
        )
    }
}

@Test func testPackageResolvedHasVersionInfo() throws {
    let resolvedContent = try loadPackageResolved()

    guard let data = resolvedContent.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let pins = json["pins"] as? [[String: Any]] else {
        Issue.record("Package.resolved should be valid JSON")
        return
    }

    // Every pin should have state with version or revision
    for pin in pins {
        guard let identity = pin["identity"] as? String,
              let state = pin["state"] as? [String: Any] else {
            Issue.record("Pin should have identity and state")
            continue
        }

        let hasVersion = state["version"] != nil
        let hasRevision = state["revision"] != nil

        #expect(
            hasVersion || hasRevision,
            "Package \(identity) should have version or revision pinned"
        )
    }
}

// MARK: - Helpers

private func loadPackageResolved() throws -> String {
    let projectRoot = try findProjectRoot()
    let resolvedPath = projectRoot.appendingPathComponent("xcodegen/Package.resolved")

    guard FileManager.default.fileExists(atPath: resolvedPath.path) else {
        throw TestHelperError.fileNotFound("xcodegen/Package.resolved")
    }

    return try String(contentsOf: resolvedPath, encoding: .utf8)
}
