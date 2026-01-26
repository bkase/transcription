import Testing
import Foundation
import Models
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
