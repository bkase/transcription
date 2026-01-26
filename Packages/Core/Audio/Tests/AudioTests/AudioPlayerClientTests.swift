import AVFoundation
import Testing
@testable import Audio

// MARK: - MockAudioPlayer

/// Mock audio player for testing playback operations
final class MockAudioPlayer: AudioPlayerProtocol, @unchecked Sendable {
    private let lock = NSLock()

    private var _isPlaying = false
    private var _currentTime: TimeInterval = 0
    private var _duration: TimeInterval
    private var _prepareToPlayCalled = false
    private var _playCalled = false
    private var _pauseCalled = false
    private var _stopCalled = false

    init(duration: TimeInterval = 60.0) {
        self._duration = duration
    }

    var isPlaying: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isPlaying
    }

    var currentTime: TimeInterval {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentTime
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _currentTime = newValue
        }
    }

    var duration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return _duration
    }

    func play() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _playCalled = true
        _isPlaying = true
        return true
    }

    func pause() {
        lock.lock()
        defer { lock.unlock() }
        _pauseCalled = true
        _isPlaying = false
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        _stopCalled = true
        _isPlaying = false
        _currentTime = 0
    }

    func prepareToPlay() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _prepareToPlayCalled = true
        return true
    }

    // Test verification helpers
    var prepareToPlayCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _prepareToPlayCalled
    }

    var playCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _playCalled
    }

    var pauseCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _pauseCalled
    }

    var stopCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _stopCalled
    }
}

// MARK: - MockAudioPlayerFactory

/// Factory that returns mock audio players
final class MockAudioPlayerFactory: AudioPlayerFactoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _createdPlayers: [MockAudioPlayer] = []
    private let duration: TimeInterval

    init(duration: TimeInterval = 60.0) {
        self.duration = duration
    }

    func createPlayer(url: URL) throws -> AudioPlayerProtocol {
        lock.lock()
        defer { lock.unlock() }
        let player = MockAudioPlayer(duration: duration)
        _createdPlayers.append(player)
        return player
    }

    var createdPlayers: [MockAudioPlayer] {
        lock.lock()
        defer { lock.unlock() }
        return _createdPlayers
    }

    var lastCreatedPlayer: MockAudioPlayer? {
        lock.lock()
        defer { lock.unlock() }
        return _createdPlayers.last
    }
}

// MARK: - Tests

@Test func testPlayPauseAndSeek() async throws {
    // Setup mock factory
    let factory = MockAudioPlayerFactory(duration: 120.0)
    let player = LiveAudioPlayer(factory: factory)
    let testURL = URL(fileURLWithPath: "/test/audio.m4a")

    // Initial state
    #expect(!player.isPlaying)
    #expect(player.currentTime == 0)

    // Play
    try player.play(url: testURL)
    #expect(player.isPlaying)
    #expect(factory.lastCreatedPlayer?.prepareToPlayCalled == true)
    #expect(factory.lastCreatedPlayer?.playCalled == true)

    // Pause
    player.pause()
    #expect(!player.isPlaying)
    #expect(factory.lastCreatedPlayer?.pauseCalled == true)

    // Resume (play same URL)
    try player.play(url: testURL)
    #expect(player.isPlaying)

    // Seek
    player.seek(to: 30.0)
    #expect(player.currentTime == 30.0)

    // Stop
    player.stop()
    #expect(!player.isPlaying)
    #expect(factory.lastCreatedPlayer?.stopCalled == true)
}

@Test func testPlayNewURLStopsPrevious() async throws {
    let factory = MockAudioPlayerFactory()
    let player = LiveAudioPlayer(factory: factory)
    let url1 = URL(fileURLWithPath: "/test/audio1.m4a")
    let url2 = URL(fileURLWithPath: "/test/audio2.m4a")

    // Play first URL
    try player.play(url: url1)
    let firstPlayer = factory.lastCreatedPlayer
    #expect(factory.createdPlayers.count == 1)
    #expect(player.isPlaying)

    // Play second URL - should stop first and create new player
    try player.play(url: url2)
    #expect(firstPlayer?.stopCalled == true)
    #expect(factory.createdPlayers.count == 2)
    #expect(player.isPlaying)
}

@Test func testResumePlaySameURL() async throws {
    let factory = MockAudioPlayerFactory()
    let player = LiveAudioPlayer(factory: factory)
    let url = URL(fileURLWithPath: "/test/audio.m4a")

    // Play
    try player.play(url: url)
    #expect(factory.createdPlayers.count == 1)

    // Pause
    player.pause()

    // Resume with same URL - should not create new player
    try player.play(url: url)
    #expect(factory.createdPlayers.count == 1)
    #expect(player.isPlaying)
}

@Test func testAudioPlayerClientLiveFactory() async throws {
    let factory = MockAudioPlayerFactory(duration: 90.0)
    let client = AudioPlayerClient.live(factory: factory)
    let testURL = URL(fileURLWithPath: "/test/audio.m4a")

    // Test the client interface
    let isPlayingBefore = await client.isPlaying()
    #expect(!isPlayingBefore)

    let currentTimeBefore = await client.currentTime()
    #expect(currentTimeBefore == 0)

    // Play through the client
    try await client.play(testURL)
    let isPlayingAfter = await client.isPlaying()
    #expect(isPlayingAfter)

    // Seek through the client
    await client.seek(45.0)
    let currentTimeAfterSeek = await client.currentTime()
    #expect(currentTimeAfterSeek == 45.0)

    // Pause through the client
    await client.pause()
    let isPlayingAfterPause = await client.isPlaying()
    #expect(!isPlayingAfterPause)

    // Stop through the client
    await client.stop()
    let isPlayingAfterStop = await client.isPlaying()
    #expect(!isPlayingAfterStop)
}

@Test func testStopResetsState() async throws {
    let factory = MockAudioPlayerFactory()
    let player = LiveAudioPlayer(factory: factory)
    let url = URL(fileURLWithPath: "/test/audio.m4a")

    // Play and seek
    try player.play(url: url)
    player.seek(to: 30.0)
    #expect(player.currentTime == 30.0)
    #expect(player.isPlaying)

    // Stop should reset
    player.stop()
    #expect(!player.isPlaying)
    // Note: Mock player resets currentTime to 0 on stop
    #expect(factory.lastCreatedPlayer?.currentTime == 0)
}
