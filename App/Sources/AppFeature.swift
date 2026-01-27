import ComposableArchitecture
import Foundation
import TimelineFeature
import RecordingFeature
import SessionDetailFeature
import PeopleFeature
import ProfileFeature
import Persistence
import Processing
import Models

// MARK: - AppFeature

@Reducer
public struct AppFeature {
    public init() {}

    // MARK: - Path (Navigation Stack)

    @Reducer(state: .equatable, action: .equatable)
    public enum Path {
        case sessionDetail(SessionDetailFeature)
        case profile(ProfileFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var currentTab: Tab = .timeline
        public var path: StackState<Path.State> = StackState()
        public var timeline: TimelineFeature.State
        public var people: PeopleFeature.State
        @Presents public var recording: RecordingFeature.State?
        public var userProfile: UserProfile = .empty

        public init(
            currentTab: Tab = .timeline,
            path: StackState<Path.State> = StackState(),
            timeline: TimelineFeature.State = .init(),
            people: PeopleFeature.State = .init(),
            recording: RecordingFeature.State? = nil,
            userProfile: UserProfile = .empty
        ) {
            self.currentTab = currentTab
            self.path = path
            self.timeline = timeline
            self.people = people
            self.recording = recording
            self.userProfile = userProfile
        }
    }

    public enum Tab: Equatable, Sendable {
        case timeline
        case people
    }

    public enum Action: Equatable {
        case onAppear
        case tabSelected(Tab)
        case path(StackAction<Path.State, Path.Action>)
        case timeline(TimelineFeature.Action)
        case people(PeopleFeature.Action)
        case recording(PresentationAction<RecordingFeature.Action>)
        case dismissRecording
        case userProfileLoaded(UserProfile)
    }

    @Dependency(\.recoveryRoutineClient) var recoveryRoutineClient
    @Dependency(\.userProfileClient) var userProfileClient

    public var body: some ReducerOf<Self> {
        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }

        Scope(state: \.people, action: \.people) {
            PeopleFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                // Run recovery routine and load user profile on app start
                return .run { [userProfileClient] send in
                    _ = try? await recoveryRoutineClient.run()
                    let profile = try await userProfileClient.load()
                    await send(.userProfileLoaded(profile))
                }

            case let .userProfileLoaded(profile):
                state.userProfile = profile
                return .none

            case let .tabSelected(tab):
                state.currentTab = tab
                return .none

            // MARK: - Navigation Stack Actions

            case .path(.element(id: _, action: .sessionDetail(.backTapped))):
                // Pop the navigation stack when back is tapped
                _ = state.path.popLast()
                return .none

            case .path(.element(id: _, action: .profile(.backTapped))):
                // Pop the navigation stack when back is tapped in profile
                _ = state.path.popLast()
                return .none

            case let .path(.element(id: _, action: .profile(.delegate(.didSaveProfile(profile))))):
                // Update app-level profile state when profile is saved
                state.userProfile = profile
                return .none

            case .path(.element(id: _, action: .sessionDetail(.deleteCompleted))):
                // Pop the navigation stack and reload timeline when session is deleted
                _ = state.path.popLast()
                return .send(.timeline(.loadSessions))

            case .path:
                // Other path actions are handled by forEach below
                return .none

            // MARK: - Timeline Actions

            case let .timeline(.sessionTapped(sessionID)):
                // Push session detail onto navigation stack
                state.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
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

            case .timeline(.avatarTapped):
                // Push profile onto navigation stack with current user profile
                state.path.append(.profile(ProfileFeature.State(profile: state.userProfile)))
                return .none

            case .timeline:
                return .none

            // MARK: - People Actions

            case .people(.avatarTapped):
                // Push profile onto navigation stack with current user profile
                state.path.append(.profile(ProfileFeature.State(profile: state.userProfile)))
                return .none

            case .people:
                return .none

            // MARK: - Recording Actions

            case let .recording(.presented(.processorEvent(.didFinish(sessionID)))):
                // Recording finished - navigate to session detail view
                state.recording = nil
                // Push session detail onto navigation stack
                state.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
                // Also reload timeline in background so it's up to date when user goes back
                return .send(.timeline(.loadSessions))

            case .recording(.presented(.processorEvent(.didDiscard(_)))):
                // Recording discarded - dismiss and reload timeline
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
        .forEach(\.path, action: \.path)
        .ifLet(\.$recording, action: \.recording) {
            RecordingFeature()
        }
    }
}
