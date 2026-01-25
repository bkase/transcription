import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence
import DesignSystem

@Reducer
public struct PeopleFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    @ObservableState
    public struct State: Equatable {
        public var people: [PersonRecord] = []
        public var conversationCounts: [String: Int] = [:]
        public var searchQuery: String = ""
        public var isLoading: Bool = false
        public var error: String?

        // CRUD form state
        public var isShowingAddPersonSheet: Bool = false
        public var editingPerson: PersonRecord? = nil
        public var formName: String = ""
        public var formColorToken: String = SpeakerColor.sky.rawValue
        public var isSaving: Bool = false

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

        public init(
            people: [PersonRecord] = [],
            conversationCounts: [String: Int] = [:],
            searchQuery: String = "",
            isLoading: Bool = false,
            error: String? = nil,
            isShowingAddPersonSheet: Bool = false,
            editingPerson: PersonRecord? = nil,
            formName: String = "",
            formColorToken: String = SpeakerColor.sky.rawValue,
            isSaving: Bool = false
        ) {
            self.people = people
            self.conversationCounts = conversationCounts
            self.searchQuery = searchQuery
            self.isLoading = isLoading
            self.error = error
            self.isShowingAddPersonSheet = isShowingAddPersonSheet
            self.editingPerson = editingPerson
            self.formName = formName
            self.formColorToken = formColorToken
            self.isSaving = isSaving
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case loadPeople
        case peopleLoaded([PersonRecord], [String: Int])
        case peopleFailed(String)
        case searchQueryChanged(String)
        case personTapped(PersonID)

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
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.people.isEmpty && !state.isLoading else {
                    return .none
                }
                return .send(.loadPeople)

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

            // MARK: - CRUD Actions

            case .addPersonTapped:
                state.editingPerson = nil
                state.formName = ""
                state.formColorToken = SpeakerColor.sky.rawValue
                state.isShowingAddPersonSheet = true
                state.error = nil
                return .none

            case let .editPersonTapped(person):
                state.editingPerson = person
                state.formName = person.name
                state.formColorToken = person.colorToken
                state.isShowingAddPersonSheet = true
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
                state.isShowingAddPersonSheet = false
                state.editingPerson = nil
                state.formName = ""
                state.formColorToken = SpeakerColor.sky.rawValue
                state.isSaving = false
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
                state.isShowingAddPersonSheet = false

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
            }
        }
    }
}
