import Testing
import Foundation
import ComposableArchitecture
import Audio
import Clocks
@testable import AudioPlayerFeature

/// Actor for thread-safe test state management
private actor TimeCounter {
    private var tickCount = 0
    private let baseTime: TimeInterval
    private let increment: TimeInterval

    init(baseTime: TimeInterval = 0, increment: TimeInterval = 0.25) {
        self.baseTime = baseTime
        self.increment = increment
    }

    /// Get current time and advance for next call
    func getCurrentTimeAndAdvance() -> TimeInterval {
        let current = baseTime + (Double(tickCount) * increment)
        tickCount += 1
        return current
    }
}

/// Actor for thread-safe playback state
private actor PlaybackState {
    private var _isPlaying: Bool
    private var _currentTime: TimeInterval

    init(isPlaying: Bool = true, currentTime: TimeInterval = 0) {
        _isPlaying = isPlaying
        _currentTime = currentTime
    }

    var isPlaying: Bool { _isPlaying }
    var currentTime: TimeInterval { _currentTime }

    func setPlaying(_ value: Bool) {
        _isPlaying = value
    }

    func setCurrentTime(_ value: TimeInterval) {
        _currentTime = value
    }
}

@MainActor
struct AudioPlayerProgressTests {

    // MARK: - testProgressTicks

    @Test
    func testProgressTicks() async {
        let testURL = URL(fileURLWithPath: "/test/audio.m4a")
        let testClock = TestClock()
        let duration: TimeInterval = 120

        // Use actor for thread-safe time tracking
        // Time progresses: 0.25 -> 0.5 -> 0.75 (so each tick shows a change)
        let timeCounter = TimeCounter(baseTime: 0.25, increment: 0.25)

        let store = TestStore(
            initialState: AudioPlayerFeature.State(
                audioURL: testURL,
                duration: duration
            )
        ) {
            AudioPlayerFeature()
        } withDependencies: {
            $0.audioPlayerClient.play = { _ in }
            $0.audioPlayerClient.currentTime = { await timeCounter.getCurrentTimeAndAdvance() }
            $0.audioPlayerClient.isPlaying = { true }
            $0.audioPlayerClient.pause = { }
            $0.audioPlayerClient.stop = { }
            $0.continuousClock = testClock
        }

        // Start playback
        await store.send(.play) {
            $0.isPlaying = true
        }

        // Advance clock by 250ms - first tick (currentTime = 0.25)
        await testClock.advance(by: .milliseconds(250))
        await store.receive(\.updateCurrentTime) {
            $0.currentTime = 0.25
        }

        // Advance clock by another 250ms - second tick (currentTime = 0.5)
        await testClock.advance(by: .milliseconds(250))
        await store.receive(\.updateCurrentTime) {
            $0.currentTime = 0.5
        }

        // Advance clock by another 250ms - third tick (currentTime = 0.75)
        await testClock.advance(by: .milliseconds(250))
        await store.receive(\.updateCurrentTime) {
            $0.currentTime = 0.75
        }

        // Verify progress calculation is working correctly
        // After 3 ticks, currentTime = 0.75, duration = 120
        // Progress should be 0.75 / 120 = 0.00625
        #expect(store.state.progress > 0)
        #expect(store.state.progress < 0.01)

        // Pause to stop the timer
        await store.send(.pause) {
            $0.isPlaying = false
        }
    }

    @Test
    func testProgressTicksStopWhenNotPlaying() async {
        let testURL = URL(fileURLWithPath: "/test/audio.m4a")
        let testClock = TestClock()

        let playbackState = PlaybackState(isPlaying: true, currentTime: 55)

        let store = TestStore(
            initialState: AudioPlayerFeature.State(
                audioURL: testURL,
                duration: 60
            )
        ) {
            AudioPlayerFeature()
        } withDependencies: {
            $0.audioPlayerClient.play = { _ in }
            $0.audioPlayerClient.currentTime = { await playbackState.currentTime }
            $0.audioPlayerClient.isPlaying = { await playbackState.isPlaying }
            $0.audioPlayerClient.stop = { }
            $0.continuousClock = testClock
        }

        // Start playback
        await store.send(.play) {
            $0.isPlaying = true
        }

        // First tick - still playing
        await testClock.advance(by: .milliseconds(250))
        await store.receive(\.updateCurrentTime) {
            $0.currentTime = 55
        }

        // Simulate playback ending (e.g., reached end of file)
        await playbackState.setPlaying(false)
        await playbackState.setCurrentTime(60)

        // Second tick - not playing anymore, should stop
        await testClock.advance(by: .milliseconds(250))
        await store.receive(\.updateCurrentTime) {
            $0.currentTime = 60
        }
        await store.receive(\.stop) {
            $0.isPlaying = false
            $0.currentTime = 0
        }
    }

    @Test
    func testFormatTimeMinutesSeconds() {
        // Test various time formatting scenarios
        #expect(AudioPlayerFeature.formatTime(0) == "0:00")
        #expect(AudioPlayerFeature.formatTime(5) == "0:05")
        #expect(AudioPlayerFeature.formatTime(59) == "0:59")
        #expect(AudioPlayerFeature.formatTime(60) == "1:00")
        #expect(AudioPlayerFeature.formatTime(65) == "1:05")
        #expect(AudioPlayerFeature.formatTime(125) == "2:05")
        #expect(AudioPlayerFeature.formatTime(599) == "9:59")
        #expect(AudioPlayerFeature.formatTime(600) == "10:00")
    }

    @Test
    func testFormatTimeHoursMinutesSeconds() {
        // Test hours formatting
        #expect(AudioPlayerFeature.formatTime(3600) == "1:00:00")
        #expect(AudioPlayerFeature.formatTime(3665) == "1:01:05")
        #expect(AudioPlayerFeature.formatTime(7200) == "2:00:00")
        #expect(AudioPlayerFeature.formatTime(7325) == "2:02:05")
        #expect(AudioPlayerFeature.formatTime(36000) == "10:00:00")
    }

    @Test
    func testProgressAtVariousPositions() {
        // Test progress calculation at different points
        let state0 = AudioPlayerFeature.State(
            audioURL: URL(fileURLWithPath: "/test.m4a"),
            currentTime: 0,
            duration: 100
        )
        #expect(state0.progress == 0.0)

        let state25 = AudioPlayerFeature.State(
            audioURL: URL(fileURLWithPath: "/test.m4a"),
            currentTime: 25,
            duration: 100
        )
        #expect(state25.progress == 0.25)

        let state50 = AudioPlayerFeature.State(
            audioURL: URL(fileURLWithPath: "/test.m4a"),
            currentTime: 50,
            duration: 100
        )
        #expect(state50.progress == 0.5)

        let state100 = AudioPlayerFeature.State(
            audioURL: URL(fileURLWithPath: "/test.m4a"),
            currentTime: 100,
            duration: 100
        )
        #expect(state100.progress == 1.0)
    }

    @Test
    func testProgressClampedToOne() {
        // If currentTime somehow exceeds duration, progress should be clamped to 1.0
        let state = AudioPlayerFeature.State(
            audioURL: URL(fileURLWithPath: "/test.m4a"),
            currentTime: 150,
            duration: 100
        )
        #expect(state.progress == 1.0)
    }
}
