import Testing
import Foundation
import Models
import Audio
@testable import Processing

// MARK: - Model Preparation Tests

@Test func testMockClientDefaultsToReady() async {
    // Default mock client should have models ready
    let client = MockFluidAudioClient.twoSpeakerConversation

    let status = await client.modelStatus()
    #expect(status == .ready, "Default mock client should be ready")
}

@Test func testMockClientConfigurableIdleState() async {
    // Create mock client with idle state
    let client = MockFluidAudioClient.idle

    let status = await client.modelStatus()
    #expect(status == .idle, "Idle mock client should report idle status")
}

@Test func testMockClientConfigurableFailedState() async {
    // Create mock client with failed state
    let errorMessage = "Test download error"
    let client = MockFluidAudioClient.failed(message: errorMessage)

    let status = await client.modelStatus()
    #expect(status == .failed(errorMessage), "Failed mock client should report failed status with message")
}

@Test func testMockClientPrepareModelsFromIdle() async {
    // Create mock client with idle state
    let client = MockFluidAudioClient.client(modelState: .idle)

    // Verify starts as idle
    var status = await client.modelStatus()
    #expect(status == .idle, "Should start as idle")

    // Prepare models
    await client.prepareModels()

    // Should now be ready
    status = await client.modelStatus()
    #expect(status == .ready, "Should be ready after prepareModels()")
}

@Test func testMockClientPrepareModelsIdempotentWhenReady() async {
    // Create mock client with ready state
    let client = MockFluidAudioClient.client(modelState: .ready)

    // Verify starts as ready
    var status = await client.modelStatus()
    #expect(status == .ready, "Should start as ready")

    // Call prepareModels multiple times - should be idempotent
    await client.prepareModels()
    await client.prepareModels()
    await client.prepareModels()

    // Should still be ready
    status = await client.modelStatus()
    #expect(status == .ready, "Should still be ready after multiple prepareModels() calls")
}

@Test func testMockClientPrepareModelsNoOpWhenFailed() async {
    // Create mock client with failed state
    let errorMessage = "Model download failed"
    let client = MockFluidAudioClient.failed(message: errorMessage)

    // Verify starts as failed
    var status = await client.modelStatus()
    #expect(status == .failed(errorMessage), "Should start as failed")

    // Call prepareModels - should be no-op when already failed
    await client.prepareModels()

    // Should still be failed (requires explicit reset, not retry through prepareModels)
    status = await client.modelStatus()
    #expect(status == .failed(errorMessage), "Should still be failed after prepareModels() when in failed state")
}

@Test func testLiveClientActorInitialState() async {
    // Create the live actor directly
    let actor = LiveFluidAudioClientActor()

    // Initial state should be idle
    let status = await actor.getModelStatus()
    #expect(status == .idle, "Live actor should start in idle state")

    let isTranscribing = await actor.getIsTranscribing()
    #expect(!isTranscribing, "Live actor should not be transcribing initially")
}

@Test func testLiveClientInitialState() async {
    // Create live client via factory
    let client = LiveFluidAudioClient.client()

    // Initial state should be idle
    let status = await client.modelStatus()
    #expect(status == .idle, "Live client should start in idle state")

    let isTranscribing = await client.isTranscribing()
    #expect(!isTranscribing, "Live client should not be transcribing initially")
}

@Test func testModelPreparationStateEquality() {
    // Test enum equality
    #expect(ModelPreparationState.idle == .idle)
    #expect(ModelPreparationState.downloading == .downloading)
    #expect(ModelPreparationState.ready == .ready)
    #expect(ModelPreparationState.failed("error1") == .failed("error1"))
    #expect(ModelPreparationState.failed("error1") != .failed("error2"))

    // Test different cases are not equal
    #expect(ModelPreparationState.idle != .ready)
    #expect(ModelPreparationState.downloading != .ready)
    #expect(ModelPreparationState.failed("error") != .ready)
}

// MARK: - ASR/Diarizer Lifecycle Split Tests

@Test func testASRReadyDiarizerMissing_liveTranscriptionStarts() async throws {
    // When ASR is ready but diarizer is unavailable, live transcription should start.
    // This is the core invariant: live start depends only on ASR readiness.
    let client = MockFluidAudioClient.asrReadyDiarizerUnavailable()

    let status = await client.modelStatus()
    #expect(status == .ready, "Model status should be ready (ASR is ready)")

    // Create a minimal audio stream that finishes immediately
    let audioStream = AsyncStream<AudioFrame> { $0.finish() }

    // startTranscription should succeed because ASR is ready
    let segmentStream = try await client.startTranscription(audioStream)

    // Consume stream to completion - it should not throw
    var segments: [TranscriptSegment] = []
    for await segment in segmentStream {
        segments.append(segment)
    }

    // Live segments should have nil speakerId (diarization deferred)
    for segment in segments {
        #expect(segment.speakerId == nil, "Live segments should have nil speakerId")
    }
}

@Test func testASRMissing_liveTranscriptionFails() async {
    // When ASR is not initialized, startTranscription should throw notInitialized
    let client = MockFluidAudioClient.asrNotInitialized

    let status = await client.modelStatus()
    #expect(status == .idle, "Model status should be idle (ASR not initialized)")

    let audioStream = AsyncStream<AudioFrame> { $0.finish() }

    // startTranscription should throw notInitialized
    do {
        _ = try await client.startTranscription(audioStream)
        Issue.record("Expected startTranscription to throw when ASR is not initialized")
    } catch let error as LiveFluidAudioClientError {
        #expect(error == .notInitialized, "Error should be notInitialized, not \(error)")
    } catch {
        Issue.record("Expected LiveFluidAudioClientError.notInitialized, got \(error)")
    }
}

@Test func testASRReadyDiarizerMissing_offlineTranscriptionFailsWithDiarizationError() async {
    // When ASR is ready but diarizer is unavailable, offline transcription should fail
    // with diarizationUnavailable (not notInitialized).
    let client = MockFluidAudioClient.asrReadyDiarizerUnavailable()

    let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.caf")

    do {
        _ = try await client.transcribeFile(dummyURL)
        Issue.record("Expected transcribeFile to throw when diarizer is unavailable")
    } catch let error as LiveFluidAudioClientError {
        #expect(error == .diarizationUnavailable, "Error should be diarizationUnavailable, not \(error)")
    } catch {
        Issue.record("Expected LiveFluidAudioClientError.diarizationUnavailable, got \(error)")
    }
}

@Test func testLiveActorASRNotInitialized_startTranscriptionThrows() async {
    // Direct actor test: without ASR initialization, startTranscription should throw
    let actor = LiveFluidAudioClientActor()

    // Verify ASR is not initialized
    let isASRReady = await actor.isASRInitialized()
    #expect(!isASRReady, "ASR should not be initialized on fresh actor")

    let audioStream = AsyncStream<AudioFrame> { $0.finish() }

    do {
        _ = try await actor.startTranscription(audioStream: audioStream)
        Issue.record("Expected startTranscription to throw when ASR is not initialized")
    } catch let error as LiveFluidAudioClientError {
        #expect(error == .notInitialized, "Error should be notInitialized")
    } catch {
        Issue.record("Expected LiveFluidAudioClientError.notInitialized, got \(error)")
    }
}

@Test func testModelReadyMeansASRReady() async {
    // Verify that .ready model state means ASR is ready for live transcription,
    // independent of diarizer state. This tests the contract that UI depends on.
    let client = MockFluidAudioClient.asrReadyDiarizerUnavailable()

    let status = await client.modelStatus()
    #expect(status == .ready, "Ready status should indicate ASR readiness for live transcription")

    // Verify live transcription works
    let audioStream = AsyncStream<AudioFrame> { $0.finish() }
    let segmentStream = try? await client.startTranscription(audioStream)
    #expect(segmentStream != nil, "Live transcription should start when model status is ready")
}
