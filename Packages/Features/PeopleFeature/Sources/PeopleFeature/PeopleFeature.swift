import ComposableArchitecture
import Models
import Persistence
import DesignSystem

@Reducer
public struct PeopleFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}
