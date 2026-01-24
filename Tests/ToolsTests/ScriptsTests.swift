import Testing
import Foundation

@Test func testCiScriptRunsMakeCi() throws {
    let root = try findProjectRoot()
    let ciScript = root.appendingPathComponent("scripts/ci.sh")

    // Verify script exists
    #expect(FileManager.default.fileExists(atPath: ciScript.path), "scripts/ci.sh should exist")

    // Read script content and verify it calls make ci (or bootstrap + gen + test)
    let content = try String(contentsOf: ciScript, encoding: .utf8)

    // The script should call make bootstrap, gen, and test (which is equivalent to make ci)
    #expect(content.contains("make") && content.contains("bootstrap"), "ci.sh should call make bootstrap")
    #expect(content.contains("make") && content.contains("gen"), "ci.sh should call make gen")
    #expect(content.contains("make") && content.contains("test"), "ci.sh should call make test")

    // Verify script is executable
    let attrs = try FileManager.default.attributesOfItem(atPath: ciScript.path)
    if let perms = attrs[.posixPermissions] as? Int {
        let isExecutable = (perms & 0o111) != 0
        #expect(isExecutable, "ci.sh should be executable")
    }
}

@Test func testGenScriptRunsMakeGen() throws {
    let root = try findProjectRoot()
    let genScript = root.appendingPathComponent("scripts/gen.sh")

    // Verify script exists
    #expect(FileManager.default.fileExists(atPath: genScript.path), "scripts/gen.sh should exist")

    // Read script content and verify it calls make gen
    let content = try String(contentsOf: genScript, encoding: .utf8)

    // The script should call make gen (and bootstrap as a dependency)
    #expect(content.contains("make") && content.contains("gen"), "gen.sh should call make gen")
    #expect(content.contains("make") && content.contains("bootstrap"), "gen.sh should call make bootstrap")

    // Verify script is executable
    let attrs = try FileManager.default.attributesOfItem(atPath: genScript.path)
    if let perms = attrs[.posixPermissions] as? Int {
        let isExecutable = (perms & 0o111) != 0
        #expect(isExecutable, "gen.sh should be executable")
    }
}

@Test func testScriptsHaveProperShebang() throws {
    let root = try findProjectRoot()
    let scripts = ["scripts/ci.sh", "scripts/gen.sh"]

    for scriptPath in scripts {
        let script = root.appendingPathComponent(scriptPath)
        let content = try String(contentsOf: script, encoding: .utf8)

        #expect(content.hasPrefix("#!/bin/bash"), "\(scriptPath) should start with #!/bin/bash")
        #expect(content.contains("set -euo pipefail"), "\(scriptPath) should use strict mode")
    }
}
