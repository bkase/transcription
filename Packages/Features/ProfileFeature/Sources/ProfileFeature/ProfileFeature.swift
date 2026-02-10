import CasePaths
import ComposableArchitecture
import Dependencies
import DesignSystem
import Export
import Foundation
import Models
import Persistence

@Reducer
public struct ProfileFeature {
    public init() {}

    @Dependency(\.userProfileClient) var userProfileClient
    @Dependency(\.profileImageClient) var profileImageClient
    @Dependency(\.exportClient) var exportClient
    @Dependency(\.databaseClient) var databaseClient

    /// Presentation destinations for ProfileFeature.
    /// Using an enum eliminates impossible states (e.g. showing both mock photo picker and delete confirmation).
    public enum Destination: Equatable, Sendable {
        case mockPhotoPicker
        case deleteAllDataConfirmation
    }

    @ObservableState
    public struct State: Equatable {
        public var profile: UserProfile
        public var isLoading: Bool
        public var isSaving: Bool
        public var error: String?

        // Edit mode states
        public var isEditingName: Bool
        public var editingNameText: String

        // Presentation destination (replaces individual isShowing* booleans)
        public var destination: Destination?

        // Export all conversations state
        public var isExporting: Bool
        public var shareURL: URL?

        // Delete all data state
        public var isDeletingAllData: Bool

        /// Convenience computed properties for backward compatibility with views
        public var isShowingMockPhotoPicker: Bool {
            destination == .mockPhotoPicker
        }
        public var isShowingDeleteAllDataConfirmation: Bool {
            destination == .deleteAllDataConfirmation
        }

        public init(
            profile: UserProfile = .empty,
            isLoading: Bool = false,
            isSaving: Bool = false,
            error: String? = nil,
            isEditingName: Bool = false,
            editingNameText: String = "",
            destination: Destination? = nil,
            isExporting: Bool = false,
            shareURL: URL? = nil,
            isDeletingAllData: Bool = false
        ) {
            self.profile = profile
            self.isLoading = isLoading
            self.isSaving = isSaving
            self.error = error
            self.isEditingName = isEditingName
            self.editingNameText = editingNameText
            self.destination = destination
            self.isExporting = isExporting
            self.shareURL = shareURL
            self.isDeletingAllData = isDeletingAllData
        }

        /// Compute initials from the profile name for avatar display
        public var initials: String {
            NameUtils.computeInitials(from: profile.name)
        }
    }

    public enum Action: Sendable {
        case onAppear
        case backTapped
        case profileLoaded(UserProfile)
        case profileLoadFailed(String)

        // Photo actions
        case changePhotoTapped
        case photoPicked(Data)
        case photoProcessed(Data?)
        case removePhotoTapped

        // Mock photo picker actions (for UI testing)
        case showMockPhotoPicker
        case mockPhotoSelected(Int)
        case dismissMockPhotoPicker

        // Name editing
        case editNameTapped
        case editingNameChanged(String)
        case saveNameTapped
        case cancelEditNameTapped

        // Save responses
        case profileSaved(UserProfile)
        case profileSaveFailed(String)

        // Export all conversations
        case exportAllTapped
        case exportAllCompleted(URL)
        case exportAllFailed(String)
        case shareSheetDismissed

        // Delete all data
        case deleteAllDataTapped
        case deleteAllDataConfirmed
        case deleteAllDataCancelled
        case deleteAllDataCompleted
        case deleteAllDataFailed(String)

        // Delegate to parent
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case didSaveProfile(UserProfile)
            case didDeleteAllData
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading && state.profile == .empty else {
                    return .none
                }
                state.isLoading = true
                state.error = nil

                return .run { send in
                    let profile = try await userProfileClient.load()
                    await send(.profileLoaded(profile))
                } catch: { error, send in
                    await send(.profileLoadFailed(error.localizedDescription))
                }

            case let .profileLoaded(profile):
                state.isLoading = false
                state.profile = profile
                return .none

            case let .profileLoadFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                return .none

            case .backTapped:
                // Parent handles navigation
                return .none

            case .changePhotoTapped:
                // View layer handles PhotosPicker presentation (live mode)
                // or triggers showMockPhotoPicker (UI testing mode)
                return .none

            case .showMockPhotoPicker:
                state.destination = .mockPhotoPicker
                return .none

            case let .mockPhotoSelected(index):
                state.destination = nil
                // Generate deterministic test image data based on index
                let testImageData = MockPhotoData.imageData(forIndex: index)
                return .send(.photoPicked(testImageData))

            case .dismissMockPhotoPicker:
                state.destination = nil
                return .none

            case let .photoPicked(data):
                state.isSaving = true
                state.error = nil

                return .run { send in
                    let normalizedData = await profileImageClient.normalize(data, 256, 0.8)
                    await send(.photoProcessed(normalizedData))
                }

            case let .photoProcessed(data):
                guard let imageData = data else {
                    state.isSaving = false
                    state.error = "Failed to process image"
                    return .none
                }

                var updatedProfile = state.profile
                updatedProfile.avatar = UserProfile.Avatar(imageData: imageData)
                state.profile = updatedProfile

                return .run { [updatedProfile] send in
                    try await userProfileClient.save(updatedProfile)
                    await send(.profileSaved(updatedProfile))
                } catch: { error, send in
                    await send(.profileSaveFailed(error.localizedDescription))
                }

            case .removePhotoTapped:
                guard state.profile.avatar.imageData != nil else {
                    return .none
                }

                state.isSaving = true
                state.error = nil

                var updatedProfile = state.profile
                updatedProfile.avatar = UserProfile.Avatar(imageData: nil)
                state.profile = updatedProfile

                return .run { [updatedProfile] send in
                    try await userProfileClient.save(updatedProfile)
                    await send(.profileSaved(updatedProfile))
                } catch: { error, send in
                    await send(.profileSaveFailed(error.localizedDescription))
                }

            case .editNameTapped:
                state.isEditingName = true
                state.editingNameText = state.profile.name
                state.error = nil
                return .none

            case let .editingNameChanged(newText):
                state.editingNameText = newText
                return .none

            case .saveNameTapped:
                let trimmedName = state.editingNameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    state.error = "Name cannot be empty"
                    return .none
                }

                state.isSaving = true
                state.error = nil

                var updatedProfile = state.profile
                updatedProfile.name = trimmedName
                state.profile = updatedProfile
                state.isEditingName = false

                return .run { [updatedProfile] send in
                    try await userProfileClient.save(updatedProfile)
                    await send(.profileSaved(updatedProfile))
                } catch: { error, send in
                    await send(.profileSaveFailed(error.localizedDescription))
                }

            case .cancelEditNameTapped:
                state.isEditingName = false
                state.editingNameText = ""
                return .none

            case let .profileSaved(profile):
                state.isSaving = false
                return .send(.delegate(.didSaveProfile(profile)))

            case let .profileSaveFailed(errorMessage):
                state.isSaving = false
                state.error = errorMessage
                return .none

            case .delegate:
                // Handled by parent
                return .none

            // MARK: - Export All Conversations

            case .exportAllTapped:
                guard !state.isExporting else { return .none }
                state.isExporting = true
                state.error = nil

                return .run { send in
                    let bundleURL = try await exportClient.exportAllSessions()
                    await send(.exportAllCompleted(bundleURL))
                } catch: { error, send in
                    await send(.exportAllFailed(error.localizedDescription))
                }

            case let .exportAllCompleted(url):
                state.isExporting = false
                state.shareURL = url
                return .none

            case let .exportAllFailed(errorMessage):
                state.isExporting = false
                state.error = errorMessage
                return .none

            case .shareSheetDismissed:
                state.shareURL = nil
                return .none

            // MARK: - Delete All Data

            case .deleteAllDataTapped:
                state.destination = .deleteAllDataConfirmation
                return .none

            case .deleteAllDataConfirmed:
                state.destination = nil
                state.isDeletingAllData = true
                state.error = nil

                return .run { send in
                    try await databaseClient.deleteAllData()
                    await send(.deleteAllDataCompleted)
                } catch: { error, send in
                    await send(.deleteAllDataFailed(error.localizedDescription))
                }

            case .deleteAllDataCancelled:
                state.destination = nil
                return .none

            case .deleteAllDataCompleted:
                state.isDeletingAllData = false
                return .send(.delegate(.didDeleteAllData))

            case let .deleteAllDataFailed(errorMessage):
                state.isDeletingAllData = false
                state.error = errorMessage
                return .none
            }
        }
    }
}

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
