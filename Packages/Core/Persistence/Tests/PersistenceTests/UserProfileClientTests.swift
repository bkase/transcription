import Testing
import Foundation
@testable import Persistence
import Models

// MARK: - In-Memory Client Tests

@Test func testInMemoryClientLoadsEmptyByDefault() async throws {
    let storage = InMemoryProfileStorage()
    let client = UserProfileClient.inMemory(storage: storage)

    let loaded = try await client.load()
    #expect(loaded == .empty)
}

@Test func testInMemoryClientSaveAndLoad() async throws {
    let storage = InMemoryProfileStorage()
    let client = UserProfileClient.inMemory(storage: storage)

    let profile = UserProfile(
        name: "Test User",
        email: "test@example.com",
        avatar: .empty
    )

    try await client.save(profile)
    let loaded = try await client.load()

    #expect(loaded == profile)
    #expect(loaded.name == "Test User")
    #expect(loaded.email == "test@example.com")
}

@Test func testInMemoryClientPreservesAvatarData() async throws {
    let storage = InMemoryProfileStorage()
    let client = UserProfileClient.inMemory(storage: storage)

    let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
    let profile = UserProfile(
        name: "Avatar User",
        avatar: UserProfile.Avatar(imageData: imageData)
    )

    try await client.save(profile)
    let loaded = try await client.load()

    #expect(loaded.avatar.imageData == imageData)
}

@Test func testInMemoryClientOverwritesPreviousSave() async throws {
    let storage = InMemoryProfileStorage()
    let client = UserProfileClient.inMemory(storage: storage)

    let profile1 = UserProfile(name: "First")
    let profile2 = UserProfile(name: "Second")

    try await client.save(profile1)
    try await client.save(profile2)
    let loaded = try await client.load()

    #expect(loaded.name == "Second")
}

@Test func testInMemoryClientWithPreloadedData() async throws {
    let initial = UserProfile(name: "Preloaded", email: "preload@test.com")
    let storage = InMemoryProfileStorage(profile: initial)
    let client = UserProfileClient.inMemory(storage: storage)

    let loaded = try await client.load()
    #expect(loaded == initial)
}

// MARK: - Shared Storage Tests

@Test func testMultipleClientsShareStorage() async throws {
    let storage = InMemoryProfileStorage()
    let client1 = UserProfileClient.inMemory(storage: storage)
    let client2 = UserProfileClient.inMemory(storage: storage)

    let profile = UserProfile(name: "Shared")
    try await client1.save(profile)

    let loaded = try await client2.load()
    #expect(loaded.name == "Shared")
}
