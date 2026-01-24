import Testing
import SwiftUI
@testable import DesignSystem

// MARK: - Text Style Tests

/// These tests verify that generated text styles match the brand specification.
/// Reference: history/brand.md Typography section

@Test func testTextStylesMatchSpec() {
    // Display style: SF Pro Display, Ultralight (100), 34pt, -0.02em
    #expect(VaporTextStyle.display.fontFamily == "SF Pro Display")
    #expect(VaporTextStyle.display.fontWeight == .ultraLight)
    #expect(VaporTextStyle.display.fontSize == 34)
    #expect(VaporTextStyle.display.letterSpacing == -0.02)

    // Title style: SF Pro Display, Thin (200), 28pt, -0.01em
    #expect(VaporTextStyle.title.fontFamily == "SF Pro Display")
    #expect(VaporTextStyle.title.fontWeight == .thin)
    #expect(VaporTextStyle.title.fontSize == 28)
    #expect(VaporTextStyle.title.letterSpacing == -0.01)

    // Headline style: SF Pro Text, Light (300), 20pt, 0em
    #expect(VaporTextStyle.headline.fontFamily == "SF Pro Text")
    #expect(VaporTextStyle.headline.fontWeight == .light)
    #expect(VaporTextStyle.headline.fontSize == 20)
    #expect(VaporTextStyle.headline.letterSpacing == 0)

    // Body style: SF Pro Text, Light (300), 16pt, 0em
    #expect(VaporTextStyle.body.fontFamily == "SF Pro Text")
    #expect(VaporTextStyle.body.fontWeight == .light)
    #expect(VaporTextStyle.body.fontSize == 16)
    #expect(VaporTextStyle.body.letterSpacing == 0)

    // Caption style: SF Pro Text, Light (300), 13pt, +0.01em
    #expect(VaporTextStyle.caption.fontFamily == "SF Pro Text")
    #expect(VaporTextStyle.caption.fontWeight == .light)
    #expect(VaporTextStyle.caption.fontSize == 13)
    #expect(VaporTextStyle.caption.letterSpacing == 0.01)

    // Timestamp style: SF Mono, Light (300), 11pt, +0.02em
    #expect(VaporTextStyle.timestamp.fontFamily == "SF Mono")
    #expect(VaporTextStyle.timestamp.fontWeight == .light)
    #expect(VaporTextStyle.timestamp.fontSize == 11)
    #expect(VaporTextStyle.timestamp.letterSpacing == 0.02)
}

@Test func testTextStyleLineHeights() {
    // Body text uses 1.6 line height
    #expect(VaporTextStyle.body.lineHeight == 1.6)
    #expect(VaporTextStyle.caption.lineHeight == 1.6)
    #expect(VaporTextStyle.timestamp.lineHeight == 1.6)

    // Headlines use 1.3 line height
    #expect(VaporTextStyle.display.lineHeight == 1.3)
    #expect(VaporTextStyle.title.lineHeight == 1.3)
    #expect(VaporTextStyle.headline.lineHeight == 1.3)
}

@Test func testTextStyleTrackingCalculation() {
    // Tracking = letterSpacing * fontSize
    // Display: -0.02 * 34 = -0.68
    #expect(VaporTextStyle.display.tracking == -0.02 * 34)

    // Caption: 0.01 * 13 = 0.13
    #expect(VaporTextStyle.caption.tracking == 0.01 * 13)

    // Body: 0 * 16 = 0
    #expect(VaporTextStyle.body.tracking == 0)
}

@Test func testTextStyleFontCreation() {
    // Verify that font property returns a Font without crashing
    let displayFont = VaporTextStyle.display.font
    let bodyFont = VaporTextStyle.body.font
    let timestampFont = VaporTextStyle.timestamp.font

    // These should all be valid Font instances
    // (can't directly compare Font types, but we can verify they don't crash)
    _ = displayFont
    _ = bodyFont
    _ = timestampFont
}

@Test func testVaporTextStyleIsSendable() {
    // Verify VaporTextStyle can be passed across actor boundaries
    let style = VaporTextStyle.body

    Task {
        // Using the style in another task verifies Sendable conformance compiles
        let _ = style.fontSize
    }
}

@Test func testVaporTextStyleIsEquatable() {
    let style1 = VaporTextStyle.body
    let style2 = VaporTextStyle.body
    let style3 = VaporTextStyle.headline

    #expect(style1 == style2)
    #expect(style1 != style3)
}
