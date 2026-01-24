import Foundation

/// App environment configuration for switching between live and UI testing modes
public enum AppEnvironment {
    case live
    case uiTesting

    /// Determine the current environment based on launch arguments
    public static var current: AppEnvironment {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return .uiTesting
        }
        return .live
    }

    /// Whether we're running UI tests
    public var isUITesting: Bool {
        self == .uiTesting
    }
}
