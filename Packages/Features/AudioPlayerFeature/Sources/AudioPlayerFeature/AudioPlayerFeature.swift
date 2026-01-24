import ComposableArchitecture
import Models
import Audio
import DesignSystem

@Reducer
public struct AudioPlayerFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var isPlaying: Bool = false
        public init() {}
    }

    public enum Action: Equatable {
        case play
        case pause
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .play:
                state.isPlaying = true
                return .none
            case .pause:
                state.isPlaying = false
                return .none
            }
        }
    }
}
