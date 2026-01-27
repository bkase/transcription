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

// MARK: - Vapor Exit Modifier

/// A view modifier that applies the vapor-exit animation when a view disappears.
/// Implements the brand animation specification for exit animations:
/// - Start: opacity 1, scale 1, blur 0px
/// - End: opacity 0, scale 0.98, blur 4px
/// - Duration: 300ms
/// - Curve: vapor-exit (cubic-bezier 0.7, 0, 0.84, 0)
///
/// Use this modifier when you have a view controlled by an `isPresented` binding
/// and want it to animate out gracefully when dismissed.
public struct VaporExitModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var isVisible: Bool

    /// Create a vapor exit modifier.
    /// - Parameter isPresented: Binding to the presentation state. When this becomes false,
    ///   the exit animation plays before the view is removed.
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        // Start visible when presented
        self._isVisible = State(initialValue: isPresented.wrappedValue)
    }

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .blur(radius: isVisible ? 0 : 4)
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    // Appearing - animate in
                    withAnimation(VaporAnimation.appearCurve.animation(duration: VaporAnimation.normalDuration)) {
                        isVisible = true
                    }
                } else {
                    // Disappearing - animate out with exit curve
                    withAnimation(VaporAnimation.exitCurve.animation(duration: VaporAnimation.normalDuration)) {
                        isVisible = false
                    }
                }
            }
            .onAppear {
                // Handle initial appearance if starting presented
                if isPresented && !isVisible {
                    withAnimation(VaporAnimation.appearCurve.animation(duration: VaporAnimation.normalDuration)) {
                        isVisible = true
                    }
                }
            }
    }
}

// MARK: - Vapor Exit Transition

/// A custom transition that applies the vapor-exit animation.
/// Use with conditional views (if/else) to animate their insertion/removal.
///
/// Example:
/// ```swift
/// if showContent {
///     MyView()
///         .transition(.vaporExit)
/// }
/// ```
public extension AnyTransition {
    /// A transition that fades in/out with scale and blur, using vapor timing curves.
    /// - Insertion: opacity 0→1, scale 0.98→1, blur 4→0, using vapor-appear curve
    /// - Removal: opacity 1→0, scale 1→0.98, blur 0→4, using vapor-exit curve
    static var vaporExit: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: VaporTransitionModifier(opacity: 0, scale: 0.98, blur: 4),
                identity: VaporTransitionModifier(opacity: 1, scale: 1, blur: 0)
            ),
            removal: .modifier(
                active: VaporTransitionModifier(opacity: 0, scale: 0.98, blur: 4),
                identity: VaporTransitionModifier(opacity: 1, scale: 1, blur: 0)
            )
        )
    }
}

/// Internal modifier used by the vaporExit transition.
private struct VaporTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: blur)
    }
}

// MARK: - Vapor Focus Blur Modifier

/// A view modifier that applies a blur effect when focus state changes.
/// Implements the brand's blur focus transition:
/// - Focused: blur 2px (background content becomes slightly blurred)
/// - Unfocused: blur 0px (background content is sharp)
/// - Duration: 500ms
/// - Curve: vapor-appear
///
/// Use this modifier on content that should blur when a search field,
/// modal, or other interactive element gains focus.
public struct VaporFocusBlurModifier: ViewModifier {
    private let isFocused: Bool
    private let blurRadius: CGFloat

    /// Create a vapor focus blur modifier.
    /// - Parameters:
    ///   - isFocused: Whether the focus state is active.
    ///   - blurRadius: The blur radius when focused (default 2px for subtle effect).
    public init(isFocused: Bool, blurRadius: CGFloat = 2) {
        self.isFocused = isFocused
        self.blurRadius = blurRadius
    }

    public func body(content: Content) -> some View {
        content
            .blur(radius: isFocused ? blurRadius : 0)
            .animation(
                VaporAnimation.appearCurve.animation(duration: VaporAnimation.blurDuration),
                value: isFocused
            )
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

    /// Applies a blur effect when focus state changes.
    /// Implements the brand's blur focus transition with 500ms duration.
    ///
    /// Use this on background content that should blur when a search field or modal is active:
    /// ```swift
    /// ScrollView {
    ///     content
    /// }
    /// .vaporFocusBlur(isFocused: isSearchFocused)
    /// ```
    /// - Parameters:
    ///   - isFocused: Whether the focus state is active (blur when true, sharp when false).
    ///   - blurRadius: The blur radius when focused (default 2px for subtle effect, use 4px for stronger effect).
    /// - Returns: A view that blurs based on focus state.
    public func vaporFocusBlur(isFocused: Bool, blurRadius: CGFloat = 2) -> some View {
        modifier(VaporFocusBlurModifier(isFocused: isFocused, blurRadius: blurRadius))
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

    /// Applies the vapor-exit animation controlled by an isPresented binding.
    /// The view animates in when isPresented becomes true, and animates out when it becomes false.
    /// - Parameter isPresented: Binding to the presentation state.
    /// - Returns: A view that animates with the vapor effect based on presentation state.
    public func vaporExit(isPresented: Binding<Bool>) -> some View {
        modifier(VaporExitModifier(isPresented: isPresented))
    }

    /// Applies vapor-drift animation timing to navigation transitions.
    /// This modifier overrides the default navigation animation with the brand-standard
    /// vapor-drift curve (400ms, cubic-bezier 0.25, 0.1, 0.25, 1).
    ///
    /// Apply this to NavigationStack destinations for consistent page transitions:
    /// ```swift
    /// NavigationStack(path: $path) {
    ///     RootView()
    /// } destination: { route in
    ///     DestinationView(route: route)
    ///         .vaporNavigationTransition()
    /// }
    /// ```
    /// - Returns: A view with vapor-drift navigation animation timing.
    public func vaporNavigationTransition() -> some View {
        modifier(VaporNavigationTransitionModifier())
    }
}

// MARK: - Vapor Navigation Transition Modifier

/// A view modifier that applies the vapor-drift timing curve to navigation transitions.
/// Implements the brand animation specification for page transitions:
/// - Duration: 400ms
/// - Curve: vapor-drift (cubic-bezier 0.25, 0.1, 0.25, 1) - Positional movement
///
/// This modifier overrides the default SwiftUI navigation animation by intercepting
/// the transaction and replacing it with the vapor-drift timing curve.
public struct VaporNavigationTransitionModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .transaction { transaction in
                // Override navigation animation with vapor-drift curve
                transaction.animation = VaporAnimation.driftCurve.animation(
                    duration: VaporAnimation.pageDuration
                )
            }
    }
}

// MARK: - Vapor Page Transition

/// A custom transition that applies the vapor-drift animation for page-level navigation.
/// Uses opacity and horizontal slide with vapor-drift timing.
///
/// Example:
/// ```swift
/// if showDetail {
///     DetailView()
///         .transition(.vaporPage)
/// }
/// ```
public extension AnyTransition {
    /// A transition for page-level navigation that slides horizontally with fade.
    /// - Insertion: slides in from right, fades in
    /// - Removal: slides out to left, fades out
    /// Uses vapor-drift timing curve.
    static var vaporPage: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: VaporPageTransitionModifier(offset: 50, opacity: 0),
                identity: VaporPageTransitionModifier(offset: 0, opacity: 1)
            ),
            removal: .modifier(
                active: VaporPageTransitionModifier(offset: -50, opacity: 0),
                identity: VaporPageTransitionModifier(offset: 0, opacity: 1)
            )
        )
    }

    /// A transition for page-level navigation that slides back (opposite of vaporPage).
    /// - Insertion: slides in from left, fades in
    /// - Removal: slides out to right, fades out
    /// Uses vapor-drift timing curve.
    static var vaporPageBack: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: VaporPageTransitionModifier(offset: -50, opacity: 0),
                identity: VaporPageTransitionModifier(offset: 0, opacity: 1)
            ),
            removal: .modifier(
                active: VaporPageTransitionModifier(offset: 50, opacity: 0),
                identity: VaporPageTransitionModifier(offset: 0, opacity: 1)
            )
        )
    }
}

/// Internal modifier used by the vaporPage transition.
private struct VaporPageTransitionModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
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

struct VaporExitModifier_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var isPresented = true

        var body: some View {
            VStack(spacing: 24) {
                Button(isPresented ? "Hide Content" : "Show Content") {
                    isPresented.toggle()
                }
                .buttonStyle(.borderedProminent)

                if isPresented {
                    VStack(spacing: 12) {
                        Text("This content will fade out")
                            .font(.headline)
                        Text("Using the vapor-exit animation")
                            .font(.caption)
                            .foregroundColor(VaporColor.textSecondary)
                    }
                    .padding()
                    .background(VaporColor.haze)
                    .cornerRadius(VaporRadius.md)
                    .transition(.vaporExit)
                }

                Spacer()
            }
            .animation(VaporAnimation.exitCurve.animation(duration: VaporAnimation.normalDuration), value: isPresented)
            .padding()
            .background(VaporColor.mist)
        }
    }

    static var previews: some View {
        PreviewContainer()
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

struct VaporFocusBlurModifier_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var isFocused = false

        var body: some View {
            VStack(spacing: 24) {
                // Control button
                Button(isFocused ? "Release Focus" : "Focus Search") {
                    withAnimation {
                        isFocused.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)

                // Simulated search field
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(isFocused ? "Type here..." : "Search transcripts...")
                        .foregroundColor(VaporColor.textTertiary)
                    Spacer()
                }
                .padding()
                .background(VaporColor.cloud)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isFocused ? VaporColor.sky : VaporColor.fog, lineWidth: 1)
                )

                // Background content that blurs when search is focused
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack {
                            Circle()
                                .fill(VaporColor.sky)
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading) {
                                Text("Session \(index + 1)")
                                    .font(.headline)
                                Text("Content that blurs when search is active")
                                    .font(.caption)
                                    .foregroundColor(VaporColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(VaporColor.cloud)
                        .cornerRadius(12)
                    }
                }
                .vaporFocusBlur(isFocused: isFocused)

                Spacer()
            }
            .padding()
            .background(VaporColor.mist)
        }
    }

    static var previews: some View {
        PreviewContainer()
    }
}
#endif
