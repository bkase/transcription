import ComposableArchitecture
import Models
import Persistence
import DesignSystem

@Reducer
public struct TimelineFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var searchQuery: String = ""
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case searchQueryChanged(String)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            case let .searchQueryChanged(query):
                state.searchQuery = query
                return .none
            }
        }
    }
}
