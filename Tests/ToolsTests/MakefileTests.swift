import Testing
import Foundation

@Test func testMakeTargetsExist() throws {
    let root = try findProjectRoot()
    let makefilePath = root.appendingPathComponent("Makefile")

    let content = try String(contentsOf: makefilePath, encoding: .utf8)

    // Required targets per the architecture
    let requiredTargets = [
        "bootstrap",
        "gen",
        "test",
        "test-slow",
        "ci",
        "clean",
        "help"
    ]

    for target in requiredTargets {
        // Look for the target definition (target: or target :)
        let pattern = "^\(target)\\s*:"
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.numberOfMatches(in: content, range: range)

        #expect(
            matches > 0,
            "Expected Makefile to contain target '\(target):'"
        )
    }
}

@Test func testMakefileHasPhonyDeclarations() throws {
    let root = try findProjectRoot()
    let makefilePath = root.appendingPathComponent("Makefile")

    let content = try String(contentsOf: makefilePath, encoding: .utf8)

    // PHONY targets prevent issues with files named like targets
    #expect(
        content.contains(".PHONY:"),
        "Makefile should declare .PHONY targets"
    )
}

@Test func testMakefileTestTargetDependsOnGen() throws {
    let root = try findProjectRoot()
    let makefilePath = root.appendingPathComponent("Makefile")

    let content = try String(contentsOf: makefilePath, encoding: .utf8)

    // test should depend on gen to ensure project is generated
    let pattern = "^test\\s*:.*\\bgen\\b"
    let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
    let range = NSRange(content.startIndex..<content.endIndex, in: content)
    let matches = regex.numberOfMatches(in: content, range: range)

    #expect(
        matches > 0,
        "test target should depend on gen target"
    )
}

@Test func testMakefileCiRunsFullPipeline() throws {
    let root = try findProjectRoot()
    let makefilePath = root.appendingPathComponent("Makefile")

    let content = try String(contentsOf: makefilePath, encoding: .utf8)

    // ci should depend on bootstrap, gen, and test
    let pattern = "^ci\\s*:.*\\bbootstrap\\b.*\\bgen\\b.*\\btest\\b"
    let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
    let range = NSRange(content.startIndex..<content.endIndex, in: content)
    let matches = regex.numberOfMatches(in: content, range: range)

    #expect(
        matches > 0,
        "ci target should depend on bootstrap, gen, and test"
    )
}
