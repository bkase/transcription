import ComposableArchitecture
import Export
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

        await store.receive(\.profileSaved) {
            $0.isSaving = false
        }

        await store.receive(\.delegate.didSaveProfile)

        // Verify storage was updated
        let savedProfile = await profileStorage.load()
        #expect(savedProfile.name == "Jane Doe")
        #expect(savedProfile.email == "brandon@example.com")
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

    @Test
    func saveNameFailure() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Save failed" }
        }

        let store = TestStore(initialState: ProfileFeature.State(
            profile: testProfile,
            isEditingName: true,
            editingNameText: "New Name"
        )) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient.save = { _ in throw TestError() }
        }

        await store.send(.saveNameTapped) {
            $0.isSaving = true
            $0.profile.name = "New Name"
            $0.isEditingName = false
        }

        await store.receive(\.profileSaveFailed) {
            $0.isSaving = false
            $0.error = "Save failed"
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

    @Test
    func photoSaveFailure() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Storage error" }
        }

        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        } withDependencies: {
            $0.profileImageClient.normalize = { _, _, _ in normalizedPhotoData }
            $0.userProfileClient.save = { _ in throw TestError() }
        }

        await store.send(.photoPicked(testPhotoData)) {
            $0.isSaving = true
        }

        await store.receive(\.photoProcessed) {
            $0.profile.avatar = UserProfile.Avatar(imageData: normalizedPhotoData)
        }

        await store.receive(\.profileSaveFailed) {
            $0.isSaving = false
            $0.error = "Storage error"
        }
    }

    @Test
    func removePhoto() async throws {
        let profileWithPhoto = UserProfile(
            name: "Brandon Kase",
            email: "brandon@example.com",
            avatar: UserProfile.Avatar(imageData: testPhotoData)
        )
        let profileStorage = InMemoryProfileStorage(profile: profileWithPhoto)

        let store = TestStore(initialState: ProfileFeature.State(profile: profileWithPhoto)) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient = .inMemory(storage: profileStorage)
        }

        await store.send(.removePhotoTapped) {
            $0.isSaving = true
            $0.profile.avatar = UserProfile.Avatar(imageData: nil)
        }

        await store.receive(\.profileSaved) {
            $0.isSaving = false
        }

        await store.receive(\.delegate.didSaveProfile)

        // Verify storage was updated
        let savedProfile = await profileStorage.load()
        #expect(savedProfile.avatar.imageData == nil)
    }

    @Test
    func removePhotoWhenNoPhotoDoesNothing() async throws {
        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        }

        // Removing when no photo exists should do nothing
        await store.send(.removePhotoTapped)
        // No state changes or effects expected
    }

    @Test
    func removePhotoFailure() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Storage error" }
        }

        let profileWithPhoto = UserProfile(
            name: "Brandon Kase",
            email: "brandon@example.com",
            avatar: UserProfile.Avatar(imageData: testPhotoData)
        )

        let store = TestStore(initialState: ProfileFeature.State(profile: profileWithPhoto)) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient.save = { _ in throw TestError() }
        }

        await store.send(.removePhotoTapped) {
            $0.isSaving = true
            $0.profile.avatar = UserProfile.Avatar(imageData: nil)
        }

        await store.receive(\.profileSaveFailed) {
            $0.isSaving = false
            $0.error = "Storage error"
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

    @Test
    func initialsFromNameWithParentheses() {
        // Parenthetical content should be stripped before computing initials
        let state = ProfileFeature.State(profile: UserProfile(name: "Alice (Work)"))
        #expect(state.initials == "A")
    }

    @Test
    func initialsFromMultiWordNameWithParentheses() {
        // "Mary Jane (Personal)" -> strips to "Mary Jane" -> "MJ"
        let state = ProfileFeature.State(profile: UserProfile(name: "Mary Jane (Personal)"))
        #expect(state.initials == "MJ")
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

    // MARK: - Mock Photo Picker Tests (UI Testing)

    @Test
    func showMockPhotoPicker() async throws {
        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        }

        await store.send(.showMockPhotoPicker) {
            $0.isShowingMockPhotoPicker = true
        }
    }

    @Test
    func dismissMockPhotoPicker() async throws {
        let store = TestStore(initialState: ProfileFeature.State(
            profile: testProfile,
            isShowingMockPhotoPicker: true
        )) {
            ProfileFeature()
        }

        await store.send(.dismissMockPhotoPicker) {
            $0.isShowingMockPhotoPicker = false
        }
    }

    @Test
    func mockPhotoSelectedTriggersPhotoPicked() async throws {
        let profileStorage = InMemoryProfileStorage(profile: testProfile)

        let store = TestStore(initialState: ProfileFeature.State(
            profile: testProfile,
            isShowingMockPhotoPicker: true
        )) {
            ProfileFeature()
        } withDependencies: {
            $0.userProfileClient = .inMemory(storage: profileStorage)
            $0.profileImageClient.normalize = { data, _, _ in data } // passthrough
        }

        // Select mock photo at index 1 (Green Square)
        await store.send(.mockPhotoSelected(1)) {
            $0.isShowingMockPhotoPicker = false
        }

        // Should receive photoPicked with deterministic test data
        let expectedData = MockPhotoData.imageData(forIndex: 1)

        await store.receive(\.photoPicked) {
            $0.isSaving = true
        }

        await store.receive(\.photoProcessed) {
            $0.profile.avatar = UserProfile.Avatar(imageData: expectedData)
        }

        await store.receive(\.profileSaved) {
            $0.isSaving = false
        }

        await store.receive(\.delegate.didSaveProfile)

        // Verify storage was updated
        let savedProfile = await profileStorage.load()
        #expect(savedProfile.avatar.imageData == expectedData)
    }

    @Test
    func mockPhotoDataGeneratesDeterministicBytes() {
        // Test that MockPhotoData generates consistent data for same index
        let data1 = MockPhotoData.imageData(forIndex: 0)
        let data2 = MockPhotoData.imageData(forIndex: 0)
        #expect(data1 == data2)

        // Different indices produce different data
        let data3 = MockPhotoData.imageData(forIndex: 1)
        #expect(data1 != data3)

        // Data starts with PNG header
        let header = Array(data1.prefix(4))
        #expect(header == [0x89, 0x50, 0x4E, 0x47])
    }

    // MARK: - Export All Conversations Tests

    @Test
    func exportAllTappedStartsExport() async throws {
        let exportURL = URL(fileURLWithPath: "/tmp/test-export.zip")

        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        } withDependencies: {
            $0.exportClient.exportAllSessions = { exportURL }
        }

        await store.send(.exportAllTapped) {
            $0.isExporting = true
        }

        await store.receive(\.exportAllCompleted) {
            $0.isExporting = false
            $0.shareURL = exportURL
        }
    }

    @Test
    func exportAllDoesNothingWhileExporting() async throws {
        let store = TestStore(initialState: ProfileFeature.State(
            profile: testProfile,
            isExporting: true
        )) {
            ProfileFeature()
        }

        await store.send(.exportAllTapped)
        // No state changes or effects expected
    }

    @Test
    func exportAllFailure() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Export failed" }
        }

        let store = TestStore(initialState: ProfileFeature.State(profile: testProfile)) {
            ProfileFeature()
        } withDependencies: {
            $0.exportClient.exportAllSessions = { throw TestError() }
        }

        await store.send(.exportAllTapped) {
            $0.isExporting = true
        }

        await store.receive(\.exportAllFailed) {
            $0.isExporting = false
            $0.error = "Export failed"
        }
    }

    @Test
    func shareSheetDismissedClearsURL() async throws {
        let exportURL = URL(fileURLWithPath: "/tmp/test-export.zip")

        let store = TestStore(initialState: ProfileFeature.State(
            profile: testProfile,
            shareURL: exportURL
        )) {
            ProfileFeature()
        }

        await store.send(.shareSheetDismissed) {
            $0.shareURL = nil
        }
    }
}
