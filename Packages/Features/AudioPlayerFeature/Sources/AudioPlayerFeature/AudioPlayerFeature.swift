import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Audio
import DesignSystem

@Reducer
public struct AudioPlayerFeature {
    public init() {}

    @Dependency(\.audioPlayerClient) var audioPlayerClient
    @Dependency(\.continuousClock) var clock

    @ObservableState
    public struct State: Equatable, Sendable {
        /// URL of the audio file to play
        public var audioURL: URL?
        /// Whether currently playing
        public var isPlaying: Bool = false
        /// Current playback position in seconds
        public var currentTime: TimeInterval = 0
        /// Total duration in seconds
        public var duration: TimeInterval = 0
        /// Progress from 0.0 to 1.0
        public var progress: Double {
            guard duration > 0 else { return 0 }
            return min(1.0, currentTime / duration)
        }

        public init(
            audioURL: URL? = nil,
            isPlaying: Bool = false,
            currentTime: TimeInterval = 0,
            duration: TimeInterval = 0
        ) {
            self.audioURL = audioURL
            self.isPlaying = isPlaying
            self.currentTime = currentTime
            self.duration = duration
        }
    }

    public enum Action: Equatable, Sendable {
        case playPauseTapped
        case play
        case pause
        case stop
        case seek(TimeInterval)
        case updateCurrentTime(TimeInterval)
        case setDuration(TimeInterval)
        case timerTick
    }

    private enum CancelID {
        case playbackTimer
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .playPauseTapped:
                if state.isPlaying {
                    return .send(.pause)
                } else {
                    return .send(.play)
                }

            case .play:
                guard let url = state.audioURL else { return .none }
                state.isPlaying = true
                return .run { [audioPlayerClient, clock] send in
                    try await audioPlayerClient.play(url)
                    // Start timer to poll current time
                    for await _ in clock.timer(interval: .milliseconds(250)) {
                        let time = await audioPlayerClient.currentTime()
                        await send(.updateCurrentTime(time))
                        // Check if still playing
                        let playing = await audioPlayerClient.isPlaying()
                        if !playing {
                            await send(.stop)
                            break
                        }
                    }
                }
                .cancellable(id: CancelID.playbackTimer, cancelInFlight: true)

            case .pause:
                state.isPlaying = false
                return .merge(
                    .cancel(id: CancelID.playbackTimer),
                    .run { [audioPlayerClient] _ in
                        await audioPlayerClient.pause()
                    }
                )

            case .stop:
                state.isPlaying = false
                state.currentTime = 0
                return .merge(
                    .cancel(id: CancelID.playbackTimer),
                    .run { [audioPlayerClient] _ in
                        await audioPlayerClient.stop()
                    }
                )

            case let .seek(time):
                state.currentTime = time
                return .run { [audioPlayerClient] _ in
                    await audioPlayerClient.seek(time)
                }

            case let .updateCurrentTime(time):
                state.currentTime = time
                return .none

            case let .setDuration(duration):
                state.duration = duration
                return .none

            case .timerTick:
                // Handled internally via timer in play effect
                return .none
            }
        }
    }
}

// MARK: - Formatters

extension AudioPlayerFeature {
    /// Formats seconds into MM:SS or H:MM:SS string
    public static func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
