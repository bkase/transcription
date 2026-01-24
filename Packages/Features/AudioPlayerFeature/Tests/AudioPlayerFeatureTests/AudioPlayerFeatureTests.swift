import Testing
import Foundation
import ComposableArchitecture
import Audio
@testable import AudioPlayerFeature

@MainActor
struct AudioPlayerReducerTests {

    // MARK: - testPlayPause

    @Test
    func testPlayPause() async {
        let testURL = URL(fileURLWithPath: "/test/audio.caf")
        var playCallCount = 0
        var stopCallCount = 0
        var currentTimeValue: TimeInterval = 10

        let store = TestStore(
            initialState: AudioPlayerFeature.State(
                audioURL: testURL,
                duration: 120
            )
        ) {
            AudioPlayerFeature()
        } withDependencies: {
            $0.audioPlayerClient.play = { url in
                playCallCount += 1
                #expect(url == testURL)
            }
            $0.audioPlayerClient.stop = {
                stopCallCount += 1
            }
            $0.audioPlayerClient.currentTime = { currentTimeValue }
            $0.audioPlayerClient.isPlaying = { false }
            $0.continuousClock = ImmediateClock()
        }

        // Initial state should be paused
        #expect(store.state.isPlaying == false)

        // Tap play/pause should start playing
        await store.send(.playPauseTapped)
        await store.receive(\.play) {
            $0.isPlaying = true
        }

        // Timer fires, gets current time (10), sees not playing, stops
        await store.receive(\.updateCurrentTime) {
            $0.currentTime = 10
        }
        await store.receive(\.stop) {
            $0.isPlaying = false
            $0.currentTime = 0
        }

        #expect(playCallCount == 1)
        #expect(stopCallCount == 1)
    }

    @Test
    func testPlayThenPause() async {
        let testURL = URL(fileURLWithPath: "/test/audio.caf")
        var pauseCalled = false

        let store = TestStore(
            initialState: AudioPlayerFeature.State(
                audioURL: testURL,
                isPlaying: true,
                currentTime: 30,
                duration: 120
            )
        ) {
            AudioPlayerFeature()
        } withDependencies: {
            $0.audioPlayerClient.pause = {
                pauseCalled = true
            }
        }

        // Tap play/pause while playing should pause
        await store.send(.playPauseTapped)
        await store.receive(\.pause) {
            $0.isPlaying = false
        }

        #expect(pauseCalled)
    }

    @Test
    func testProgressCalculation() async {
        let state = AudioPlayerFeature.State(
            audioURL: URL(fileURLWithPath: "/test.caf"),
            currentTime: 30,
            duration: 120
        )

        #expect(state.progress == 0.25)
    }

    @Test
    func testProgressWithZeroDuration() async {
        let state = AudioPlayerFeature.State(
            audioURL: URL(fileURLWithPath: "/test.caf"),
            currentTime: 30,
            duration: 0
        )

        #expect(state.progress == 0)
    }

    @Test
    func testSeek() async {
        let testURL = URL(fileURLWithPath: "/test/audio.caf")
        var seekedToTime: TimeInterval?

        let store = TestStore(
            initialState: AudioPlayerFeature.State(
                audioURL: testURL,
                currentTime: 30,
                duration: 120
            )
        ) {
            AudioPlayerFeature()
        } withDependencies: {
            $0.audioPlayerClient.seek = { time in
                seekedToTime = time
            }
        }

        await store.send(.seek(60)) {
            $0.currentTime = 60
        }

        #expect(seekedToTime == 60)
    }

    @Test
    func testSetDuration() async {
        let store = TestStore(
            initialState: AudioPlayerFeature.State()
        ) {
            AudioPlayerFeature()
        }

        await store.send(.setDuration(180)) {
            $0.duration = 180
        }
    }

    @Test
    func testFormatTime() {
        // Test seconds only
        #expect(AudioPlayerFeature.formatTime(45) == "0:45")

        // Test minutes and seconds
        #expect(AudioPlayerFeature.formatTime(125) == "2:05")

        // Test hours
        #expect(AudioPlayerFeature.formatTime(3665) == "1:01:05")

        // Test zero
        #expect(AudioPlayerFeature.formatTime(0) == "0:00")
    }

    @Test
    func testStop() async {
        let testURL = URL(fileURLWithPath: "/test/audio.caf")
        var stopCalled = false

        let store = TestStore(
            initialState: AudioPlayerFeature.State(
                audioURL: testURL,
                isPlaying: true,
                currentTime: 60,
                duration: 120
            )
        ) {
            AudioPlayerFeature()
        } withDependencies: {
            $0.audioPlayerClient.stop = {
                stopCalled = true
            }
        }

        await store.send(.stop) {
            $0.isPlaying = false
            $0.currentTime = 0
        }

        #expect(stopCalled)
    }

    @Test
    func testPlayWithNoURL() async {
        let store = TestStore(
            initialState: AudioPlayerFeature.State(audioURL: nil)
        ) {
            AudioPlayerFeature()
        }

        // Play with no URL should be a no-op
        await store.send(.play)
    }
}
