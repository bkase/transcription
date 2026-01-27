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
#endif
