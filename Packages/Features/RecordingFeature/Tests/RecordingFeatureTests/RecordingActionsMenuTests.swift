import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import RecordingFeature
@testable import Processing
@testable import Audio

@MainActor
struct RecordingActionsMenuTests {

    // MARK: - testMoreMenuPresentsOptions

    @Test
    func testMoreMenuPresentsOptions() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-menu")

        // Create a continuation we can control
        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in
                return eventStream
            }
            $0.recordingProcessorClient.stopRecording = { }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
            $0.preferencesClient.getAudioRetentionMode = { .both }
            $0.preferencesClient.setAudioRetentionMode = { _ in }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        // Emit didStart event from processor
        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Initially menu is not shown
        #expect(!store.state.isShowingActionsMenu)

        // Tap more button
        await store.send(.moreButtonTapped) {
            $0.isShowingActionsMenu = true
            $0.audioRetentionMode = .both
        }

        // Dismiss menu
        await store.send(.actionsMenuDismissed) {
            $0.isShowingActionsMenu = false
        }

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testSetPrivacyModeFromMenu

    @Test
    func testSetPrivacyModeFromMenu() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-privacy")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        var savedMode: AudioRetentionMode?

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
            $0.preferencesClient.getAudioRetentionMode = { .both }
            $0.preferencesClient.setAudioRetentionMode = { mode in
                savedMode = mode
            }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Open menu
        await store.send(.moreButtonTapped) {
            $0.isShowingActionsMenu = true
            $0.audioRetentionMode = .both
        }

        // Set privacy mode to transcript only
        await store.send(.setAudioRetentionMode(.transcriptOnly)) {
            $0.audioRetentionMode = .transcriptOnly
        }

        // Verify preference was saved
        #expect(savedMode == .transcriptOnly)

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }

    // MARK: - testDiscardFromMenu

    @Test
    func testDiscardFromMenu() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-menu-discard")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        var discardCalled = false

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
            $0.recordingProcessorClient.discardRecording = {
                discardCalled = true
            }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.playStopSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
            $0.feedbackClient.triggerStopHaptic = { }
            $0.preferencesClient.getAudioRetentionMode = { .both }
            $0.preferencesClient.setAudioRetentionMode = { _ in }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Open menu and tap discard - this triggers discardTapped from the menu
        // (menu closes automatically when action is selected)
        await store.send(.moreButtonTapped) {
            $0.isShowingActionsMenu = true
            $0.audioRetentionMode = .both
        }

        // Dismiss menu (happens before discardTapped in real flow)
        await store.send(.actionsMenuDismissed) {
            $0.isShowingActionsMenu = false
        }

        // User taps discard from the menu - shows confirmation
        await store.send(.discardTapped) {
            $0.isShowingDiscardConfirmation = true
        }

        // Confirm discard
        await store.send(.discardConfirmed) {
            $0.isShowingDiscardConfirmation = false
        }

        // Verify discard was called
        #expect(discardCalled)

        // Processor emits didDiscard event
        eventContinuation?.yield(.didDiscard(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.isRecording = false
            $0.isListening = false
            $0.sessionID = nil
            $0.elapsedSeconds = 0
        }

        // Clean up
        eventContinuation?.finish()
    }

    // MARK: - testMoreButtonWhileNotRecordingIsIgnored

    @Test
    func testMoreButtonWhileNotRecordingIsIgnored() async {
        let store = TestStore(
            initialState: RecordingFeature.State(isRecording: false)
        ) {
            RecordingFeature()
        }

        // More button while not recording should be ignored
        await store.send(.moreButtonTapped)
    }

    // MARK: - testAudioRetentionModeLoadsCurrentPreference

    @Test
    func testAudioRetentionModeLoadsCurrentPreference() async {
        let audioDirectory = FileManager.default.temporaryDirectory
        let mockSessionID = SessionID("test-session-load-pref")

        var eventContinuation: AsyncStream<RecordingProcessorEvent>.Continuation?
        let eventStream = AsyncStream<RecordingProcessorEvent> { continuation in
            eventContinuation = continuation
        }

        let clock = TestClock()

        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.recordingProcessorClient.startRecording = { _ in eventStream }
            $0.recordingProcessorClient.stopRecording = { }
            $0.feedbackClient.playStartSound = { }
            $0.feedbackClient.triggerStartHaptic = { }
            // Return transcriptOnly as the saved preference
            $0.preferencesClient.getAudioRetentionMode = { .transcriptOnly }
            $0.preferencesClient.setAudioRetentionMode = { _ in }
        }

        // Start recording
        await store.send(.startRecording(audioDirectory: audioDirectory))

        await store.receive(\.permissionGranted) {
            $0.isRecording = true
            $0.audioDirectory = audioDirectory
        }

        eventContinuation?.yield(.didStart(mockSessionID))
        await store.receive(\.processorEvent) {
            $0.sessionID = mockSessionID
        }

        // Open menu - should load transcriptOnly from preference
        await store.send(.moreButtonTapped) {
            $0.isShowingActionsMenu = true
            $0.audioRetentionMode = .transcriptOnly
        }

        // Clean up
        eventContinuation?.finish()
        await store.send(.stopRecording)
    }
}
