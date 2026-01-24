import Testing
import Foundation

@Test func testGeneratedTokensCompile() throws {
    let root = try findProjectRoot()
    let designSystemDir = root
        .appendingPathComponent("Packages")
        .appendingPathComponent("Core")
        .appendingPathComponent("DesignSystem")

    // Verify generated files exist
    let generatedDir = designSystemDir
        .appendingPathComponent("Sources")
        .appendingPathComponent("DesignSystem")
        .appendingPathComponent("Generated")

    let tokensFile = generatedDir.appendingPathComponent("DesignTokens.swift")
    let textStyleFile = generatedDir.appendingPathComponent("VaporTextStyle.swift")

    #expect(
        FileManager.default.fileExists(atPath: tokensFile.path),
        "DesignTokens.swift should be generated"
    )
    #expect(
        FileManager.default.fileExists(atPath: textStyleFile.path),
        "VaporTextStyle.swift should be generated"
    )

    // Build the DesignSystem package to verify generated code compiles
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["build"]
    process.currentDirectoryURL = designSystemDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    #expect(
        process.terminationStatus == 0,
        "DesignSystem package with generated tokens should compile. Output: \(output)"
    )
}

@Test func testGeneratedTokensContainExpectedSymbols() throws {
    let root = try findProjectRoot()
    let generatedDir = root
        .appendingPathComponent("Packages")
        .appendingPathComponent("Core")
        .appendingPathComponent("DesignSystem")
        .appendingPathComponent("Sources")
        .appendingPathComponent("DesignSystem")
        .appendingPathComponent("Generated")

    let tokensFile = generatedDir.appendingPathComponent("DesignTokens.swift")
    let tokensContent = try String(contentsOf: tokensFile, encoding: .utf8)

    // Verify color tokens are present
    #expect(tokensContent.contains("VaporColor"), "Should contain VaporColor enum")
    #expect(tokensContent.contains("cloud"), "Should contain cloud color")
    #expect(tokensContent.contains("mist"), "Should contain mist color")
    #expect(tokensContent.contains("haze"), "Should contain haze color")
    #expect(tokensContent.contains("fog"), "Should contain fog color")
    #expect(tokensContent.contains("deep"), "Should contain deep color")
    #expect(tokensContent.contains("recording"), "Should contain recording color")

    // Verify spacing tokens are present
    #expect(tokensContent.contains("VaporSpacing"), "Should contain VaporSpacing enum")
    #expect(tokensContent.contains("xs"), "Should contain xs spacing")
    #expect(tokensContent.contains("xxl"), "Should contain xxl spacing")

    // Verify radius tokens are present
    #expect(tokensContent.contains("VaporRadius"), "Should contain VaporRadius enum")

    // Verify animation tokens are present
    #expect(tokensContent.contains("VaporAnimation"), "Should contain VaporAnimation enum")
    #expect(tokensContent.contains("microDuration"), "Should contain micro duration")
    #expect(tokensContent.contains("appearCurve"), "Should contain appear curve")
}

@Test func testGeneratedTextStylesContainExpectedSymbols() throws {
    let root = try findProjectRoot()
    let generatedDir = root
        .appendingPathComponent("Packages")
        .appendingPathComponent("Core")
        .appendingPathComponent("DesignSystem")
        .appendingPathComponent("Sources")
        .appendingPathComponent("DesignSystem")
        .appendingPathComponent("Generated")

    let textStyleFile = generatedDir.appendingPathComponent("VaporTextStyle.swift")
    let textStyleContent = try String(contentsOf: textStyleFile, encoding: .utf8)

    // Verify VaporTextStyle struct is present
    #expect(textStyleContent.contains("struct VaporTextStyle"), "Should contain VaporTextStyle struct")

    // Verify all style names are present
    let expectedStyles = ["display", "title", "headline", "body", "caption", "timestamp"]
    for style in expectedStyles {
        #expect(
            textStyleContent.contains("static let \(style)"),
            "Should contain \(style) style"
        )
    }

    // Verify view modifier is present
    #expect(textStyleContent.contains("vaporTextStyle"), "Should contain vaporTextStyle view modifier")
}

@Test func testTokenGenRunsSuccessfully() throws {
    let root = try findProjectRoot()
    let toolsDir = root.appendingPathComponent("tools")

    // Build first
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

    let outputFile = tempDir.appendingPathComponent("TestTokens.swift")
    let inputFile = root.appendingPathComponent("tokens.json")

    // Run TokenGen
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["run", "TokenGen", "--input", inputFile.path, "--output", outputFile.path]
    process.currentDirectoryURL = toolsDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    #expect(
        process.terminationStatus == 0,
        "TokenGen should run successfully. Output: \(output)"
    )

    #expect(
        FileManager.default.fileExists(atPath: outputFile.path),
        "TokenGen should create DesignTokens.swift"
    )

    let textStyleFile = tempDir.appendingPathComponent("VaporTextStyle.swift")
    #expect(
        FileManager.default.fileExists(atPath: textStyleFile.path),
        "TokenGen should create VaporTextStyle.swift alongside DesignTokens.swift"
    )
}
