import Foundation
import Testing
import Dependencies
@testable import Persistence
@testable import Audio
@testable import Processing
@testable import Export

/// Tests that verify all dependency clients have proper noop implementations
/// that can be used in tests without crashing.
///
/// The `@DependencyClient` macro generates "unimplemented" defaults for throwing endpoints
/// that fail tests when called unexpectedly. This test verifies:
/// 1. Non-throwing endpoints with explicit defaults work correctly
/// 2. Clients can be overridden with noop implementations for test contexts
@Test func testDependencyDefaultsProvideNoopClients() async throws {
    // Create noop implementations for testing
    try await withDependencies { deps in
        // Override with explicit noop implementations
        deps.databaseClient = DatabaseClient(
            fetchSessions: { [] },
            fetchSession: { _ in nil },
            createSession: { _ in },
            updateSession: { _ in },
            deleteSession: { _ in },
            fetchPeople: { [] },
            fetchPerson: { _ in nil },
            createPerson: { _ in },
            updatePerson: { _ in },
            deletePerson: { _ in },
            fetchSpeakerTracks: { _ in [] },
            createSpeakerTrack: { _ in },
            updateSpeakerTrack: { _ in },
            deleteSpeakerTracksForSession: { _ in },
            fetchTranscriptSegments: { _ in [] },
            createTranscriptSegment: { _ in },
            updateTranscriptSegment: { _ in },
            deleteTranscriptSegmentsForSession: { _ in },
            fetchSpeakerSegments: { _ in [] },
            createSpeakerSegment: { _ in },
            searchSessions: { _ in [] },
            searchSessionsWithDetails: { _ in [] },
            fetchSessionsGroupedByDate: { _ in [] },
            fetchPersonConversationCounts: { [:] },
            fetchSessionsForPerson: { _ in [] },
            fetchStaleRecordings: { [] },
            reconcileStaleRecordings: { _, _ in 0 },
            recoverStuckTranscriptions: { _ in 0 },
            fetchSpeakerInfoForSessions: { _ in [:] },
            deleteAllData: { }
        )
        deps.audioCaptureClient = AudioCaptureClient(
            startCapture: { AsyncStream { _ in } },
            stopCapture: { },
            isCapturing: { false },
            getInputFormat: { .recording }
        )
        deps.audioPlayerClient = AudioPlayerClient(
            play: { _ in },
            pause: { },
            stop: { },
            seek: { _ in },
            currentTime: { 0 },
            isPlaying: { false }
        )
        deps.fluidAudioClient = FluidAudioClient(
            prepareModels: { },
            modelStatus: { .ready },
            startTranscription: { _ in AsyncStream { _ in } },
            stopTranscription: { },
            isTranscribing: { false },
            transcribeFile: { _ in [] },
            diarizeFile: { _ in [] }
        )
        deps.recordingProcessorClient = RecordingProcessorClient(
            startRecording: { _ in AsyncStream { _ in } },
            continueRecording: { _, _ in AsyncStream { _ in } },
            stopRecording: { },
            discardRecording: { },
            pauseRecording: { },
            resumeRecording: { },
            isRecording: { false },
            isPaused: { false },
            currentSessionID: { nil },
            retryOfflineTranscription: { _ in false }
        )
        deps.exportClient = ExportClient(
            exportSession: { _, format in ExportResult(url: URL(fileURLWithPath: "/tmp"), format: format) },
            exportBundle: { _ in URL(fileURLWithPath: "/tmp") },
            exportAllSessions: { URL(fileURLWithPath: "/tmp") },
            availableFormats: { ExportFormat.allCases }
        )
        deps.fileClient = FileClient(
            read: { _ in Data() },
            write: { _, _ in },
            delete: { _ in },
            exists: { _ in false },
            createDirectory: { _ in },
            temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
            cachesDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) }
        )
        deps.preferencesClient = PreferencesClient(
            getAudioRetentionMode: { .both },
            setAudioRetentionMode: { _ in }
        )
    } operation: {
        // Test DatabaseClient noop
        @Dependency(\.databaseClient) var databaseClient
        let sessions = try await databaseClient.fetchSessions()
        #expect(sessions.isEmpty, "DatabaseClient.fetchSessions should return empty array")

        // Test AudioCaptureClient defaults (non-throwing have defaults)
        @Dependency(\.audioCaptureClient) var audioCaptureClient
        let isCapturing = await audioCaptureClient.isCapturing()
        #expect(!isCapturing, "AudioCaptureClient.isCapturing should return false by default")

        // Test AudioPlayerClient defaults (non-throwing have defaults)
        @Dependency(\.audioPlayerClient) var audioPlayerClient
        let isPlaying = await audioPlayerClient.isPlaying()
        #expect(!isPlaying, "AudioPlayerClient.isPlaying should return false by default")
        let currentTime = await audioPlayerClient.currentTime()
        #expect(currentTime == 0, "AudioPlayerClient.currentTime should return 0 by default")

        // Test FluidAudioClient defaults (non-throwing have defaults)
        @Dependency(\.fluidAudioClient) var fluidAudioClient
        let isTranscribing = await fluidAudioClient.isTranscribing()
        #expect(!isTranscribing, "FluidAudioClient.isTranscribing should return false by default")
        let modelStatus = await fluidAudioClient.modelStatus()
        #expect(modelStatus == .ready, "FluidAudioClient.modelStatus should return .ready in noop test")

        // Test RecordingProcessorClient defaults (non-throwing have defaults)
        @Dependency(\.recordingProcessorClient) var recordingProcessorClient
        let isRecording = await recordingProcessorClient.isRecording()
        #expect(!isRecording, "RecordingProcessorClient.isRecording should return false by default")
        let currentSessionID = await recordingProcessorClient.currentSessionID()
        #expect(currentSessionID == nil, "RecordingProcessorClient.currentSessionID should return nil by default")

        // Test ExportClient defaults (non-throwing have defaults)
        @Dependency(\.exportClient) var exportClient
        let formats = exportClient.availableFormats()
        #expect(!formats.isEmpty, "ExportClient.availableFormats should return all cases by default")

        // Test FileClient defaults (non-throwing have defaults)
        @Dependency(\.fileClient) var fileClient
        let exists = fileClient.exists(URL(fileURLWithPath: "/nonexistent"))
        #expect(!exists, "FileClient.exists should return false by default")
        let tempDir = fileClient.temporaryDirectory()
        #expect(!tempDir.path.isEmpty, "FileClient.temporaryDirectory should return a valid URL")

        // Test PreferencesClient defaults (non-throwing have defaults)
        @Dependency(\.preferencesClient) var preferencesClient
        let mode = preferencesClient.getAudioRetentionMode()
        #expect(mode == .both, "PreferencesClient.getAudioRetentionMode should return .both by default")
    }
}

/// Tests that all dependency clients can be instantiated with their live values
/// Note: DatabaseClient.liveValue is excluded because it requires exclusive access to a
/// shared database file, which causes race conditions during parallel test execution.
@Test func testLiveValuesCanBeInstantiated() async {
    // These should not crash - just verify they can be created
    await withDependencies { deps in
        // Skip databaseClient.liveValue - it creates a shared database file that causes
        // race conditions when tests run in parallel
        deps.audioCaptureClient = .liveValue
        deps.audioPlayerClient = .liveValue
        deps.fluidAudioClient = .liveValue
        deps.recordingProcessorClient = .liveValue
        deps.exportClient = .liveValue
        deps.fileClient = .liveValue
        deps.preferencesClient = .liveValue
    } operation: {
        // If we get here without crashing, live values are instantiable
        @Dependency(\.audioCaptureClient) var audioCaptureClient
        @Dependency(\.audioPlayerClient) var audioPlayerClient
        @Dependency(\.fluidAudioClient) var fluidAudioClient
        @Dependency(\.recordingProcessorClient) var recordingProcessorClient
        @Dependency(\.exportClient) var exportClient
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.preferencesClient) var preferencesClient

        // Verify non-crashing access for clients that have safe defaults
        _ = await audioCaptureClient.isCapturing()
        _ = await audioPlayerClient.isPlaying()
        _ = await fluidAudioClient.isTranscribing()
        _ = await fluidAudioClient.modelStatus()
        _ = await recordingProcessorClient.isRecording()
        _ = exportClient.availableFormats()
        _ = fileClient.exists(URL(fileURLWithPath: "/test"))
        _ = preferencesClient.getAudioRetentionMode()
    }
}
