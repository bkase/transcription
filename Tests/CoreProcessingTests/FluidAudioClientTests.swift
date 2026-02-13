import Testing
import Foundation
import Dependencies
import Models
@testable import Processing
@testable import Audio

/// Tests for FluidAudioClient live integration
/// Note: These tests verify the live client can be created and initialized,
/// but actual transcription requires the ML models which are tested in `make test`
/// (via the dedicated FluidAudioIntegration lane in run-tests.py).

@Test func testLiveClientInitializes() async throws {
    // Create the live client using the factory method
    let client = LiveFluidAudioClient.client()

    // Verify the client was created (non-nil closures)
    // The live client lazily initializes, so we just verify it can be created
    // without throwing. Actual model initialization happens on first use.

    // Check isTranscribing returns false initially
    let isTranscribing = await client.isTranscribing()
    #expect(!isTranscribing, "Client should not be transcribing initially")
}

@Test func testLiveClientActorCreation() async throws {
    // Create the actor directly to verify it can be constructed
    let actor = LiveFluidAudioClientActor()

    // Verify initial state
    let isTranscribing = await actor.getIsTranscribing()
    #expect(!isTranscribing, "Actor should not be transcribing initially")

    let isASRInitialized = await actor.isASRInitialized()
    #expect(!isASRInitialized, "Actor should not have ASR initialized before calling initializeASR()")
}

@Test func testLiveClientStopTranscription() async throws {
    // Create the live client
    let client = LiveFluidAudioClient.client()

    // Calling stop on a non-transcribing client should be a no-op
    await client.stopTranscription()

    // Verify still not transcribing
    let isTranscribing = await client.isTranscribing()
    #expect(!isTranscribing, "Client should still not be transcribing after stop")
}

@Test func testLiveFluidAudioClientErrorCases() {
    // Verify error cases are properly defined
    let notInitialized = LiveFluidAudioClientError.notInitialized
    let downloadFailed = LiveFluidAudioClientError.modelDownloadFailed
    let transcriptionFailed = LiveFluidAudioClientError.transcriptionFailed("test error")

    // Errors should be distinct
    #expect(String(describing: notInitialized) != String(describing: downloadFailed))
    #expect(String(describing: transcriptionFailed).contains("test error"))
}

@Test func testFluidAudioClientLiveValueUsesLiveImplementation() async throws {
    // The FluidAudioClient.liveValue should return the live implementation
    // We can't easily verify it's the *exact* live implementation, but we can
    // verify it behaves like a proper client (not throwing unimplemented)

    let client = FluidAudioClient.liveValue

    // Should not be transcribing initially
    let isTranscribing = await client.isTranscribing()
    #expect(!isTranscribing, "liveValue should not be transcribing initially")
}
