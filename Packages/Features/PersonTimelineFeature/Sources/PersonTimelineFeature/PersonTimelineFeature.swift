import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence

@Reducer
public struct PersonTimelineFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient

    @ObservableState
    public struct State: Equatable {
        public var personId: PersonID
        public var personName: String
        public var sessions: [SessionRecord] = []
        public var isLoading: Bool = false
        public var error: String?

        public init(
            personId: PersonID,
            personName: String,
            sessions: [SessionRecord] = [],
            isLoading: Bool = false,
            error: String? = nil
        ) {
            self.personId = personId
            self.personName = personName
            self.sessions = sessions
            self.isLoading = isLoading
            self.error = error
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case loadSessions
        case sessionsLoaded([SessionRecord])
        case loadFailed(String)
        case sessionTapped(SessionID)
        case backTapped
        /// User tapped the settings icon to navigate to profile
        case avatarTapped
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.sessions.isEmpty && !state.isLoading else {
                    return .none
                }
                return .send(.loadSessions)

            case .loadSessions:
                state.isLoading = true
                state.error = nil

                return .run { [personId = state.personId, databaseClient] send in
                    let sessions = try await databaseClient.fetchSessionsForPerson(personId)
                    await send(.sessionsLoaded(sessions))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }

            case let .sessionsLoaded(sessions):
                state.isLoading = false
                state.sessions = sessions
                return .none

            case let .loadFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                return .none

            case .sessionTapped:
                // Navigation intent - will be handled by parent
                return .none

            case .backTapped:
                // Navigation intent - will be handled by parent
                return .none

            case .avatarTapped:
                // Navigation intent - will be handled by parent
                return .none
            }
        }
    }
}
