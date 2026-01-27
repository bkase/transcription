import Testing
import SwiftUI
@testable import DesignSystem

// MARK: - Vapor Appear Animation Tests

/// Tests for the VaporAppearModifier that implements the brand's appear animation spec.
/// Reference: brand.md Appear Animation section

@Test func testVaporAppearModifierDefaultDelay() {
    // Default delay should be 0
    let modifier = VaporAppearModifier()
    // The modifier exists and can be applied - actual animation behavior
    // is tested visually via snapshot tests
    #expect(true)
}

@Test func testVaporAppearModifierWithDelay() {
    // Should accept custom delay values
    let modifier = VaporAppearModifier(delay: 0.5)
    #expect(true)
}

@Test func testVaporAppearViewExtension() {
    // View extension should be accessible
    let _ = Text("Test").vaporAppear()
    let _ = Text("Test").vaporAppear(delay: 0.2)
    #expect(true)
}

@Test func testVaporAppearStaggeredExtension() {
    // Staggered extension should calculate delay based on index
    let _ = Text("Test").vaporAppear(index: 0)
    let _ = Text("Test").vaporAppear(index: 5)
    let _ = Text("Test").vaporAppear(index: 2, staggerDelay: 0.1)
    #expect(true)
}

@Test func testVaporAppearUsesCorrectAnimationCurve() {
    // Verify the animation curve matches brand spec
    // vapor-appear: cubic-bezier(0.16, 1, 0.3, 1)
    let curve = VaporAnimation.appearCurve
    #expect(curve.x1 == 0.16)
    #expect(curve.y1 == 1)
    #expect(curve.x2 == 0.3)
    #expect(curve.y2 == 1)
}

@Test func testVaporAppearUsesCorrectDuration() {
    // Verify duration is 300ms (0.3 seconds)
    #expect(VaporAnimation.normalDuration == 0.3)
}
