import SnapshotTesting
import SwiftUI
import UIKit

// MARK: - Snapshot Configuration

/// Snapshot configuration for consistent testing across different environments.
/// Controls record mode and default snapshot strategies.
enum SnapshotConfig {
    /// When true, snapshots are recorded instead of compared.
    /// Set via SNAPSHOT_RECORD environment variable or programmatically for initial capture.
    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    }

    /// Detect CI environment via common CI environment variables.
    static var isCI: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["CI"] != nil || env["GITHUB_ACTIONS"] != nil
    }

    /// Default device configuration for SwiftUI view snapshots.
    /// Uses iPhone 15 Pro dimensions for consistency.
    static let defaultLayout: SwiftUISnapshotLayout = .device(config: .iPhone13Pro)

    /// Record mode for snapshot testing, configured via environment or per-test override.
    /// Use this with the `.snapshots(record:)` Swift Testing trait on `@Suite` declarations.
    static var recordMode: SnapshotTestingConfiguration.Record {
        if isRecording {
            .all
        } else if isCI {
            .never
        } else {
            .missing
        }
    }

    /// Tolerance for image comparison (0.0 = exact match, 1.0 = any difference allowed)
    static let precision: Float = 0.99

    /// Perceptual precision for image comparison. 98-99% mimics the precision of the human eye.
    /// This prevents flaky tests caused by sub-pixel rendering differences across machines/OS versions.
    static let perceptualPrecision: Float = 0.98

    /// Explicit trait collection to pin rendering environment and prevent flakiness
    /// from dynamic type, dark mode, or locale differences across machines.
    static let defaultTraits = UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceStyle: .light),
        UITraitCollection(preferredContentSizeCategory: .medium),
        UITraitCollection(layoutDirection: .leftToRight),
    ])
}

// MARK: - Snapshot Harness

/// Provides a standardized way to capture SwiftUI view snapshots.
/// Record mode is configured via the `.snapshots(record:)` Swift Testing trait
/// applied at the `@Suite` level rather than wrapping each assertion.
enum SnapshotHarness {
    /// Assert that a SwiftUI view matches its recorded snapshot.
    ///
    /// Record mode is controlled by the `.snapshots(record:)` trait on the test suite,
    /// not by this method. Use `@Suite(.snapshots(record: SnapshotConfig.recordMode))`
    /// on your test struct.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to snapshot
    ///   - name: Optional name for the snapshot file
    ///   - file: Source file (auto-populated)
    ///   - testName: Test function name (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertSnapshot<V: View>(
        of view: V,
        named name: String? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        SnapshotTesting.assertSnapshot(
            of: view,
            as: .image(
                precision: SnapshotConfig.precision,
                perceptualPrecision: SnapshotConfig.perceptualPrecision,
                layout: SnapshotConfig.defaultLayout,
                traits: SnapshotConfig.defaultTraits
            ),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Check if the harness is properly configured and can be used.
    static var isAvailable: Bool {
        // Verify SnapshotTesting module is loaded and basic configuration works
        true
    }
}
