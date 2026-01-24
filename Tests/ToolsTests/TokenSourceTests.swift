import Testing
import Foundation

// MARK: - Token Parsing Types

struct DesignTokens: Codable {
    let version: String
    let description: String
    let colors: ColorTokens
    let spacing: [String: Int]
    let radii: [String: Int]
    let typography: TypographyTokens
    let motion: MotionTokens
}

struct ColorTokens: Codable {
    let primary: [String: String]
    let accent: [String: String]
    let semantic: [String: String]
}

struct TypographyTokens: Codable {
    let fontFamily: String
    let fallbackStack: String
    let styles: [String: TextStyle]
    let lineHeight: [String: Double]
}

struct TextStyle: Codable {
    let fontFamily: String
    let fontWeight: Int
    let fontSize: Int
    let letterSpacing: Double
}

struct MotionTokens: Codable {
    let curves: [String: String]
    let durations: [String: Int]
}

// MARK: - Brand Palette Reference

/// Reference values from history/brand.md - the authoritative brand specification
enum BrandPalette {
    enum Primary {
        static let cloud = "#FFFFFF"
        static let mist = "#F7FAFC"
        static let haze = "#EDF2F7"
        static let fog = "#E2E8F0"
        static let overcast = "#CBD5E0"
    }

    enum Accent {
        static let sky = "#A0C4E8"
        static let dusk = "#B8C4D8"
        static let lavender = "#C9B8D8"
        static let deep = "#4A90A4"
    }

    enum Semantic {
        static let recording = "#E88B8B"
        static let success = "#90C4A8"
        static let textPrimary = "#2D3748"
        static let textSecondary = "#718096"
    }

    enum Spacing {
        static let xs = 4
        static let sm = 8
        static let md = 16
        static let lg = 24
        static let xl = 40
        static let xxl = 64
    }

    enum Radii {
        static let sm = 8
        static let md = 16
        static let lg = 24
    }

    enum Typography {
        static let displaySize = 34
        static let titleSize = 28
        static let headlineSize = 20
        static let bodySize = 16
        static let captionSize = 13
        static let timestampSize = 11
    }
}

// MARK: - Tests

@Test func testTokenSourceMatchesBrandPalette() throws {
    let root = try findProjectRoot()
    let tokensURL = root.appendingPathComponent("tokens.json")

    let data = try Data(contentsOf: tokensURL)
    let tokens = try JSONDecoder().decode(DesignTokens.self, from: data)

    // Validate primary colors match brand.md
    #expect(tokens.colors.primary["cloud"] == BrandPalette.Primary.cloud)
    #expect(tokens.colors.primary["mist"] == BrandPalette.Primary.mist)
    #expect(tokens.colors.primary["haze"] == BrandPalette.Primary.haze)
    #expect(tokens.colors.primary["fog"] == BrandPalette.Primary.fog)
    #expect(tokens.colors.primary["overcast"] == BrandPalette.Primary.overcast)

    // Validate accent colors match brand.md
    #expect(tokens.colors.accent["sky"] == BrandPalette.Accent.sky)
    #expect(tokens.colors.accent["dusk"] == BrandPalette.Accent.dusk)
    #expect(tokens.colors.accent["lavender"] == BrandPalette.Accent.lavender)
    #expect(tokens.colors.accent["deep"] == BrandPalette.Accent.deep)

    // Validate semantic colors match brand.md
    #expect(tokens.colors.semantic["recording"] == BrandPalette.Semantic.recording)
    #expect(tokens.colors.semantic["success"] == BrandPalette.Semantic.success)
    #expect(tokens.colors.semantic["textPrimary"] == BrandPalette.Semantic.textPrimary)
    #expect(tokens.colors.semantic["textSecondary"] == BrandPalette.Semantic.textSecondary)

    // Validate spacing matches brand.md
    #expect(tokens.spacing["xs"] == BrandPalette.Spacing.xs)
    #expect(tokens.spacing["sm"] == BrandPalette.Spacing.sm)
    #expect(tokens.spacing["md"] == BrandPalette.Spacing.md)
    #expect(tokens.spacing["lg"] == BrandPalette.Spacing.lg)
    #expect(tokens.spacing["xl"] == BrandPalette.Spacing.xl)
    #expect(tokens.spacing["2xl"] == BrandPalette.Spacing.xxl)

    // Validate corner radii match brand.md
    #expect(tokens.radii["sm"] == BrandPalette.Radii.sm)
    #expect(tokens.radii["md"] == BrandPalette.Radii.md)
    #expect(tokens.radii["lg"] == BrandPalette.Radii.lg)

    // Validate typography sizes match brand.md
    #expect(tokens.typography.styles["display"]?.fontSize == BrandPalette.Typography.displaySize)
    #expect(tokens.typography.styles["title"]?.fontSize == BrandPalette.Typography.titleSize)
    #expect(tokens.typography.styles["headline"]?.fontSize == BrandPalette.Typography.headlineSize)
    #expect(tokens.typography.styles["body"]?.fontSize == BrandPalette.Typography.bodySize)
    #expect(tokens.typography.styles["caption"]?.fontSize == BrandPalette.Typography.captionSize)
    #expect(tokens.typography.styles["timestamp"]?.fontSize == BrandPalette.Typography.timestampSize)
}

@Test func testTokensContainAllRequiredCategories() throws {
    let root = try findProjectRoot()
    let tokensURL = root.appendingPathComponent("tokens.json")

    let data = try Data(contentsOf: tokensURL)
    let tokens = try JSONDecoder().decode(DesignTokens.self, from: data)

    // Ensure all color categories are present
    #expect(tokens.colors.primary.count == 5, "Expected 5 primary colors")
    #expect(tokens.colors.accent.count == 4, "Expected 4 accent colors")
    #expect(tokens.colors.semantic.count >= 4, "Expected at least 4 semantic colors")

    // Ensure spacing scale is complete
    #expect(tokens.spacing.count == 6, "Expected 6 spacing values")

    // Ensure radii scale is complete
    #expect(tokens.radii.count == 3, "Expected 3 radius values")

    // Ensure typography styles are complete
    #expect(tokens.typography.styles.count == 6, "Expected 6 typography styles")
}

@Test func testTokensHaveValidVersion() throws {
    let root = try findProjectRoot()
    let tokensURL = root.appendingPathComponent("tokens.json")

    let data = try Data(contentsOf: tokensURL)
    let tokens = try JSONDecoder().decode(DesignTokens.self, from: data)

    // Version should be semantic versioning format
    let versionComponents = tokens.version.split(separator: ".")
    #expect(versionComponents.count == 3, "Version should be semantic (X.Y.Z)")
}

@Test func testColorValuesAreValidHex() throws {
    let root = try findProjectRoot()
    let tokensURL = root.appendingPathComponent("tokens.json")

    let data = try Data(contentsOf: tokensURL)
    let tokens = try JSONDecoder().decode(DesignTokens.self, from: data)

    // Check all primary colors
    for (name, value) in tokens.colors.primary {
        #expect(isValidHexColor(value), "Invalid hex for primary.\(name): \(value)")
    }

    // Check all accent colors
    for (name, value) in tokens.colors.accent {
        #expect(isValidHexColor(value), "Invalid hex for accent.\(name): \(value)")
    }

    // Check all semantic colors
    for (name, value) in tokens.colors.semantic {
        #expect(isValidHexColor(value), "Invalid hex for semantic.\(name): \(value)")
    }
}

/// Validates that a string is a valid 6-digit hex color code
private func isValidHexColor(_ value: String) -> Bool {
    guard value.count == 7, value.first == "#" else { return false }
    let hex = value.dropFirst()
    return hex.allSatisfy { $0.isHexDigit }
}
