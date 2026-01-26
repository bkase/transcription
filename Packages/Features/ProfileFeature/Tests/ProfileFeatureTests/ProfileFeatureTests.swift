import ComposableArchitecture
import Foundation
import Models
import Persistence
import Testing

@testable import ProfileFeature

// MARK: - Test Data

private let testProfile = UserProfile(
    name: "Brandon Kase",
    email: "brandon@example.com",
    avatar: .empty
)

private let testPhotoData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
private let normalizedPhotoData = Data([0xFF, 0xD8, 0xFF]) // JPEG header bytes

// MARK: - Profile Feature Tests

@MainActor
struct ProfileFeatureTests {

    // MARK: - Load Profile Tests

    @Test
    func loadProfileOnAppear() async throws {
        let store = TestStore(initialState: ProfileFeature.State()) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient.load = { testProfile }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.profileLoaded) {
            $0.isLoading = false
            $0.profile = testProfile
        }
    }

    @Test
    func loadProfileFailure() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }

        let store = TestStore(initialState: ProfileFeature.State()) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient.load = { throw TestError() }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.profileLoadFailed) {
            $0.isLoading = false
            $0.error = "Test error"
        }
    }

    @Test
    func onAppearSkipsLoadWhenAlreadyLoaded() async throws {
        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        }

        await store.send(.onAppear)
        // No actions received - load is skipped
    }

    // MARK: - Name Editing Tests

    @Test
    func editNameFlow() async throws {
        let profileStorage = InMemoryProfileStorage(profile: testProfile)

        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient = .inMemory(storage: profileStorage)
        }

        // Start editing
        await store.send(.editNameTapped) {
            $0.isEditingName = true
            $0.editingNameText = "Brandon Kase"
        }

        // Change the text
        await store.send(.editingNameChanged("Jane Doe")) {
            $0.editingNameText = "Jane Doe"
        }

        // Save
        await store.send(.saveNameTapped) {
            $0.isSaving = true
            $0.profile.name = "Jane Doe"
            $0.isEditingName = false
        }

        let expectedProfile = UserProfile(
            name: "Jane Doe",
            email: "brandon@example.com",
            avatar: .empty
        )

        await store.receive(\.profileSaved) {
            $0.isSaving = false
        }

        await store.receive(\.delegate.didSaveProfile)

        // Verify storage was updated
        let savedProfile = await profileStorage.load()
        #expect(savedProfile.name == "Jane Doe")
    }

    @Test
    func cancelNameEdit() async throws {
        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        }

        // Start editing
        await store.send(.editNameTapped) {
            $0.isEditingName = true
            $0.editingNameText = "Brandon Kase"
        }

        // Change the text
        await store.send(.editingNameChanged("New Name")) {
            $0.editingNameText = "New Name"
        }

        // Cancel
        await store.send(.cancelEditNameTapped) {
            $0.isEditingName = false
            $0.editingNameText = ""
        }

        // Profile should be unchanged
        #expect(store.state.profile.name == "Brandon Kase")
    }

    @Test
    func saveEmptyNameShowsError() async throws {
        let store = TestStore(initialState: ProfileFeature.State(
            profile: testProfile,
            isEditingName: true,
            editingNameText: "   "
        )) {
            ProfileFeature()
        }

        await store.send(.saveNameTapped) {
            $0.error = "Name cannot be empty"
        }
    }

    // MARK: - Photo Tests

    @Test
    func photoPickedAndProcessed() async throws {
        let profileStorage = InMemoryProfileStorage(profile: testProfile)

        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient = .inMemory(storage: profileStorage)
            $0.profileImageClient.normalize = { _, _, _ in normalizedPhotoData }
        }

        await store.send(.photoPicked(testPhotoData)) {
            $0.isSaving = true
        }

        await store.receive(\.photoProcessed) {
            $0.profile.avatar = UserProfile.Avatar(imageData: normalizedPhotoData)
        }

        await store.receive(\.profileSaved) {
            $0.isSaving = false
        }

        await store.receive(\.delegate.didSaveProfile)

        // Verify storage was updated
        let savedProfile = await profileStorage.load()
        #expect(savedProfile.avatar.imageData == normalizedPhotoData)
    }

    @Test
    func photoProcessingFailure() async throws {
        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        } withDependencies: {
            $0.profileImageClient.normalize = { _, _, _ in nil }
        }

        await store.send(.photoPicked(testPhotoData)) {
            $0.isSaving = true
        }

        await store.receive(\.photoProcessed) {
            $0.isSaving = false
            $0.error = "Failed to process image"
        }
    }

    // MARK: - Initials Tests

    @Test
    func initialsFromFullName() {
        let state = ProfileFeature.State(profile: UserProfile(name: "Brandon Kase"))
        #expect(state.initials == "BK")
    }

    @Test
    func initialsFromSingleName() {
        let state = ProfileFeature.State(profile: UserProfile(name: "Brandon"))
        #expect(state.initials == "B")
    }

    @Test
    func initialsFromEmptyName() {
        let state = ProfileFeature.State(profile: UserProfile(name: ""))
        #expect(state.initials == "")
    }

    @Test
    func initialsFromMultiWordName() {
        let state = ProfileFeature.State(profile: UserProfile(name: "Mary Jane Watson"))
        #expect(state.initials == "MW")
    }

    // MARK: - Back Button Test

    @Test
    func backTappedEmitsNoEffect() async throws {
        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        }

        await store.send(.backTapped)
        // No state changes or effects expected
    }
}
