import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Observability
import Persistence
import DesignSystem

@Reducer
public struct TimelineFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.date) var date
    @Dependency(\.uuid) var uuid

    @ObservableState
    public struct State: Equatable {
        public var searchQuery: String = ""
        public var sessionGroups: [SessionGroup] = []
        public var searchResults: [SessionRecord] = []
        public var isLoading: Bool = false
        public var error: String?
        /// Alert info for displaying errors with recovery options
        public var alertInfo: AlertInfo?

        /// Whether the user is actively searching (non-empty query)
        public var isSearching: Bool {
            !searchQuery.isEmpty
        }

        public init(
            searchQuery: String = "",
            sessionGroups: [SessionGroup] = [],
            searchResults: [SessionRecord] = [],
            isLoading: Bool = false,
            error: String? = nil,
            alertInfo: AlertInfo? = nil
        ) {
            self.searchQuery = searchQuery
            self.sessionGroups = sessionGroups
            self.searchResults = searchResults
            self.isLoading = isLoading
            self.error = error
            self.alertInfo = alertInfo
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case searchQueryChanged(String)
        case loadSessions
        case sessionsLoaded([SessionGroup])
        case sessionsFailed(String)
        case searchPerformed([SessionRecord])
        case sessionTapped(SessionID)
        case newRecordingTapped
        /// User tapped a recovery action in the alert
        case alertActionTapped(RecoveryAction)
        /// Alert was dismissed
        case alertDismissed
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.sessionGroups.isEmpty && !state.isLoading else {
                    return .none
                }
                return .send(.loadSessions)

            case let .searchQueryChanged(query):
                state.searchQuery = query

                if query.isEmpty {
                    state.searchResults = []
                    // Reload all sessions when clearing search
                    return .send(.loadSessions)
                }

                // Perform FTS search with full session details
                return .run { send in
                    let results = try await databaseClient.searchSessionsWithDetails(query)
                    await send(.searchPerformed(results))
                } catch: { error, send in
                    await send(.sessionsFailed(error.localizedDescription))
                }

            case .loadSessions:
                state.isLoading = true
                state.error = nil

                return .run { [date] send in
                    let groups = try await databaseClient.fetchSessionsGroupedByDate(date.now)
                    await send(.sessionsLoaded(groups))
                } catch: { error, send in
                    await send(.sessionsFailed(error.localizedDescription))
                }

            case let .sessionsLoaded(groups):
                state.isLoading = false
                state.sessionGroups = groups
                return .none

            case let .sessionsFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                // Create an error envelope and convert to alert with deterministic ID
                let envelope = ErrorEnvelope.databaseRead(message: errorMessage)
                let alertInfo = envelope.toAlertInfo()
                state.alertInfo = AlertInfo(
                    id: uuid().uuidString,
                    title: alertInfo.title,
                    message: alertInfo.message,
                    primaryButton: alertInfo.primaryButton,
                    secondaryButton: alertInfo.secondaryButton
                )
                return .none

            case let .searchPerformed(results):
                state.searchResults = results
                return .none

            case .sessionTapped:
                // Navigation intent - will be handled by parent
                return .none

            case .newRecordingTapped:
                // Navigation intent - will be handled by parent
                return .none

            case let .alertActionTapped(action):
                state.alertInfo = nil
                switch action {
                case .retry:
                    return .send(.loadSessions)
                case .dismiss:
                    return .none
                default:
                    return .none
                }

            case .alertDismissed:
                state.alertInfo = nil
                return .none
            }
        }
    }
}
