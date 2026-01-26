import Testing
import Foundation
import ComposableArchitecture
import Models
import Observability
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

// Test UUID for deterministic alert IDs
private let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

@MainActor
struct RecordingErrorTests {

    // MARK: - testErrorAlertShown

    @Test
    func testErrorAlertShown() async {
        let audioDirectory = FileManager.default.temporaryDirectory

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Audio capture failed" }
        }

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.uuid = .constant(testUUID)
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in
                throw TestError()
            }
        }

        // Initially no alert
        #expect(store.state.alertInfo == nil)

        // Start recording - triggers permission check then permissionGranted
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Should receive failure from processor with alert
        await store.receive(\.recordingFailed) {
            $0.isRecording = false
            $0.error = "Audio capture failed"
            // Alert should be shown with recording error
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Recording Error",
                message: "Audio capture failed",
                primaryButton: .init(title: "Retry", action: .retry),
                secondaryButton: .init(title: "Cancel", action: .dismiss)
            )
        }
    }

    // MARK: - testProcessorFailureShowsAlert

    @Test
    func testProcessorFailureShowsAlert() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-456")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .constant(testUUID)
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Initially no alert
        #expect(store.state.alertInfo == nil)

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Emit didStart
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Emit failure event
        eventContinuation?.yield(.didFail("Storage full"))
        await store.receive(\.processorEvent) {
            $0.error = "Storage full"
            $0.isRecording = false
            $0.isListening = false
            // Alert should be shown
            $0.alertInfo = AlertInfo(
                id: testUUID.uuidString,
                title: "Recording Error",
                message: "Storage full",
                primaryButton: .init(title: "Retry", action: .retryFinalize),
                secondaryButton: .init(title: "Cancel", action: .dismiss)
            )
        }

        // Clean up
        eventContinuation?.finish()
    }

    // MARK: - testAlertDismissedClearsAlert

    @Test
    func testAlertDismissedClearsAlert() async {
        // Create an alert info
        let alertInfo = AlertInfo(
            id: testUUID.uuidString,
            title: "Test Error",
            message: "Test message",
            primaryButton: .init(title: "OK", action: .dismiss)
        )

        let store = TestStore(
            initialState: RecordingFeature.State(alertInfo: alertInfo)
        ) {
            RecordingFeature()
        }

        // Alert is present
        #expect(store.state.alertInfo != nil)

        // Dismiss the alert
        await store.send(.alertDismissed) {
            $0.alertInfo = nil
        }
    }

    // MARK: - testAlertRetryTriggersRecordingStart

    @Test
    func testAlertRetryTriggersRecordingStart() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-retry")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        // Start with an alert showing and audioDirectory set (from previous failed attempt)
        let alertInfo = AlertInfo(
            id: testUUID.uuidString,
            title: "Recording Error",
            message: "Unable to start recording",
            primaryButton: .init(title: "Retry", action: .retry),
            secondaryButton: .init(title: "Cancel", action: .dismiss)
        )

        let store = TestStore(
            initialState: RecordingFeature.State(
                audioDirectory: audioDirectory,
                alertInfo: alertInfo
            )
        ) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .constant(testUUID)
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
        }

        // Tap retry
        await store.send(.alertActionTapped(.retry)) {
            $0.alertInfo = nil
        }

        // Should trigger startRecording
        await store.receive(\.startRecording)

        // Then permissionGranted
        await store.receive(\.permissionGranted) {
            $0.isRecording = true
        }

        // Emit didStart to complete the recording start
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testAlertRetryWithoutAudioDirectoryDoesNothing

    @Test
    func testAlertRetryWithoutAudioDirectoryDoesNothing() async {
        // Start with an alert but no audioDirectory (edge case)
        let alertInfo = AlertInfo(
            id: testUUID.uuidString,
            title: "Recording Error",
            message: "Unable to start recording",
            primaryButton: .init(title: "Retry", action: .retry),
            secondaryButton: .init(title: "Cancel", action: .dismiss)
        )

        let store = TestStore(
            initialState: RecordingFeature.State(alertInfo: alertInfo)
        ) {
            RecordingFeature()
        }

        // Tap retry - should clear alert but not start recording (no audioDirectory)
        await store.send(.alertActionTapped(.retry)) {
            $0.alertInfo = nil
        }

        // No further actions expected since audioDirectory is nil
    }
}
