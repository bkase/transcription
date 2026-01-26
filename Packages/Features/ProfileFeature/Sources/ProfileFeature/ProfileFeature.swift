import CasePaths
import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence

@Reducer
public struct ProfileFeature {
    public init() {}

    @Dependency(\.userProfileClient) var userProfileClient
    @Dependency(\.profileImageClient) var profileImageClient

    @ObservableState
    public struct State: Equatable {
        public var profile: UserProfile
        public var isLoading: Bool
        public var isSaving: Bool
        public var error: String?

        // Edit mode states
        public var isEditingName: Bool
        public var editingNameText: String

        public init(
            profile: UserProfile = .empty,
            isLoading: Bool = false,
            isSaving: Bool = false,
            error: String? = nil,
            isEditingName: Bool = false,
            editingNameText: String = ""
        ) {
            self.profile = profile
            self.isLoading = isLoading
            self.isSaving = isSaving
            self.error = error
            self.isEditingName = isEditingName
            self.editingNameText = editingNameText
        }

        /// Compute initials from the profile name for avatar display
        public var initials: String {
            let components = profile.name.split(separator: " ")
            if components.count >= 2 {
                let first = components[0].prefix(1)
                let last = components[components.count - 1].prefix(1)
                return "\(first)\(last)".uppercased()
            } else if let first = components.first?.prefix(1) {
                return String(first).uppercased()
            }
            return ""
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case backTapped
        case profileLoaded(UserProfile)
        case profileLoadFailed(String)

        // Photo actions
        case changePhotoTapped
        case photoPicked(Data)
        case photoProcessed(Data?)

        // Name editing
        case editNameTapped
        case editingNameChanged(String)
        case saveNameTapped
        case cancelEditNameTapped

        // Save responses
        case profileSaved(UserProfile)
        case profileSaveFailed(String)

        // Delegate to parent
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case didSaveProfile(UserProfile)
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
                // View layer handles PhotosPicker presentation
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
            }
        }
    }
}
