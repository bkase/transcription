import Foundation
import Dependencies
import DependenciesMacros

#if os(iOS)
import UIKit
#endif

// MARK: - Profile Image Client

/// Client for normalizing profile images.
/// Provides deterministic image processing hooks for downscaling and compression.
@DependencyClient
public struct ProfileImageClient: Sendable {
    /// Normalize image data by downscaling and compressing.
    /// - Parameters:
    ///   - data: Raw image data (e.g., from photo picker)
    ///   - maxDimension: Maximum width or height in pixels (default 256)
    ///   - compressionQuality: JPEG compression quality 0.0-1.0 (default 0.8)
    /// - Returns: Normalized image data, or nil if processing fails
    public var normalize: @Sendable (
        _ data: Data,
        _ maxDimension: Int,
        _ compressionQuality: Double
    ) async -> Data? = { _, _, _ in nil }
}

// MARK: - Errors

public enum ProfileImageClientError: Error, Sendable, Equatable {
    case imageCreationFailed
    case resizeFailed
    case compressionFailed
}

// MARK: - Dependency Key

extension ProfileImageClient: DependencyKey {
    #if os(iOS)
    public static var liveValue: Self {
        Self(
            normalize: { data, maxDimension, compressionQuality in
                guard let image = UIImage(data: data) else {
                    return nil
                }

                // Calculate scale to fit within maxDimension
                let size = image.size
                let scale: CGFloat
                if size.width > size.height {
                    scale = CGFloat(maxDimension) / size.width
                } else {
                    scale = CGFloat(maxDimension) / size.height
                }

                // Only downscale if image is larger than maxDimension
                let finalImage: UIImage
                if scale < 1.0 {
                    let newSize = CGSize(
                        width: size.width * scale,
                        height: size.height * scale
                    )

                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    defer { UIGraphicsEndImageContext() }

                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    guard let resized = UIGraphicsGetImageFromCurrentImageContext() else {
                        return nil
                    }
                    finalImage = resized
                } else {
                    finalImage = image
                }

                // Compress as JPEG
                return finalImage.jpegData(compressionQuality: compressionQuality)
            }
        )
    }
    #else
    // macOS fallback - just pass through data unchanged for now
    public static var liveValue: Self {
        Self(
            normalize: { data, _, _ in data }
        )
    }
    #endif

    public static var testValue: Self { Self() }
}

extension DependencyValues {
    public var profileImageClient: ProfileImageClient {
        get { self[ProfileImageClient.self] }
        set { self[ProfileImageClient.self] = newValue }
    }
}

// MARK: - Test Implementations

extension ProfileImageClient {
    /// A test implementation that returns data unchanged (passthrough).
    public static let passthrough = Self(
        normalize: { data, _, _ in data }
    )

    /// A test implementation that always returns nil (simulates failure).
    public static let alwaysFails = Self(
        normalize: { _, _, _ in nil }
    )

    /// A test implementation that returns a fixed result.
    public static func fixed(_ result: Data?) -> Self {
        Self(
            normalize: { _, _, _ in result }
        )
    }
}
