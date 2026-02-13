import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Typography Catalog

extension CatalogBase {
    @Suite("Typography Components")
    @MainActor
    struct TypographyCatalog {

        @Test func testAllTextStyles() {
            let view = VStack(alignment: .leading, spacing: 24) {
                DisplayText("Display Text")
                TitleText("Title Text")
                HeadlineText("Headline Text")
                BodyText("Body text for paragraphs and regular content.")
                CaptionText("Caption text for supplementary info")
                TimestampText("12:34:56")
            }
            .padding(32).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "all_text_styles",
                                   section: "Components", description: "All typography styles: Display, Title, Headline, Body, Caption, Timestamp.")
        }

        @Test func testColorPalette() {
            let colors: [(String, Color)] = [
                ("textPrimary", VaporColor.textPrimary),
                ("textSecondary", VaporColor.textSecondary),
                ("textTertiary", VaporColor.textTertiary),
                ("sky", VaporColor.sky),
                ("lavender", VaporColor.lavender),
                ("deep", VaporColor.deep),
                ("dusk", VaporColor.dusk),
                ("mist", VaporColor.mist),
                ("cloud", VaporColor.cloud),
                ("haze", VaporColor.haze),
                ("fog", VaporColor.fog),
                ("recording", VaporColor.recording),
            ]

            let view = VStack(alignment: .leading, spacing: 8) {
                ForEach(colors, id: \.0) { name, color in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(width: 40, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                        Text(name)
                            .font(.system(size: 13, weight: .light, design: .monospaced))
                            .foregroundColor(VaporColor.textPrimary)
                    }
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "color_palette",
                                   section: "Components", description: "Full Vapor color palette with swatches and names.")
        }
    }
}
