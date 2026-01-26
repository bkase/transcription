import Foundation
import Dependencies
import DependenciesMacros
import Models

// MARK: - User Profile Client

/// Client for persisting and loading user profile data.
/// Uses UserDefaults for storage with JSON encoding.
@DependencyClient
public struct UserProfileClient: Sendable {
    /// Load the current user profile from storage.
    /// Returns UserProfile.empty if no profile has been saved.
    public var load: @Sendable () async throws -> UserProfile = { .empty }

    /// Save the user profile to storage.
    public var save: @Sendable (_ profile: UserProfile) async throws -> Void
}

// MARK: - Errors

public enum UserProfileClientError: Error, Sendable, Equatable {
    case encodingFailed
    case decodingFailed(String)
}

// MARK: - Dependency Key

extension UserProfileClient: DependencyKey {
    private static let storageKey = "com.vapor.userProfile"

    public static let liveValue: Self = {
        Self(
            load: {
                guard let data = UserDefaults.standard.data(forKey: storageKey) else {
                    return .empty
                }
                do {
                    let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                    return profile
                } catch {
                    throw UserProfileClientError.decodingFailed(error.localizedDescription)
                }
            },
            save: { profile in
                do {
                    let data = try JSONEncoder().encode(profile)
                    UserDefaults.standard.set(data, forKey: storageKey)
                } catch {
                    throw UserProfileClientError.encodingFailed
                }
            }
        )
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var userProfileClient: UserProfileClient {
        get { self[UserProfileClient.self] }
        set { self[UserProfileClient.self] = newValue }
    }
}

// MARK: - In-Memory Test Implementation

/// Thread-safe in-memory storage for testing UserProfileClient.
public actor InMemoryProfileStorage {
    public var profile: UserProfile

    public init(profile: UserProfile = .empty) {
        self.profile = profile
    }

    public func load() -> UserProfile {
        profile
    }

    public func save(_ newProfile: UserProfile) {
        self.profile = newProfile
    }
}

extension UserProfileClient {
    /// Creates an in-memory test client backed by the provided storage actor.
    /// Useful for testing save/load behavior without touching UserDefaults.
    public static func inMemory(storage: InMemoryProfileStorage) -> Self {
        Self(
            load: {
                await storage.load()
            },
            save: { profile in
                await storage.save(profile)
            }
        )
    }
}
