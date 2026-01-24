import Testing
import Foundation
@testable import Processing

// MARK: - VAD Chunk Boundary Tests

@Test func testChunkBoundariesFromVAD() {
    // Test that VAD events produce correct chunk boundaries
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    // Speech starts at 1000ms
    let startResult = VadChunkingPolicy.processEvent(
        .speechStart(timeMs: 1000),
        state: &state,
        config: config
    )
    #expect(startResult == nil) // No boundary on speech start
    #expect(state.isSpeaking == true)
    #expect(state.currentSpeechStartMs != nil)

    // Speech ends at 3000ms (2 seconds of speech)
    let endResult = VadChunkingPolicy.processEvent(
        .speechEnd(timeMs: 3000),
        state: &state,
        config: config
    )

    #expect(endResult != nil) // Boundary emitted on speech end
    #expect(state.isSpeaking == false)
    #expect(state.chunkCount == 1)

    // Verify boundary timing (includes padding)
    if let boundary = endResult {
        // Start should be padded back by speechPaddingMs (120ms)
        #expect(boundary.startMs == 880) // 1000 - 120
        // End should be padded forward by speechPaddingMs (120ms)
        #expect(boundary.endMs == 3120) // 3000 + 120
        #expect(boundary.wasForced == false)
        #expect(boundary.durationMs == 2240) // 3120 - 880
    }
}

@Test func testMinSpeechDurationFilter() {
    // Test that very short speech is filtered out
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default // minSpeechDurationMs = 250

    // Speech starts at 0ms
    _ = VadChunkingPolicy.processEvent(
        .speechStart(timeMs: 0),
        state: &state,
        config: config
    )

    // Speech ends after only 100ms (too short even with padding)
    // With 120ms padding on each end = 100 + 240 = 340ms total
    // But the raw duration is only 100ms which is < 250ms
    let result = VadChunkingPolicy.processEvent(
        .speechEnd(timeMs: 100),
        state: &state,
        config: config
    )

    #expect(result == nil) // Too short, no boundary emitted
    #expect(state.chunkCount == 0)
}

@Test func testMinSpeechDurationPass() {
    // Test that speech meeting minimum duration passes
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default // minSpeechDurationMs = 250

    // Speech from 0ms to 300ms = 300ms raw duration
    // With padding: (0-120=0) to (300+120=420) = 420ms total
    _ = VadChunkingPolicy.processEvent(
        .speechStart(timeMs: 0),
        state: &state,
        config: config
    )

    let result = VadChunkingPolicy.processEvent(
        .speechEnd(timeMs: 300),
        state: &state,
        config: config
    )

    #expect(result != nil) // Meets minimum duration
    #expect(state.chunkCount == 1)
}

@Test func testMaxDurationForcedBoundary() {
    // Test that long speech is force-chunked at max duration
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config(
        minSpeechDurationMs: 200,
        maxSpeechDurationMs: 5000, // 5 seconds max for easier testing
        minSilenceDurationMs: 400,
        speechPaddingMs: 100
    )

    // Speech starts
    _ = VadChunkingPolicy.processEvent(
        .speechStart(timeMs: 0),
        state: &state,
        config: config
    )

    // Check at 3 seconds - no boundary yet
    let check1 = VadChunkingPolicy.checkMaxDuration(
        currentTimeMs: 3000,
        state: &state,
        config: config
    )
    #expect(check1 == nil)
    #expect(state.isSpeaking == true)

    // Check at 5 seconds - should force boundary
    let check2 = VadChunkingPolicy.checkMaxDuration(
        currentTimeMs: 5000,
        state: &state,
        config: config
    )
    #expect(check2 != nil)
    #expect(check2?.wasForced == true)
    #expect(check2?.startMs == 0)
    #expect(check2?.endMs == 5000)
    #expect(state.chunkCount == 1)

    // State should still be speaking but with new start
    #expect(state.isSpeaking == true)
    #expect(state.currentSpeechStartMs == 5000)
}

@Test func testMultipleUtterances() {
    // Test multiple sequential utterances
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    // First utterance: 0-500ms
    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 0), state: &state, config: config)
    let result1 = VadChunkingPolicy.processEvent(.speechEnd(timeMs: 500), state: &state, config: config)

    #expect(result1 != nil)
    #expect(state.chunkCount == 1)

    // Gap (silence from 500-1500ms)

    // Second utterance: 1500-2500ms
    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 1500), state: &state, config: config)
    let result2 = VadChunkingPolicy.processEvent(.speechEnd(timeMs: 2500), state: &state, config: config)

    #expect(result2 != nil)
    #expect(state.chunkCount == 2)

    // Verify second chunk starts after first chunk ended
    if let chunk1 = result1, let chunk2 = result2 {
        #expect(chunk2.startMs >= chunk1.endMs || chunk2.startMs == state.lastChunkEndMs - config.speechPaddingMs * 2 - 1000)
    }
}

@Test func testFlushRemainingAudio() {
    // Test flushing when recording stops mid-speech
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    // Speech starts at 1000ms
    _ = VadChunkingPolicy.processEvent(
        .speechStart(timeMs: 1000),
        state: &state,
        config: config
    )

    // Recording stops at 3000ms (never received speechEnd)
    let result = VadChunkingPolicy.flush(
        endTimeMs: 3000,
        state: &state,
        config: config
    )

    #expect(result != nil)
    #expect(state.isSpeaking == false)
    #expect(state.currentSpeechStartMs == nil)
    #expect(state.chunkCount == 1)

    if let boundary = result {
        #expect(boundary.startMs == 880) // 1000 - 120 padding
        #expect(boundary.endMs == 3000)
        #expect(boundary.wasForced == false)
    }
}

@Test func testFlushTooShort() {
    // Test that flush filters short speech
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    // Speech starts at 0ms
    _ = VadChunkingPolicy.processEvent(
        .speechStart(timeMs: 0),
        state: &state,
        config: config
    )

    // Recording stops very quickly (100ms)
    let result = VadChunkingPolicy.flush(
        endTimeMs: 100,
        state: &state,
        config: config
    )

    #expect(result == nil) // Too short
    #expect(state.isSpeaking == false)
    #expect(state.chunkCount == 0)
}

@Test func testNoSpeechFlush() {
    // Test flush when no speech was detected
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    let result = VadChunkingPolicy.flush(
        endTimeMs: 10000,
        state: &state,
        config: config
    )

    #expect(result == nil)
    #expect(state.chunkCount == 0)
}

@Test func testDuplicateSpeechStart() {
    // Test that duplicate speechStart events are ignored
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 0), state: &state, config: config)
    #expect(state.isSpeaking == true)

    // Duplicate speechStart should be ignored
    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 500), state: &state, config: config)
    #expect(state.isSpeaking == true)
    // Original start time should be preserved
    #expect(state.currentSpeechStartMs == 0) // No padding since start is 0
}

@Test func testSpuriousSpeechEnd() {
    // Test that speechEnd without prior speechStart is ignored
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    let result = VadChunkingPolicy.processEvent(.speechEnd(timeMs: 1000), state: &state, config: config)

    #expect(result == nil)
    #expect(state.isSpeaking == false)
    #expect(state.chunkCount == 0)
}

@Test func testSampleRangeConversion() {
    // Test conversion of time boundaries to sample indices
    let boundary = VadChunkingPolicy.ChunkBoundary(
        startMs: 1000,
        endMs: 2000,
        wasForced: false
    )

    // At 16kHz sample rate
    let range16k = boundary.sampleRange(atSampleRate: 16000)
    #expect(range16k.start == 16000) // 1 second * 16000 samples/sec
    #expect(range16k.end == 32000)   // 2 seconds * 16000 samples/sec

    // At 44.1kHz sample rate
    let range44k = boundary.sampleRange(atSampleRate: 44100)
    #expect(range44k.start == 44100)
    #expect(range44k.end == 88200)
}

@Test func testConfigPresets() {
    // Test different config presets have sensible values
    let defaultConfig = VadChunkingPolicy.Config.default
    let meetingConfig = VadChunkingPolicy.Config.meeting
    let quickConfig = VadChunkingPolicy.Config.quick

    // Meeting mode should have longer silence tolerance than default
    #expect(meetingConfig.minSilenceDurationMs > defaultConfig.minSilenceDurationMs)

    // Quick mode should have shorter max duration than meeting
    #expect(quickConfig.maxSpeechDurationMs < meetingConfig.maxSpeechDurationMs)

    // All should have positive durations
    #expect(defaultConfig.minSpeechDurationMs > 0)
    #expect(defaultConfig.maxSpeechDurationMs > defaultConfig.minSpeechDurationMs)
}

@Test func testPaddingClampedToLastChunkEnd() {
    // Test that padding doesn't cause overlap with previous chunk
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    // First chunk: 0-1000ms
    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 0), state: &state, config: config)
    let _ = VadChunkingPolicy.processEvent(.speechEnd(timeMs: 1000), state: &state, config: config)
    let lastEnd = state.lastChunkEndMs

    // Second chunk starts at 1050ms (very close to first chunk end)
    // With 120ms padding, raw start would be 930ms which is before lastEnd
    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 1050), state: &state, config: config)
    let result = VadChunkingPolicy.processEvent(.speechEnd(timeMs: 2000), state: &state, config: config)

    // Start should be clamped to lastEnd, not overlap
    if let boundary = result {
        #expect(boundary.startMs >= lastEnd)
    }
}

@Test func testChunkBoundaryDuration() {
    // Test duration calculation
    let boundary1 = VadChunkingPolicy.ChunkBoundary(startMs: 100, endMs: 500, wasForced: false)
    #expect(boundary1.durationMs == 400)

    // Zero duration
    let boundary2 = VadChunkingPolicy.ChunkBoundary(startMs: 100, endMs: 100, wasForced: false)
    #expect(boundary2.durationMs == 0)

    // Invalid (end < start) - should handle gracefully
    let boundary3 = VadChunkingPolicy.ChunkBoundary(startMs: 500, endMs: 100, wasForced: false)
    #expect(boundary3.durationMs == 0)
}

@Test func testStateReset() {
    // Test that state properly resets between utterances
    var state = VadChunkingPolicy.State()
    let config = VadChunkingPolicy.Config.default

    // Complete one utterance
    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 0), state: &state, config: config)
    _ = VadChunkingPolicy.processEvent(.speechEnd(timeMs: 500), state: &state, config: config)

    #expect(state.isSpeaking == false)
    #expect(state.currentSpeechStartMs == nil)
    #expect(state.chunkCount == 1)
    #expect(state.lastChunkEndMs > 0)

    // Fresh state for new utterance
    _ = VadChunkingPolicy.processEvent(.speechStart(timeMs: 1000), state: &state, config: config)
    #expect(state.isSpeaking == true)
    #expect(state.currentSpeechStartMs != nil)
}
