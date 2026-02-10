import Foundation

// MARK: - Mock Photo Data

/// Generates deterministic test image data for UI testing.
/// Each index produces a unique colored square image.
public enum MockPhotoData {
    /// Available mock photo options for the UI test picker
    public static let options: [(name: String, color: String)] = [
        ("Blue Square", "blue"),
        ("Green Square", "green"),
        ("Red Square", "red"),
    ]

    /// Generate deterministic image data for a given index.
    /// Returns a small PNG-like data blob that can be identified by index.
    public static func imageData(forIndex index: Int) -> Data {
        // Create a simple identifiable data pattern
        // In a real scenario this would be actual image data,
        // but for testing we just need deterministic bytes
        let header: [UInt8] = [0x89, 0x50, 0x4E, 0x47] // PNG header
        let indexBytes = withUnsafeBytes(of: UInt32(index).bigEndian) { Array($0) }
        // Add some padding to make it look more like real image data
        let padding: [UInt8] = Array(repeating: UInt8(index % 256), count: 100)
        return Data(header + indexBytes + padding)
    }
}
