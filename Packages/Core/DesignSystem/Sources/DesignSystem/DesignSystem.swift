import SwiftUI

public enum VaporColors {
    public static let cloud = Color(hex: "#F5F5F5")
    public static let mist = Color(hex: "#E0E0E0")
}

// MARK: - Name Utilities

/// Utilities for processing names for display.
public enum NameUtils {
    /// Strips parenthetical content from a name for initials calculation.
    /// For example: "You (John Smith)" becomes "You", "Alice (Work)" becomes "Alice"
    public static func stripParentheticalContent(_ name: String) -> String {
        // Remove anything in parentheses and trim whitespace
        let cleaned = name.components(separatedBy: "(").first?
            .trimmingCharacters(in: .whitespaces) ?? name
        return cleaned
    }

    /// Computes initials from a name, stripping any parenthetical content first.
    /// - Parameter name: The full name (may contain parentheses like "Alice (Work)")
    /// - Returns: Uppercase initials (e.g., "AL" for "Alice" or "JS" for "John Smith")
    public static func computeInitials(from name: String) -> String {
        let cleanName = stripParentheticalContent(name)
        let trimmed = cleanName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let components = trimmed.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[components.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first?.prefix(1) {
            return String(first).uppercased()
        }
        return ""
    }
}

// MARK: - Binding Helpers

/// Helpers for creating derived bindings without using `Binding.init(get:set:)` directly at call sites.
/// Use these static methods instead of `Binding(get:set:)` in SwiftUI views.
extension Binding where Value == Bool {
    /// Creates a dismiss binding from a boolean value that sends an action when the value becomes `false`.
    ///
    /// Use instead of `Binding(get: { boolValue }, set: { if !$0 { dismiss() } })`.
    ///
    /// Usage:
    /// ```
    /// .sheet(isPresented: .dismiss(store.isShowing) { store.send(.dismissed) }) { ... }
    /// ```
    public static func dismiss(
        _ value: @escaping @autoclosure @MainActor () -> Bool,
        send action: @escaping @MainActor () -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { value() },
            set: { if !$0 { action() } }
        )
    }

    /// Creates a boolean binding from an optional value, `true` when non-nil.
    /// Sends an action when the binding becomes `false` (dismissed).
    ///
    /// Use instead of `Binding(get: { optValue != nil }, set: { if !$0 { dismiss() } })`.
    ///
    /// Usage:
    /// ```
    /// .sheet(isPresented: .isPresent(store.shareURL) { store.send(.dismissed) }) { ... }
    /// ```
    public static func isPresent<T>(
        _ value: @escaping @autoclosure @MainActor () -> T?,
        onDismiss action: @escaping @MainActor () -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { value() != nil },
            set: { if !$0 { action() } }
        )
    }
}

extension Binding {
    /// Creates a dismiss binding from an optional value.
    /// Sends an action when the value becomes `nil` (dismissed).
    ///
    /// Use instead of `Binding(get: { optValue }, set: { if $0 == nil { dismiss() } })`.
    ///
    /// Usage:
    /// ```
    /// .alert(item: .onNilDismiss(store.alertInfo) { store.send(.alertDismissed) }) { ... }
    /// ```
    public static func onNilDismiss<Wrapped>(
        _ value: @escaping @autoclosure @MainActor () -> Wrapped?,
        send action: @escaping @MainActor () -> Void
    ) -> Binding<Wrapped?> {
        Binding<Wrapped?>(
            get: { value() },
            set: { if $0 == nil { action() } }
        )
    }
}

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
