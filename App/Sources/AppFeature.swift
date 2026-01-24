import ComposableArchitecture
import TimelineFeature
import RecordingFeature
import SessionDetailFeature
import PeopleFeature

// MARK: - AppFeature

@Reducer
public struct AppFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var currentTab: Tab = .timeline
        public var timeline: TimelineFeature.State

        public init(
            currentTab: Tab = .timeline,
            timeline: TimelineFeature.State = .init()
        ) {
            self.currentTab = currentTab
            self.timeline = timeline
        }
    }

    public enum Tab: Equatable, Sendable {
        case timeline
        case people
    }

    public enum Action: Equatable {
        case onAppear
        case tabSelected(Tab)
        case timeline(TimelineFeature.Action)
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .tabSelected(tab):
                state.currentTab = tab
                return .none

            case .timeline:
                return .none
            }
        }
    }
}
