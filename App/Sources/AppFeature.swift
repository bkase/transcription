import ComposableArchitecture
import Foundation
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
        @Presents public var recording: RecordingFeature.State?

        public init(
            currentTab: Tab = .timeline,
            timeline: TimelineFeature.State = .init(),
            recording: RecordingFeature.State? = nil
        ) {
            self.currentTab = currentTab
            self.timeline = timeline
            self.recording = recording
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
        case recording(PresentationAction<RecordingFeature.Action>)
        case dismissRecording
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

            case .timeline(.newRecordingTapped):
                // Present recording screen and start recording
                state.recording = RecordingFeature.State()
                // Get audio directory from caches
                let audioDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("recordings", isDirectory: true)
                // Create directory if needed
                try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
                return .send(.recording(.presented(.startRecording(audioDirectory: audioDir))))

            case .timeline:
                return .none

            case .recording(.presented(.processorEvent(.didFinish))):
                // Recording finished - dismiss and reload timeline
                state.recording = nil
                return .send(.timeline(.loadSessions))

            case .recording(.dismiss):
                // Stop recording if still in progress when dismissed
                if let recording = state.recording, recording.isRecording {
                    return .send(.recording(.presented(.stopRecording)))
                }
                return .none

            case .recording:
                return .none

            case .dismissRecording:
                // Stop recording if still in progress
                if let recording = state.recording, recording.isRecording {
                    return .merge(
                        .send(.recording(.presented(.stopRecording))),
                        .run { send in
                            // Wait a moment for recording to stop, then dismiss
                            try? await Task.sleep(for: .milliseconds(100))
                            await send(.recording(.dismiss))
                        }
                    )
                }
                state.recording = nil
                return .send(.timeline(.loadSessions))
            }
        }
        .ifLet(\.$recording, action: \.recording) {
            RecordingFeature()
        }
    }
}
