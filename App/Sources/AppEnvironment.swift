import Foundation

/// App environment configuration for switching between live and UI testing modes
public enum AppEnvironment {
    case live
    case uiTesting(scenario: UITestScenario)

    /// UI testing scenarios for different error states and flows
    public enum UITestScenario: Equatable {
        /// Default happy path with models ready and successful transcription
        case normal
        /// Model download fails (shows error banner on timeline, disabled FAB)
        case modelDownloadFailure
        /// Offline transcription fails after recording (session shows failed state)
        case transcriptionFailure
    }

    /// Determine the current environment based on launch arguments
    public static var current: AppEnvironment {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTesting") {
            let scenario = parseUITestScenario(from: args)
            return .uiTesting(scenario: scenario)
        }
        return .live
    }

    /// Parse the UI test scenario from launch arguments
    private static func parseUITestScenario(from args: [String]) -> UITestScenario {
        if args.contains("-modelDownloadFailure") {
            return .modelDownloadFailure
        } else if args.contains("-transcriptionFailure") {
            return .transcriptionFailure
        }
        return .normal
    }

    /// Whether we're running UI tests
    public var isUITesting: Bool {
        if case .uiTesting = self {
            return true
        }
        return false
    }

    /// Get the UI test scenario if in UI testing mode
    public var uiTestScenario: UITestScenario? {
        if case .uiTesting(let scenario) = self {
            return scenario
        }
        return nil
    }
}
