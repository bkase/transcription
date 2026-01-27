import SwiftUI

// MARK: - Vapor Appear Modifier

/// A view modifier that applies the vapor-appear animation when a view appears.
/// Implements the brand animation specification:
/// - Start: opacity 0, scale 0.98, blur 4px
/// - End: opacity 1, scale 1, blur 0px
/// - Duration: 300ms
/// - Curve: vapor-appear (cubic-bezier 0.16, 1, 0.3, 1)
public struct VaporAppearModifier: ViewModifier {
    @State private var isVisible = false

    private let delay: Double

    /// Create a vapor appear modifier.
    /// - Parameter delay: Optional delay before the animation starts (in seconds). Default is 0.
    public init(delay: Double = 0) {
        self.delay = delay
    }

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .blur(radius: isVisible ? 0 : 4)
            .onAppear {
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        animateIn()
                    }
                } else {
                    animateIn()
                }
            }
    }

    private func animateIn() {
        withAnimation(VaporAnimation.appearCurve.animation(duration: VaporAnimation.normalDuration)) {
            isVisible = true
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies the vapor-appear animation when the view appears.
    /// The view starts invisible with slight scale-down and blur, then animates to full visibility.
    /// - Parameter delay: Optional delay before the animation starts (in seconds). Default is 0.
    /// - Returns: A view that animates in with the vapor-appear effect.
    public func vaporAppear(delay: Double = 0) -> some View {
        modifier(VaporAppearModifier(delay: delay))
    }

    /// Applies the vapor-appear animation with staggered delay based on index.
    /// Useful for animating lists where each item appears after the previous.
    /// - Parameters:
    ///   - index: The index of this item in the list (0-based)
    ///   - staggerDelay: The delay between each item's animation (in seconds). Default is 0.05 (50ms).
    /// - Returns: A view that animates in with staggered timing.
    public func vaporAppear(index: Int, staggerDelay: Double = 0.05) -> some View {
        modifier(VaporAppearModifier(delay: Double(index) * staggerDelay))
    }
}

// MARK: - Previews

// MARK: - Staggered Text Reveal View

/// A view that reveals text word-by-word with a staggered blur animation.
/// Implements the brand's transcript text reveal animation:
/// - Each word starts with opacity 0, blur 4px
/// - Words animate in sequence with 20ms delay between each
/// - Each word takes 200ms to fully appear
/// - Uses vapor-appear curve
public struct StaggeredTextRevealView: View {
    private let text: String
    private let font: Font
    private let foregroundColor: Color
    private let lineSpacing: CGFloat
    private let wordDelay: Double
    private let wordDuration: Double

    /// Create a staggered text reveal view.
    /// - Parameters:
    ///   - text: The text to reveal word-by-word
    ///   - font: The font to use for the text
    ///   - foregroundColor: The text color
    ///   - lineSpacing: Line spacing between lines of text
    ///   - wordDelay: Delay between each word's animation start (default 0.02 = 20ms)
    ///   - wordDuration: Duration for each word's animation (default 0.2 = 200ms)
    public init(
        text: String,
        font: Font = .system(size: 16, weight: .light),
        foregroundColor: Color = VaporColor.textPrimary,
        lineSpacing: CGFloat = 6,
        wordDelay: Double = 0.02,
        wordDuration: Double = 0.2
    ) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.lineSpacing = lineSpacing
        self.wordDelay = wordDelay
        self.wordDuration = wordDuration
    }

    public var body: some View {
        FlowLayout(spacing: 4, lineSpacing: lineSpacing) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                StaggeredWordView(
                    word: word,
                    font: font,
                    foregroundColor: foregroundColor,
                    delay: Double(index) * wordDelay,
                    duration: wordDuration
                )
            }
        }
    }

    private var words: [String] {
        text.split(separator: " ").map(String.init)
    }
}

// MARK: - Staggered Word View

/// A single word in the staggered text reveal animation.
private struct StaggeredWordView: View {
    let word: String
    let font: Font
    let foregroundColor: Color
    let delay: Double
    let duration: Double

    @State private var isVisible = false

    var body: some View {
        Text(word)
            .font(font)
            .foregroundColor(foregroundColor)
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible ? 0 : 4)
            .onAppear {
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        animateIn()
                    }
                } else {
                    animateIn()
                }
            }
    }

    private func animateIn() {
        withAnimation(VaporAnimation.appearCurve.animation(duration: duration)) {
            isVisible = true
        }
    }
}

// MARK: - Flow Layout

/// A layout that arranges views in a flowing, wrapping manner like text.
private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { continue }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subview.sizeThatFits(.unspecified))
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#if DEBUG
struct VaporAppearModifier_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            Text("This appears with vapor effect")
                .font(.title)
                .vaporAppear()

            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Text("Item \(index + 1)")
                        .padding()
                        .background(VaporColor.cloud)
                        .cornerRadius(8)
                        .vaporAppear(index: index)
                }
            }
        }
        .padding()
        .background(VaporColor.mist)
    }
}

struct StaggeredTextRevealView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 24) {
            StaggeredTextRevealView(
                text: "So we're looking at the Vapor direction. It needs to feel like breath on glass."
            )

            StaggeredTextRevealView(
                text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
            )
        }
        .padding(24)
        .background(VaporColor.cloud)
    }
}
#endif
