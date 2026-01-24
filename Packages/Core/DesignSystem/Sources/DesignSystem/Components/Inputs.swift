import SwiftUI

// MARK: - Search Field

/// Search field component with idle and focused states.
/// Uses frosted glass effect (idle) or solid background (focused).
public struct SearchField: View {
    @Binding private var text: String
    private let placeholder: String
    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, placeholder: String = "Search transcripts...") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: VaporSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(VaporColor.textTertiary)

            TextField(placeholder, text: $text)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textPrimary)
                .focused($isFocused)
        }
        .padding(.horizontal, VaporSpacing.md)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isFocused ? VaporColor.cloud : Color.white.opacity(0.5))
                .background(
                    Group {
                        if !isFocused {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    }
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(VaporColor.haze, lineWidth: 1)
        )
        .shadow(
            color: isFocused ? Color.black.opacity(0.03) : Color.clear,
            radius: isFocused ? 8 : 0,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Search Field (Static Preview Variant)

/// Non-interactive search field for snapshot testing and previews.
/// Shows either idle or focused state without TextField interaction.
public struct SearchFieldPreview: View {
    private let text: String
    private let placeholder: String
    private let isFocused: Bool

    public init(text: String = "", placeholder: String = "Search transcripts...", isFocused: Bool = false) {
        self.text = text
        self.placeholder = placeholder
        self.isFocused = isFocused
    }

    public var body: some View {
        HStack(spacing: VaporSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(VaporColor.textTertiary)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textTertiary)
            } else {
                Text(text)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, VaporSpacing.md)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isFocused ? VaporColor.cloud : Color.white.opacity(0.5))
                .background(
                    Group {
                        if !isFocused {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    }
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(VaporColor.haze, lineWidth: 1)
        )
        .shadow(
            color: isFocused ? Color.black.opacity(0.03) : Color.clear,
            radius: isFocused ? 8 : 0,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Previews

#if DEBUG
struct SearchField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            // Idle state
            VStack(alignment: .leading, spacing: 8) {
                Text("Idle")
                    .font(.caption)
                    .foregroundColor(VaporColor.textTertiary)
                SearchFieldPreview()
            }

            // Focused state with text
            VStack(alignment: .leading, spacing: 8) {
                Text("Focused")
                    .font(.caption)
                    .foregroundColor(VaporColor.textTertiary)
                SearchFieldPreview(text: "morning ref", isFocused: true)
            }
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}
#endif
