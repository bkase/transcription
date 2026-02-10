import Foundation

/// Polls a condition at short intervals until it becomes true, or throws after a timeout.
/// Replaces flaky `Task.sleep` calls with deterministic condition-based waiting.
///
/// - Parameters:
///   - timeout: Maximum time to wait (default 2 seconds, generous for CI)
///   - pollInterval: How often to check the condition (default 10ms)
///   - description: Description for the timeout error message
///   - condition: Async closure that returns true when the condition is met
func waitUntil(
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(10),
    _ description: String = "condition",
    _ condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: pollInterval)
    }
    // Final check
    if await condition() { return }
    struct WaitTimeout: Error, CustomStringConvertible {
        let description: String
    }
    throw WaitTimeout(description: "waitUntil timed out waiting for: \(description)")
}
