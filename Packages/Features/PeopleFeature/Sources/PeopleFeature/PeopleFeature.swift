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

    @ObservableState
    public struct State: Equatable {
        public var people: [PersonRecord] = []
        public var searchQuery: String = ""
        public var isLoading: Bool = false
        public var error: String?

        /// Filtered people based on search query
        public var filteredPeople: [PersonRecord] {
            if searchQuery.isEmpty {
                return people
            }
            return people.filter { person in
                person.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        public init(
            people: [PersonRecord] = [],
            searchQuery: String = "",
            isLoading: Bool = false,
            error: String? = nil
        ) {
            self.people = people
            self.searchQuery = searchQuery
            self.isLoading = isLoading
            self.error = error
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case loadPeople
        case peopleLoaded([PersonRecord])
        case peopleFailed(String)
        case searchQueryChanged(String)
        case personTapped(PersonID)
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
                    let people = try await databaseClient.fetchPeople()
                    await send(.peopleLoaded(people))
                } catch: { error, send in
                    await send(.peopleFailed(error.localizedDescription))
                }

            case let .peopleLoaded(people):
                state.isLoading = false
                state.people = people
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
            }
        }
    }
}
