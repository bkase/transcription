import SwiftUI

// MARK: - Typography Components

/// Large display text for splash screens and hero content.
/// Uses SF Pro Display Ultralight at 34pt.
public struct DisplayText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = VaporColor.textPrimary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .vaporTextStyle(.display)
            .foregroundColor(color)
    }
}

/// Primary page title text.
/// Uses SF Pro Display Thin at 28pt.
public struct TitleText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = VaporColor.textPrimary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .vaporTextStyle(.title)
            .foregroundColor(color)
    }
}

/// Section heading text.
/// Uses SF Pro Text Light at 20pt.
public struct HeadlineText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = VaporColor.textPrimary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .vaporTextStyle(.headline)
            .foregroundColor(color)
    }
}

/// Regular body text for paragraphs and content.
/// Uses SF Pro Text Light at 16pt with 1.6 line height.
public struct BodyText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = VaporColor.textPrimary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .vaporTextStyle(.body)
            .foregroundColor(color)
    }
}

/// Small supplementary text for captions and labels.
/// Uses SF Pro Text Light at 13pt.
public struct CaptionText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = VaporColor.textSecondary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .vaporTextStyle(.caption)
            .foregroundColor(color)
    }
}

/// Monospace timestamp text for times and codes.
/// Uses SF Mono Light at 11pt.
public struct TimestampText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = VaporColor.textTertiary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .vaporTextStyle(.timestamp)
            .foregroundColor(color)
    }
}
