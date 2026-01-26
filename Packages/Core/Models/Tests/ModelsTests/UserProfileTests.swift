import Testing
import Foundation
@testable import Models

@Test func userProfileDefaultsAreEmpty() {
    let profile = UserProfile()

    #expect(profile.name == "")
    #expect(profile.email == nil)
    #expect(profile.avatar.imageData == nil)
}

@Test func userProfileStaticEmptyMatchesDefault() {
    let defaultProfile = UserProfile()
    let emptyProfile = UserProfile.empty

    #expect(defaultProfile == emptyProfile)
}

@Test func userProfileWithValues() {
    let avatarData = Data([0x00, 0x01, 0x02])
    let avatar = UserProfile.Avatar(imageData: avatarData)
    let profile = UserProfile(
        name: "Jane Doe",
        email: "jane@example.com",
        avatar: avatar
    )

    #expect(profile.name == "Jane Doe")
    #expect(profile.email == "jane@example.com")
    #expect(profile.avatar.imageData == avatarData)
}

@Test func userProfileIsCodable() throws {
    let avatarData = Data([0xFF, 0xD8, 0xFF])
    let original = UserProfile(
        name: "Test User",
        email: "test@example.com",
        avatar: UserProfile.Avatar(imageData: avatarData)
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(UserProfile.self, from: data)

    #expect(decoded == original)
}

@Test func userProfileIsEquatable() {
    let profile1 = UserProfile(name: "Alice", email: "alice@example.com")
    let profile2 = UserProfile(name: "Alice", email: "alice@example.com")
    let profile3 = UserProfile(name: "Bob", email: "bob@example.com")

    #expect(profile1 == profile2)
    #expect(profile1 != profile3)
}

@Test func avatarEmptyMatchesDefault() {
    let defaultAvatar = UserProfile.Avatar()
    let emptyAvatar = UserProfile.Avatar.empty

    #expect(defaultAvatar == emptyAvatar)
    #expect(emptyAvatar.imageData == nil)
}
