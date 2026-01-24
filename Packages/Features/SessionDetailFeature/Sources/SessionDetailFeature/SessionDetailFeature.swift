import ComposableArchitecture
import Models
import Persistence
import DesignSystem

@Reducer
public struct SessionDetailFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var sessionID: SessionID
        public init(sessionID: SessionID) {
            self.sessionID = sessionID
        }
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
