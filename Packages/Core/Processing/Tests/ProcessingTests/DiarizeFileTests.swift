import Testing
import Foundation
import Dependencies
import Models
@testable import Processing

// MARK: - DiarizeFile API Tests

@Suite(.serialized)
struct DiarizeFileTests {

    // MARK: - Success Cases

    @Test func testDiarizeFileReturnsSegmentsOnSuccess() async throws {
        let expectedSegments: [DiarizationMapping.SpeakerSegment] = [
            .init(speakerId: "spk_0", startTimeSeconds: 0.0, endTimeSeconds: 2.5),
            .init(speakerId: "spk_1", startTimeSeconds: 2.5, endTimeSeconds: 5.5),
            .init(speakerId: "spk_0", startTimeSeconds: 5.5, endTimeSeconds: 7.0),
        ]
        let client = MockFluidAudioClient.client(
            diarizationBehavior: .success(expectedSegments)
        )

        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")
        let result = try await client.diarizeFile(dummyURL)

        #expect(result.count == 3)
        #expect(result[0].speakerId == "spk_0")
        #expect(result[0].startTimeSeconds == 0.0)
        #expect(result[0].endTimeSeconds == 2.5)
        #expect(result[1].speakerId == "spk_1")
        #expect(result[2].speakerId == "spk_0")
    }

    @Test func testDiarizeFileDefaultMockReturnsTwoSpeakers() async throws {
        // Default mock client uses twoSpeakerDefault diarization behavior
        let client = MockFluidAudioClient.twoSpeakerConversation

        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")
        let result = try await client.diarizeFile(dummyURL)

        #expect(result.count == 3)
        let speakerIds = Set(result.map(\.speakerId))
        #expect(speakerIds.count == 2, "Should have exactly 2 distinct speakers")
        #expect(speakerIds.contains("spk_0"))
        #expect(speakerIds.contains("spk_1"))
    }

    // MARK: - Empty Result

    @Test func testDiarizeFileReturnsEmptyWhenNoSpeakers() async throws {
        let client = MockFluidAudioClient.diarizationEmpty()

        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")
        let result = try await client.diarizeFile(dummyURL)

        #expect(result.isEmpty, "Should return empty array when no speakers detected")
    }

    // MARK: - Error Cases

    @Test func testDiarizeFileThrowsOnFailure() async throws {
        let errorMessage = "Diarizer model crashed"
        let client = MockFluidAudioClient.diarizationFailure(errorMessage: errorMessage)

        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

        do {
            _ = try await client.diarizeFile(dummyURL)
            Issue.record("Expected diarizeFile to throw on failure")
        } catch let error as MockOfflineTranscriptionError {
            #expect(error.message == errorMessage)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func testDiarizeFileThrowsWhenDiarizerUnavailable() async throws {
        let client = MockFluidAudioClient.asrReadyDiarizerUnavailable()

        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

        do {
            _ = try await client.diarizeFile(dummyURL)
            Issue.record("Expected diarizeFile to throw when diarizer is unavailable")
        } catch let error as LiveFluidAudioClientError {
            #expect(error == .diarizationUnavailable)
        } catch {
            Issue.record("Expected LiveFluidAudioClientError.diarizationUnavailable, got \(error)")
        }
    }

    @Test func testDiarizeFileThrowsWhenNotInitialized() async throws {
        let client = MockFluidAudioClient.asrNotInitialized

        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

        do {
            _ = try await client.diarizeFile(dummyURL)
            Issue.record("Expected diarizeFile to throw when not initialized")
        } catch let error as LiveFluidAudioClientError {
            #expect(error == .notInitialized)
        } catch {
            Issue.record("Expected LiveFluidAudioClientError.notInitialized, got \(error)")
        }
    }

    // MARK: - Cancellation / Timeout

    @Test func testDiarizeFileCancellationStopsHangingWork() async throws {
        let client = MockFluidAudioClient.diarizationHang()
        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

        // Run diarization with a short timeout to test cancellation
        let diarizeTask = Task {
            try await client.diarizeFile(dummyURL)
        }

        // Wait briefly then cancel
        try await Task.sleep(for: .milliseconds(50))
        diarizeTask.cancel()

        // The task should complete (either with cancellation error or empty result)
        let result = await diarizeTask.result
        switch result {
        case .success:
            // Cancellation might allow a partial result in some implementations
            break
        case .failure(let error):
            // CancellationError is the expected outcome for cooperative cancellation
            #expect(error is CancellationError, "Expected CancellationError, got \(error)")
        }
    }

    @Test func testDiarizeFileTimeoutWithTaskGroup() async throws {
        let client = MockFluidAudioClient.diarizationHang()
        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")

        let timeoutSeconds: TimeInterval = 0.1

        // Simulate the timeout pattern used in production (withThrowingTaskGroup)
        do {
            _ = try await withThrowingTaskGroup(of: [DiarizationMapping.SpeakerSegment].self) { group in
                group.addTask {
                    try await client.diarizeFile(dummyURL)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeoutSeconds))
                    throw OfflineTranscriptionError.timeout
                }
                guard let result = try await group.next() else {
                    throw OfflineTranscriptionError.timeout
                }
                group.cancelAll()
                return result
            }
            Issue.record("Expected timeout error")
        } catch let error as OfflineTranscriptionError {
            #expect(error == .timeout, "Should timeout cleanly")
        } catch {
            // CancellationError from the hanging task is also acceptable
            #expect(error is CancellationError, "Unexpected error: \(error)")
        }
    }

    // MARK: - Data-Oriented Output

    @Test func testDiarizeFileOutputIsDataOriented() async throws {
        // Verify that diarizeFile returns pure data types (DiarizationMapping.SpeakerSegment)
        // that can be used for mapping without any DB side effects
        let segments: [DiarizationMapping.SpeakerSegment] = [
            .init(speakerId: "alpha", startTimeSeconds: 0.0, endTimeSeconds: 10.0),
            .init(speakerId: "beta", startTimeSeconds: 10.0, endTimeSeconds: 20.0),
        ]
        let client = MockFluidAudioClient.client(
            diarizationBehavior: .success(segments)
        )

        let dummyURL = URL(fileURLWithPath: "/tmp/test-audio.caf")
        let result = try await client.diarizeFile(dummyURL)

        // Verify the output is the same data-oriented struct type
        #expect(result.count == 2)
        for segment in result {
            // SpeakerSegment has speakerId, startTimeSeconds, endTimeSeconds, durationSeconds
            #expect(segment.durationSeconds > 0)
            #expect(!segment.speakerId.isEmpty)
        }

        // Verify we can use the output for DiarizationMapping operations
        let dominant = DiarizationMapping.findDominantSpeaker(in: result)
        #expect(dominant != nil, "Should be able to find dominant speaker from diarizeFile output")
    }

    // MARK: - Integration with Dependency System

    @Test func testDiarizeFileThroughDependencyInjection() async throws {
        let expectedSegments: [DiarizationMapping.SpeakerSegment] = [
            .init(speakerId: "speaker-A", startTimeSeconds: 0.0, endTimeSeconds: 5.0),
        ]

        let result = try await withDependencies {
            $0.fluidAudioClient = MockFluidAudioClient.client(
                diarizationBehavior: .success(expectedSegments)
            )
        } operation: {
            @Dependency(\.fluidAudioClient) var fluidAudioClient
            let dummyURL = URL(fileURLWithPath: "/tmp/test.caf")
            return try await fluidAudioClient.diarizeFile(dummyURL)
        }

        #expect(result.count == 1)
        #expect(result[0].speakerId == "speaker-A")
    }
}
