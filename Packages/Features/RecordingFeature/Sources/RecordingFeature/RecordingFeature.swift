import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence
import Audio
import Processing
import DesignSystem

@Reducer
public struct RecordingFeature {
    public init() {}

    @Dependency(\.recordingProcessorClient) var recordingProcessorClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case timer
        case processorEvents
    }

    @ObservableState
    public struct State: Equatable {
        /// Whether recording is active
        public var isRecording: Bool = false
        /// Whether the microphone is listening (may be false during initialization)
        public var isListening: Bool = false
        /// Elapsed recording time in seconds
        public var elapsedSeconds: Int = 0
        /// The current session ID if recording
        public var sessionID: SessionID?
        /// Error message if something went wrong
        public var error: String?
        /// Directory where audio files are stored
        public var audioDirectory: URL?

        public init(
            isRecording: Bool = false,
            isListening: Bool = false,
            elapsedSeconds: Int = 0,
            sessionID: SessionID? = nil,
            error: String? = nil,
            audioDirectory: URL? = nil
        ) {
            self.isRecording = isRecording
            self.isListening = isListening
            self.elapsedSeconds = elapsedSeconds
            self.sessionID = sessionID
            self.error = error
            self.audioDirectory = audioDirectory
        }
    }

    public enum Action: Equatable, Sendable {
        /// Start recording with the given audio directory
        case startRecording(audioDirectory: URL)
        /// Stop the current recording
        case stopRecording
        /// Timer tick - increment elapsed time
        case timerTicked
        /// Received processor event
        case processorEvent(RecordingProcessorEvent)
        /// Recording started successfully with session ID
        case recordingStarted(SessionID)
        /// Recording failed to start
        case recordingFailed(String)
        /// View appeared
        case onAppear
        /// View disappeared
        case onDisappear
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startRecording(audioDirectory):
                guard !state.isRecording else { return .none }

                state.audioDirectory = audioDirectory
                state.isRecording = true
                state.elapsedSeconds = 0
                state.error = nil

                return .run { send in
                    do {
                        let eventStream = try await recordingProcessorClient.startRecording(audioDirectory)

                        // Listen for events
                        for await event in eventStream {
                            await send(.processorEvent(event))
                        }
                    } catch {
                        await send(.recordingFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.processorEvents, cancelInFlight: true)

            case .stopRecording:
                guard state.isRecording else { return .none }

                // Don't cancel processor events here - let the processor emit
                // .didFinish and finish the stream naturally
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in
                        await recordingProcessorClient.stopRecording()
                    }
                )

            case .timerTicked:
                guard state.isRecording else { return .none }
                state.elapsedSeconds += 1
                return .none

            case let .processorEvent(event):
                switch event {
                case let .didStart(sessionID):
                    state.sessionID = sessionID
                    // Start timer when recording starts
                    return .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.timerTicked)
                        }
                    }
                    .cancellable(id: CancelID.timer, cancelInFlight: true)

                case let .listeningChanged(isListening):
                    state.isListening = isListening
                    return .none

                case .didAppendSegment:
                    // Segments are read from DB by views, no state change needed
                    return .none

                case .didFinish:
                    state.isRecording = false
                    state.isListening = false
                    state.sessionID = nil
                    // Keep elapsedSeconds for display until view navigates away
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .cancel(id: CancelID.processorEvents)
                    )

                case let .didFail(errorMessage):
                    state.error = errorMessage
                    state.isRecording = false
                    state.isListening = false
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .cancel(id: CancelID.processorEvents)
                    )
                }

            case let .recordingStarted(sessionID):
                state.sessionID = sessionID
                return .none

            case let .recordingFailed(errorMessage):
                state.isRecording = false
                state.error = errorMessage
                return .none

            case .onAppear:
                return .none

            case .onDisappear:
                // Cancel ongoing effects when view disappears
                return .merge(
                    .cancel(id: CancelID.timer),
                    .cancel(id: CancelID.processorEvents)
                )
            }
        }
    }
}
