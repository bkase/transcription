import Testing
import SwiftUI
@testable import DesignSystem

// MARK: - Color Token Tests

@Test func vaporColorsExist() {
    // Primary colors
    let _ = VaporColor.cloud
    let _ = VaporColor.mist
    let _ = VaporColor.haze
    let _ = VaporColor.fog
    let _ = VaporColor.overcast

    // Accent colors
    let _ = VaporColor.sky
    let _ = VaporColor.dusk
    let _ = VaporColor.lavender
    let _ = VaporColor.deep

    // Semantic colors
    let _ = VaporColor.recording
    let _ = VaporColor.success
    let _ = VaporColor.textPrimary
    let _ = VaporColor.textSecondary
    let _ = VaporColor.textTertiary
}

// MARK: - Spacing Token Tests

@Test func vaporSpacingExists() {
    #expect(VaporSpacing.xs == 4)
    #expect(VaporSpacing.sm == 8)
    #expect(VaporSpacing.md == 16)
    #expect(VaporSpacing.lg == 24)
    #expect(VaporSpacing.xl == 40)
    #expect(VaporSpacing.xxl == 64)
}

// MARK: - Radius Token Tests

@Test func vaporRadiusExists() {
    #expect(VaporRadius.sm == 8)
    #expect(VaporRadius.md == 16)
    #expect(VaporRadius.lg == 24)
}

// MARK: - Animation Token Tests

@Test func vaporAnimationDurationsExist() {
    #expect(VaporAnimation.microDuration == 0.15)
    #expect(VaporAnimation.normalDuration == 0.3)
    #expect(VaporAnimation.pageDuration == 0.4)
    #expect(VaporAnimation.blurDuration == 0.5)
    #expect(VaporAnimation.breatheDuration == 2.0)
}

@Test func vaporAnimationCurvesExist() {
    // Verify curves are defined with valid control points
    let appear = VaporAnimation.appearCurve
    #expect(appear.x1 == 0.16)
    #expect(appear.y1 == 1.0)

    let breathe = VaporAnimation.breatheCurve
    #expect(breathe.x1 == 0.45)

    let drift = VaporAnimation.driftCurve
    #expect(drift.x1 == 0.25)

    let exit = VaporAnimation.exitCurve
    #expect(exit.x1 == 0.7)
}
