import AVFoundation
import Foundation
import Testing
@testable import Audio

// MARK: - AudioFileWriter Tests

@Test func testWritesAudioFileCAF() async throws {
    let writer = LiveAudioFileWriter()

    // Create temp file URL
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).caf")

    // Cleanup on exit
    defer {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // Start writing
    let format = AudioFormatConfig(sampleRate: 44100, channels: 1, isFloat: true)
    try await writer.startWriting(url: fileURL, format: format)

    #expect(await writer.isWriting)

    // Create test audio frame with a simple sine wave
    let sampleCount = 1024
    var samples = [Float](repeating: 0, count: sampleCount)
    for i in 0..<sampleCount {
        samples[i] = sin(2.0 * .pi * 440.0 * Float(i) / 44100.0)
    }
    let frameData = samples.withUnsafeBytes { Data($0) }
    let frame = AudioFrame(data: frameData, timestamp: 0)

    // Write frame
    try await writer.appendFrame(frame)

    // Finish writing
    let bytesWritten = try await writer.finishWriting()

    #expect(bytesWritten == frameData.count)
    #expect(await writer.isWriting == false)

    // Verify file exists and has content
    #expect(FileManager.default.fileExists(atPath: fileURL.path))

    let fileAttrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = fileAttrs[.size] as? Int ?? 0
    #expect(fileSize > 0)
}

@Test func testWritesAudioFileWAV() async throws {
    let writer = LiveAudioFileWriter()

    // Create temp file URL with .wav extension
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).wav")

    defer {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // Start writing
    let format = AudioFormatConfig(sampleRate: 16000, channels: 1, isFloat: true)
    try await writer.startWriting(url: fileURL, format: format)

    // Create and write multiple frames
    let sampleCount = 512
    let samples = [Float](repeating: 0.5, count: sampleCount)
    let frameData = samples.withUnsafeBytes { Data($0) }

    // Write 3 frames
    for i in 0..<3 {
        let frame = AudioFrame(data: frameData, timestamp: UInt64(i))
        try await writer.appendFrame(frame)
    }

    // Finish writing
    let bytesWritten = try await writer.finishWriting()

    #expect(bytesWritten == frameData.count * 3)

    // Verify file exists
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
}

@Test func testAudioFileWriterErrorWhenNotWriting() async {
    let writer = LiveAudioFileWriter()

    // Try to append without starting
    let frame = AudioFrame(data: Data([0, 0, 0, 0]), timestamp: 0)

    do {
        try await writer.appendFrame(frame)
        Issue.record("Expected error when appending without starting")
    } catch let error as AudioFileWriterError {
        #expect(error == .notWriting)
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}

@Test func testAudioFileWriterErrorWhenDoubleStart() async throws {
    let writer = LiveAudioFileWriter()

    let tempDir = FileManager.default.temporaryDirectory
    let fileURL1 = tempDir.appendingPathComponent("test1_\(UUID().uuidString).caf")
    let fileURL2 = tempDir.appendingPathComponent("test2_\(UUID().uuidString).caf")

    defer {
        try? FileManager.default.removeItem(at: fileURL1)
        try? FileManager.default.removeItem(at: fileURL2)
    }

    let format = AudioFormatConfig.recording

    // Start first write
    try await writer.startWriting(url: fileURL1, format: format)

    // Try to start another write
    do {
        try await writer.startWriting(url: fileURL2, format: format)
        Issue.record("Expected error when starting write while already writing")
    } catch let error as AudioFileWriterError {
        #expect(error == .alreadyWriting)
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }

    // Cleanup
    _ = try? await writer.finishWriting()
}

@Test func testAudioFileWriterFinishWithoutStartingThrows() async {
    let writer = LiveAudioFileWriter()

    do {
        _ = try await writer.finishWriting()
        Issue.record("Expected error when finishing without starting")
    } catch let error as AudioFileWriterError {
        #expect(error == .notWriting)
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}

@Test func testAudioFileWriterClientInterface() async throws {
    // Test using the client interface with mock-style test
    // Use actor for thread-safe state management
    actor MockState {
        var startedURL: URL?
        var appendedFrames: [AudioFrame] = []
        var finishedCalled = false
        var isWriting = false

        func setStarted(url: URL) {
            startedURL = url
            isWriting = true
        }

        func appendFrame(_ frame: AudioFrame) {
            appendedFrames.append(frame)
        }

        func finish() -> Int {
            finishedCalled = true
            isWriting = false
            return appendedFrames.reduce(0) { $0 + $1.data.count }
        }
    }

    let state = MockState()

    let client = AudioFileWriterClient(
        startWriting: { url, format in
            await state.setStarted(url: url)
        },
        appendFrame: { frame in
            await state.appendFrame(frame)
        },
        finishWriting: {
            await state.finish()
        },
        cancelWriting: { },
        isWriting: {
            await state.isWriting
        }
    )

    let testURL = URL(fileURLWithPath: "/tmp/test.caf")
    let format = AudioFormatConfig.recording

    // Test start
    try await client.startWriting(testURL, format)
    #expect(await state.startedURL == testURL)
    #expect(await client.isWriting() == true)

    // Test append
    let frame1 = AudioFrame(data: Data(repeating: 0, count: 100), timestamp: 0)
    let frame2 = AudioFrame(data: Data(repeating: 1, count: 200), timestamp: 1000)
    try await client.appendFrame(frame1)
    try await client.appendFrame(frame2)
    #expect(await state.appendedFrames.count == 2)

    // Test finish
    let bytesWritten = try await client.finishWriting()
    #expect(await state.finishedCalled)
    #expect(bytesWritten == 300)
    #expect(await client.isWriting() == false)
}

@Test func testWritesStereoAudioFile() async throws {
    let writer = LiveAudioFileWriter()

    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("test_stereo_\(UUID().uuidString).caf")

    defer {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // Start writing with stereo format
    let format = AudioFormatConfig(sampleRate: 44100, channels: 2, isFloat: true)
    try await writer.startWriting(url: fileURL, format: format)

    // Create stereo frame data
    let frameCount = 512
    var samples = [Float](repeating: 0, count: frameCount * 2)
    for i in 0..<frameCount {
        samples[i * 2] = Float(i) / Float(frameCount)       // Left channel
        samples[i * 2 + 1] = Float(frameCount - i) / Float(frameCount)  // Right channel
    }
    let frameData = samples.withUnsafeBytes { Data($0) }
    let frame = AudioFrame(data: frameData, timestamp: 0)

    // Write frame
    try await writer.appendFrame(frame)

    // Finish
    let bytesWritten = try await writer.finishWriting()
    #expect(bytesWritten == frameData.count)

    // Verify file exists
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
}
