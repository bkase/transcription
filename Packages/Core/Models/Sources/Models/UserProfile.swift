import Foundation

// MARK: - UserProfile

/// Domain model representing the local user's profile.
/// Stores identity information locally for a local-first experience.
public struct UserProfile: Sendable, Equatable, Codable, Hashable {
    /// The user's full name (e.g., "Jane Doe").
    public var name: String

    /// Optional email address. Local-only for now; may be used for export metadata.
    public var email: String?

    /// The user's profile avatar.
    public var avatar: Avatar

    /// Creates a new UserProfile with the provided values.
    public init(name: String = "", email: String? = nil, avatar: Avatar = Avatar()) {
        self.name = name
        self.email = email
        self.avatar = avatar
    }

    /// Sensible default for a new user with no profile data yet.
    public static let empty = UserProfile()
}

// MARK: - Avatar

extension UserProfile {
    /// Represents the user's profile avatar image.
    /// MVP stores image data directly; future versions may use file paths.
    public struct Avatar: Sendable, Equatable, Codable, Hashable {
        /// Compressed image data (e.g., JPEG).
        /// When nil, UI should display initials or a placeholder.
        public var imageData: Data?

        /// Creates an Avatar with optional image data.
        public init(imageData: Data? = nil) {
            self.imageData = imageData
        }

        /// Empty avatar with no image data.
        public static let empty = Avatar()
    }
}
