import ComposableArchitecture
import Models
import Persistence
import Audio
import Processing
import DesignSystem

@Reducer
public struct RecordingFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var isRecording: Bool = false
        public init() {}
    }

    public enum Action: Equatable {
        case startRecording
        case stopRecording
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startRecording:
                state.isRecording = true
                return .none
            case .stopRecording:
                state.isRecording = false
                return .none
            }
        }
    }
}
