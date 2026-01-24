import AVFoundation
import Testing
@testable import Audio

// MARK: - Mock Audio Engine

final class MockAudioInputNode: AudioInputNodeProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var tapBlock: AVAudioNodeTapBlock?
    private var _tapInstalled = false
    private let _format: AVAudioFormat

    init(format: AVAudioFormat? = nil) {
        // Create a default mono 44.1kHz format
        self._format = format ?? AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 1
        )!
    }

    var tapInstalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _tapInstalled
    }

    func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping AVAudioNodeTapBlock
    ) {
        lock.lock()
        defer { lock.unlock() }
        tapBlock = block
        _tapInstalled = true
    }

    func removeTap(onBus bus: AVAudioNodeBus) {
        lock.lock()
        defer { lock.unlock() }
        tapBlock = nil
        _tapInstalled = false
    }

    var outputFormat: @Sendable (AVAudioNodeBus) -> AVAudioFormat {
        { [_format] _ in _format }
    }

    /// Simulate receiving audio data
    func simulateAudioBuffer(frameCount: AVAudioFrameCount, timestamp: UInt64) {
        lock.lock()
        let block = tapBlock
        let format = _format
        lock.unlock()

        guard let block = block else { return }

        // Create a buffer with the mock format
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        buffer.frameLength = frameCount

        // Fill with simple test data
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCount) {
                channelData[0][i] = Float(i) / Float(frameCount)
            }
        }

        let time = AVAudioTime(hostTime: timestamp)
        block(buffer, time)
    }
}

final class MockAudioEngine: AudioEngineProtocol, @unchecked Sendable {
    private let lock = NSLock()
    let mockInputNode: MockAudioInputNode
    private var _isRunning = false
    private var _isPrepared = false

    init(inputNode: MockAudioInputNode = MockAudioInputNode()) {
        self.mockInputNode = inputNode
    }

    var audioInputNode: AudioInputNodeProtocol {
        mockInputNode
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    var isPrepared: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isPrepared
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        _isRunning = true
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        _isRunning = false
    }

    func prepare() {
        lock.lock()
        defer { lock.unlock() }
        _isPrepared = true
    }
}

// MARK: - Tests

@Test func testLiveCaptureProducesFramesWithMockEngine() async throws {
    // Setup mock engine
    let mockInputNode = MockAudioInputNode()
    let mockEngine = MockAudioEngine(inputNode: mockInputNode)

    // Create capture
    let capture = LiveMicrophoneCapture(engine: mockEngine)

    // Start capture
    let stream = try capture.startCapture()

    // Verify engine is prepared and started
    #expect(mockEngine.isPrepared)
    #expect(mockEngine.isRunning)
    #expect(mockInputNode.tapInstalled)
    #expect(capture.isCapturing)

    // Simulate audio arriving
    let testTimestamp: UInt64 = 12345
    let testFrameCount: AVAudioFrameCount = 1024
    mockInputNode.simulateAudioBuffer(frameCount: testFrameCount, timestamp: testTimestamp)

    // Get first frame from stream
    var iterator = stream.makeAsyncIterator()
    let frame = await iterator.next()

    // Verify we received a frame
    #expect(frame != nil)
    if let frame = frame {
        #expect(frame.timestamp == testTimestamp)
        #expect(frame.data.count == Int(testFrameCount) * MemoryLayout<Float>.size)
    }

    // Stop capture
    capture.stopCapture()

    // Verify cleanup
    #expect(!capture.isCapturing)
    #expect(!mockEngine.isRunning)
    #expect(!mockInputNode.tapInstalled)
}

@Test func testLiveCaptureStopsCleanly() throws {
    let mockEngine = MockAudioEngine()
    let capture = LiveMicrophoneCapture(engine: mockEngine)

    // Start capture
    let _ = try capture.startCapture()
    #expect(capture.isCapturing)
    #expect(mockEngine.isRunning)

    // Stop capture
    capture.stopCapture()
    #expect(!capture.isCapturing)
    #expect(!mockEngine.isRunning)
}

@Test func testLiveCaptureIgnoresDuplicateStart() throws {
    let mockEngine = MockAudioEngine()
    let capture = LiveMicrophoneCapture(engine: mockEngine)

    // First start
    let _ = try capture.startCapture()
    #expect(capture.isCapturing)

    // Second start should be a noop but not crash
    let _ = try capture.startCapture()
    #expect(capture.isCapturing)  // Still capturing from first

    capture.stopCapture()
    #expect(!capture.isCapturing)
}

@Test func testAudioCaptureClientLiveFactory() async throws {
    let mockEngine = MockAudioEngine()
    let client = AudioCaptureClient.live(engine: mockEngine)

    // Test the client interface
    let isCaptBefore = await client.isCapturing()
    #expect(isCaptBefore == false)

    // Start capture through the client
    let _ = try await client.startCapture()
    let isCaptAfter = await client.isCapturing()
    #expect(isCaptAfter == true)

    // Stop
    await client.stopCapture()
    let isCaptFinal = await client.isCapturing()
    #expect(isCaptFinal == false)
}
