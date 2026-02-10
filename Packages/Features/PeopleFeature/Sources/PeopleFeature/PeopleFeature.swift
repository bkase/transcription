import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence
import DesignSystem

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

@Reducer
public struct PeopleFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileImageClient) var profileImageClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    /// Presentation destination for PeopleFeature's primary presentation.
    /// Replaces the isShowingAddPersonSheet boolean. The mock photo picker is a nested
    /// presentation within the add person sheet, so it stays as a separate boolean.
    public enum Destination: Equatable, Sendable {
        case addPersonSheet
    }

    @ObservableState
    public struct State: Equatable {
        public var people: [PersonRecord] = []
        public var conversationCounts: [String: Int] = [:]
        public var searchQuery: String = ""
        public var isLoading: Bool = false
        public var error: String?

        // CRUD form state
        public var destination: Destination?
        public var editingPerson: PersonRecord? = nil
        public var formName: String = ""
        public var formColorToken: String = SpeakerColor.sky.rawValue
        public var formImageData: Data? = nil
        public var isSaving: Bool = false

        // Mock photo picker state (nested presentation within add person sheet, for UI testing)
        public var isShowingMockPhotoPicker: Bool = false

        /// Current user profile (to detect when tapped person is self)
        public var userProfile: UserProfile = .empty

        /// Whether the add person sheet is showing (derived from destination)
        public var isShowingAddPersonSheet: Bool {
            destination == .addPersonSheet
        }

        /// Whether we're editing an existing person (vs creating new)
        public var isEditing: Bool {
            editingPerson != nil
        }

        /// Filtered people based on search query
        public var filteredPeople: [PersonRecord] {
            if searchQuery.isEmpty {
                return people
            }
            return people.filter { person in
                person.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        /// Get conversation count for a person
        public func conversationCount(for personId: String) -> Int {
            conversationCounts[personId] ?? 0
        }

        /// Check if a person record represents the current user.
        /// Matches by case-insensitive name comparison (same logic as SpeakerPickerFeature).
        public func isCurrentUser(_ person: PersonRecord) -> Bool {
            let userName = userProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !userName.isEmpty else { return false }
            return person.name.lowercased() == userName.lowercased()
        }

        public init(
            people: [PersonRecord] = [],
            conversationCounts: [String: Int] = [:],
            searchQuery: String = "",
            isLoading: Bool = false,
            error: String? = nil,
            destination: Destination? = nil,
            editingPerson: PersonRecord? = nil,
            formName: String = "",
            formColorToken: String = SpeakerColor.sky.rawValue,
            formImageData: Data? = nil,
            isSaving: Bool = false,
            isShowingMockPhotoPicker: Bool = false,
            userProfile: UserProfile = .empty
        ) {
            self.people = people
            self.conversationCounts = conversationCounts
            self.searchQuery = searchQuery
            self.isLoading = isLoading
            self.error = error
            self.destination = destination
            self.editingPerson = editingPerson
            self.formName = formName
            self.formColorToken = formColorToken
            self.formImageData = formImageData
            self.isSaving = isSaving
            self.isShowingMockPhotoPicker = isShowingMockPhotoPicker
            self.userProfile = userProfile
        }
    }

    public enum Action: Sendable {
        case onAppear
        case backTapped
        case loadPeople
        case peopleLoaded([PersonRecord], [String: Int])
        case peopleFailed(String)
        case searchQueryChanged(String)
        case personTapped(PersonID)
        case selfTapped  // Emitted when tapping on a person that represents the current user

        // CRUD actions
        case addPersonTapped
        case editPersonTapped(PersonRecord)
        case deletePersonTapped(PersonID)
        case dismissSheet
        case formNameChanged(String)
        case formColorChanged(String)
        case savePerson
        case personSaved(PersonRecord)
        case personDeleted(PersonID)
        case saveFailed(String)
        case deleteFailed(String)

        // Photo actions
        case changePhotoTapped
        case photoPicked(Data)
        case photoProcessed(Data?)
        case removePhotoTapped

        // Mock photo picker actions (for UI testing)
        case showMockPhotoPicker
        case mockPhotoSelected(Int)
        case dismissMockPhotoPicker
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.people.isEmpty && !state.isLoading else {
                    return .none
                }
                return .send(.loadPeople)

            case .backTapped:
                // Navigation intent - will be handled by parent
                return .none

            case .loadPeople:
                state.isLoading = true
                state.error = nil

                return .run { send in
                    async let peopleTask = databaseClient.fetchPeople()
                    async let countsTask = databaseClient.fetchPersonConversationCounts()
                    let (people, counts) = try await (peopleTask, countsTask)
                    await send(.peopleLoaded(people, counts))
                } catch: { error, send in
                    await send(.peopleFailed(error.localizedDescription))
                }

            case let .peopleLoaded(people, counts):
                state.isLoading = false
                state.people = people
                state.conversationCounts = counts
                return .none

            case let .peopleFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                return .none

            case let .searchQueryChanged(query):
                state.searchQuery = query
                return .none

            case .personTapped:
                // Navigation intent - will be handled by parent
                return .none

            case .selfTapped:
                // Navigation intent to open profile - will be handled by parent
                return .none

            // MARK: - CRUD Actions

            case .addPersonTapped:
                state.editingPerson = nil
                state.formName = ""
                state.formColorToken = SpeakerColor.forIndex(state.people.count).rawValue
                state.formImageData = nil
                state.destination = .addPersonSheet
                state.error = nil
                return .none

            case let .editPersonTapped(person):
                state.editingPerson = person
                state.formName = person.name
                state.formColorToken = person.colorToken
                state.formImageData = person.imageData
                state.destination = .addPersonSheet
                state.error = nil
                return .none

            case let .deletePersonTapped(personId):
                return .run { send in
                    try await databaseClient.deletePerson(personId)
                    await send(.personDeleted(personId))
                } catch: { error, send in
                    await send(.deleteFailed(error.localizedDescription))
                }

            case .dismissSheet:
                state.destination = nil
                state.editingPerson = nil
                state.formName = ""
                state.formColorToken = SpeakerColor.sky.rawValue
                state.formImageData = nil
                state.isSaving = false
                state.error = nil
                return .none

            case let .formNameChanged(name):
                state.formName = name
                return .none

            case let .formColorChanged(colorToken):
                state.formColorToken = colorToken
                return .none

            case .savePerson:
                let trimmedName = state.formName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    state.error = "Name cannot be empty"
                    return .none
                }

                state.isSaving = true
                state.error = nil

                if let existingPerson = state.editingPerson {
                    // Update existing person
                    let updatedPerson = PersonRecord(
                        id: existingPerson.id,
                        name: trimmedName,
                        colorToken: state.formColorToken,
                        imageData: state.formImageData,
                        createdAt: existingPerson.createdAt,
                        updatedAt: date.now
                    )
                    return .run { [updatedPerson] send in
                        try await databaseClient.updatePerson(updatedPerson)
                        await send(.personSaved(updatedPerson))
                    } catch: { error, send in
                        await send(.saveFailed(error.localizedDescription))
                    }
                } else {
                    // Create new person
                    let newPerson = PersonRecord(
                        id: uuid().uuidString,
                        name: trimmedName,
                        colorToken: state.formColorToken,
                        imageData: state.formImageData,
                        createdAt: date.now,
                        updatedAt: date.now
                    )
                    return .run { [newPerson] send in
                        try await databaseClient.createPerson(newPerson)
                        await send(.personSaved(newPerson))
                    } catch: { error, send in
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case let .personSaved(person):
                state.isSaving = false
                state.destination = nil

                // Update local list
                if let index = state.people.firstIndex(where: { $0.id == person.id }) {
                    state.people[index] = person
                } else {
                    state.people.append(person)
                }
                // Re-sort by name
                state.people.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                state.editingPerson = nil
                state.formName = ""
                state.formColorToken = SpeakerColor.sky.rawValue
                state.formImageData = nil
                return .none

            case let .personDeleted(personId):
                state.people.removeAll { $0.id == personId.rawValue }
                return .none

            case let .saveFailed(errorMessage):
                state.isSaving = false
                state.error = errorMessage
                return .none

            case let .deleteFailed(errorMessage):
                state.error = errorMessage
                return .none

            // MARK: - Photo Actions

            case .changePhotoTapped:
                // View layer handles PhotosPicker presentation (live mode)
                // or triggers showMockPhotoPicker (UI testing mode)
                return .none

            case let .photoPicked(data):
                return .run { send in
                    let normalizedData = await profileImageClient.normalize(data, 256, 0.8)
                    await send(.photoProcessed(normalizedData))
                }

            case let .photoProcessed(data):
                guard let imageData = data else {
                    state.error = "Failed to process image"
                    return .none
                }
                state.formImageData = imageData
                return .none

            case .removePhotoTapped:
                state.formImageData = nil
                return .none

            case .showMockPhotoPicker:
                state.isShowingMockPhotoPicker = true
                return .none

            case let .mockPhotoSelected(index):
                state.isShowingMockPhotoPicker = false
                // Generate deterministic test image data based on index
                let testImageData = MockPhotoData.imageData(forIndex: index)
                return .send(.photoPicked(testImageData))

            case .dismissMockPhotoPicker:
                state.isShowingMockPhotoPicker = false
                return .none
            }
        }
    }
}
