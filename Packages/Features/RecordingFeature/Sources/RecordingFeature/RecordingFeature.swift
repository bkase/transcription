import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Observability
import Persistence
import Audio
import Processing
import DesignSystem
import SpeakerPickerFeature

/// A live transcript segment for display during recording
public struct LiveSegment: Equatable, Sendable {
    public let id: TranscriptSegmentID
    public let machineSpeakerId: String?
    public let startMs: Int
    public let endMs: Int
    public let text: String
    public let isFinal: Bool

    public init(
        id: TranscriptSegmentID,
        machineSpeakerId: String?,
        startMs: Int,
        endMs: Int,
        text: String,
        isFinal: Bool
    ) {
        self.id = id
        self.machineSpeakerId = machineSpeakerId
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
        self.isFinal = isFinal
    }
}

/// A speaker track with optional person assignment for live recording
public struct LiveSpeakerTrack: Equatable, Sendable {
    public let id: String
    public let machineSpeakerId: String
    public let displayOrder: Int
    public let personId: String?
    public let personName: String?

    public init(
        id: String,
        machineSpeakerId: String,
        displayOrder: Int,
        personId: String?,
        personName: String?
    ) {
        self.id = id
        self.machineSpeakerId = machineSpeakerId
        self.displayOrder = displayOrder
        self.personId = personId
        self.personName = personName
    }
}

@Reducer
public struct RecordingFeature {
    public init() {}

    @Dependency(\.recordingProcessorClient) var recordingProcessorClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.uuid) var uuid
    @Dependency(\.microphonePermissionClient) var microphonePermissionClient
    @Dependency(\.feedbackClient) var feedbackClient
    @Dependency(\.preferencesClient) var preferencesClient

    private enum CancelID {
        case timer
        case processorEvents
    }

    @ObservableState
    public struct State: Equatable {
        /// Whether recording is active
        public var isRecording: Bool = false
        /// Whether recording is paused
        public var isPaused: Bool = false
        /// Whether the microphone is listening (may be false during initialization)
        public var isListening: Bool = false
        /// Elapsed recording time in seconds
        public var elapsedSeconds: Int = 0
        /// The current session ID if recording
        public var sessionID: SessionID?
        /// Error message if something went wrong
        public var error: String?
        /// Directory where audio files are stored
        public var audioDirectory: URL?
        /// Live transcript segments loaded from DB
        public var liveSegments: [LiveSegment] = []
        /// Speaker tracks with person assignments
        public var speakerTracks: [LiveSpeakerTrack] = []
        /// Whether microphone permission was denied (shows special UI with Settings button)
        public var isPermissionDenied: Bool = false
        /// Alert info for displaying errors with recovery options
        public var alertInfo: AlertInfo?

        /// Presentation destinations for RecordingFeature.
        /// Using an enum eliminates impossible states (e.g. showing both discard confirmation and actions menu).
        public enum Destination: Equatable, Sendable {
            case discardConfirmation
            case actionsMenu
        }
        public var destination: Destination?

        /// Whether discard confirmation is showing (derived from destination)
        public var isShowingDiscardConfirmation: Bool {
            destination == .discardConfirmation
        }
        /// Whether the actions menu is showing (derived from destination)
        public var isShowingActionsMenu: Bool {
            destination == .actionsMenu
        }
        /// Current audio retention mode (privacy setting)
        public var audioRetentionMode: AudioRetentionMode = .both
        /// Whether live transcription is available (may be unavailable if models failed to load)
        public var isTranscriptionAvailable: Bool = true
        /// Message explaining why transcription is unavailable
        public var transcriptionUnavailableMessage: String?
        /// User profile for avatar display
        public var userProfile: UserProfile = .empty
        /// Speaker picker modal state
        @Presents public var speakerPicker: SpeakerPickerFeature.State?

        // MARK: - Speaker Setup

        /// Whether the speaker setup accordion is expanded
        public var speakerSetupExpanded: Bool = false
        /// Selected speaker count for offline diarization (nil = not yet selected; 1/2/3/4)
        public var selectedSpeakerCount: Int? = nil

        // MARK: - File Playback Mode

        /// Whether this is a file playback session (debug mode)
        public var isFilePlayback: Bool = false
        /// Playback speed for file playback mode (1.0 = real-time)
        public var playbackSpeed: Double = 1.0

        // MARK: - Continuation Mode

        /// If set, this recording is a continuation of an existing session
        public var continuationSessionID: SessionID?
        /// Timestamp offset in milliseconds for continuation mode
        public var timestampOffsetMs: Int = 0

        /// Whether this is a continuation of an existing session
        public var isContinuation: Bool {
            continuationSessionID != nil
        }

        /// Compute initials from the profile name for avatar display
        public var initials: String {
            NameUtils.computeInitials(from: userProfile.name)
        }

        public init(
            isRecording: Bool = false,
            isPaused: Bool = false,
            isListening: Bool = false,
            elapsedSeconds: Int = 0,
            sessionID: SessionID? = nil,
            error: String? = nil,
            audioDirectory: URL? = nil,
            liveSegments: [LiveSegment] = [],
            speakerTracks: [LiveSpeakerTrack] = [],
            isPermissionDenied: Bool = false,
            alertInfo: AlertInfo? = nil,
            destination: Destination? = nil,
            audioRetentionMode: AudioRetentionMode = .both,
            isTranscriptionAvailable: Bool = true,
            transcriptionUnavailableMessage: String? = nil,
            userProfile: UserProfile = .empty,
            speakerPicker: SpeakerPickerFeature.State? = nil,
            speakerSetupExpanded: Bool = false,
            selectedSpeakerCount: Int? = nil,
            continuationSessionID: SessionID? = nil,
            timestampOffsetMs: Int = 0
        ) {
            self.isRecording = isRecording
            self.isPaused = isPaused
            self.isListening = isListening
            self.elapsedSeconds = elapsedSeconds
            self.sessionID = sessionID
            self.error = error
            self.audioDirectory = audioDirectory
            self.liveSegments = liveSegments
            self.speakerTracks = speakerTracks
            self.isPermissionDenied = isPermissionDenied
            self.alertInfo = alertInfo
            self.destination = destination
            self.audioRetentionMode = audioRetentionMode
            self.isTranscriptionAvailable = isTranscriptionAvailable
            self.transcriptionUnavailableMessage = transcriptionUnavailableMessage
            self.userProfile = userProfile
            self.speakerPicker = speakerPicker
            self.speakerSetupExpanded = speakerSetupExpanded
            self.selectedSpeakerCount = selectedSpeakerCount
            self.continuationSessionID = continuationSessionID
            self.timestampOffsetMs = timestampOffsetMs
        }
    }

    public enum Action: Sendable {
        /// Start recording with the given audio directory
        case startRecording(audioDirectory: URL)
        /// Continue an existing recording session
        case continueRecording(audioDirectory: URL, sessionID: SessionID, timestampOffsetMs: Int)
        /// Stop the current recording
        case stopRecording
        /// Pause the current recording
        case pauseRecording
        /// Resume the current recording
        case resumeRecording
        /// Timer tick - increment elapsed time
        case timerTicked
        /// Received processor event
        case processorEvent(RecordingProcessorEvent)
        /// Recording started successfully with session ID
        case recordingStarted(SessionID)
        /// Recording failed to start
        case recordingFailed(String)
        /// Segments and speaker tracks loaded from database
        case segmentsLoaded([LiveSegment], [LiveSpeakerTrack])
        /// View appeared
        case onAppear
        /// View disappeared
        case onDisappear
        /// Permission was granted after requesting
        case permissionGranted(audioDirectory: URL)
        /// Permission was denied
        case permissionDenied
        /// User tapped open settings button
        case openSettingsTapped
        /// User tapped discard button (shows confirmation)
        case discardTapped
        /// User confirmed discard in the confirmation alert
        case discardConfirmed
        /// User cancelled discard in the confirmation alert
        case discardCancelled
        /// User tapped a recovery action in the error alert
        case alertActionTapped(RecoveryAction)
        /// Error alert was dismissed
        case alertDismissed
        /// User tapped more (ellipsis) button
        case moreButtonTapped
        /// Actions menu was dismissed
        case actionsMenuDismissed
        /// User selected a privacy mode from the menu
        case setAudioRetentionMode(AudioRetentionMode)
        /// User tapped a speaker label to assign a person
        case speakerLabelTapped(segmentId: TranscriptSegmentID, machineSpeakerId: String?)
        /// Speaker picker modal actions
        case speakerPicker(PresentationAction<SpeakerPickerFeature.Action>)
        /// Toggle the speaker setup accordion open/closed
        case toggleSpeakerSetup
        /// User selected a speaker count (1, 2, 3, or 4)
        case selectSpeakerCount(Int)
        /// User tapped Stop & Save (requires selectedSpeakerCount != nil)
        case stopAndSave
        /// Start file playback mode (debug)
        case startFilePlayback(audioFileURL: URL)
        /// Set playback speed for file playback mode
        case setPlaybackSpeed(Double)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startRecording(audioDirectory):
                guard !state.isRecording else { return .none }

                // Clear any previous permission denied state
                state.isPermissionDenied = false
                state.error = nil

                // Check permission status synchronously first
                let status = microphonePermissionClient.getStatus()

                switch status {
                case .authorized:
                    // Already authorized, proceed directly
                    return .send(.permissionGranted(audioDirectory: audioDirectory))

                case .undetermined:
                    // Need to request permission
                    return .run { [microphonePermissionClient] send in
                        let granted = await microphonePermissionClient.requestPermission()
                        if granted {
                            await send(.permissionGranted(audioDirectory: audioDirectory))
                        } else {
                            await send(.permissionDenied)
                        }
                    }

                case .denied, .restricted:
                    // Permission denied - show UI with settings button
                    return .send(.permissionDenied)
                }

            case let .permissionGranted(audioDirectory):
                guard !state.isRecording else { return .none }

                state.audioDirectory = audioDirectory
                state.isRecording = true
                state.elapsedSeconds = 0
                state.error = nil
                state.isPermissionDenied = false

                // Check if we're in continuation mode
                let isContinuation = state.continuationSessionID != nil
                let continuationSessionID = state.continuationSessionID
                let timestampOffsetMs = state.timestampOffsetMs

                // For continuation, start timer at offset
                if isContinuation {
                    state.elapsedSeconds = timestampOffsetMs / 1000
                }

                return .merge(
                    .run { send in
                        do {
                            let eventStream: AsyncStream<RecordingProcessorEvent>
                            if isContinuation, let sessionID = continuationSessionID {
                                // Continue existing session
                                let config = ContinuationConfig(
                                    sessionID: sessionID,
                                    timestampOffsetMs: timestampOffsetMs
                                )
                                eventStream = try await recordingProcessorClient.continueRecording(audioDirectory, config)
                            } else {
                                // Start new session
                                eventStream = try await recordingProcessorClient.startRecording(audioDirectory)
                            }

                            // Listen for events
                            for await event in eventStream {
                                await send(.processorEvent(event))
                            }
                        } catch {
                            await send(.recordingFailed(error.localizedDescription))
                        }
                    }
                    .cancellable(id: CancelID.processorEvents, cancelInFlight: true),
                    .run { [feedbackClient] _ in
                        await feedbackClient.triggerStartHaptic()
                        await feedbackClient.playStartSound()
                    }
                )

            case let .continueRecording(audioDirectory, sessionID, timestampOffsetMs):
                guard !state.isRecording else { return .none }

                // Store continuation info in state
                state.continuationSessionID = sessionID
                state.timestampOffsetMs = timestampOffsetMs

                // Check permission status synchronously first
                let status = microphonePermissionClient.getStatus()

                switch status {
                case .authorized:
                    // Already authorized, proceed directly
                    return .send(.permissionGranted(audioDirectory: audioDirectory))

                case .undetermined:
                    // Need to request permission
                    return .run { [microphonePermissionClient] send in
                        let granted = await microphonePermissionClient.requestPermission()
                        if granted {
                            await send(.permissionGranted(audioDirectory: audioDirectory))
                        } else {
                            await send(.permissionDenied)
                        }
                    }

                case .denied, .restricted:
                    // Permission denied - show UI with settings button
                    return .send(.permissionDenied)
                }

            case .permissionDenied:
                state.isPermissionDenied = true
                state.error = "Microphone access is required to record. Please enable it in Settings."
                return .none

            case .openSettingsTapped:
                return .run { [microphonePermissionClient] _ in
                    await microphonePermissionClient.openSettings()
                }

            case .discardTapped:
                guard state.isRecording else { return .none }
                state.destination = .discardConfirmation
                return .none

            case .discardConfirmed:
                state.destination = nil
                guard state.isRecording else { return .none }

                // Cancel timer and call discard on processor
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in
                        await recordingProcessorClient.discardRecording()
                    }
                )

            case .discardCancelled:
                state.destination = nil
                return .none

            case .stopRecording:
                guard state.isRecording else { return .none }

                // Don't cancel processor events here - let the processor emit
                // .didFinish and finish the stream naturally
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in
                        await recordingProcessorClient.stopRecording(nil)
                    }
                )

            case .pauseRecording:
                guard state.isRecording, !state.isPaused else { return .none }

                return .run { _ in
                    await recordingProcessorClient.pauseRecording()
                }

            case .resumeRecording:
                guard state.isRecording, state.isPaused else { return .none }

                return .run { _ in
                    await recordingProcessorClient.resumeRecording()
                }

            case .timerTicked:
                guard state.isRecording, !state.isPaused else { return .none }
                state.elapsedSeconds += state.isFilePlayback ? Int(state.playbackSpeed) : 1
                return .none

            case let .processorEvent(event):
                switch event {
                case let .didStart(sessionID):
                    state.sessionID = sessionID
                    // Start timer when recording starts
                    return .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.timerTicked)
                        }
                    }
                    .cancellable(id: CancelID.timer, cancelInFlight: true)

                case let .listeningChanged(isListening):
                    state.isListening = isListening
                    return .none

                case .didAppendSegment:
                    // Load segments and speaker tracks from DB when a new segment is appended
                    guard let sessionID = state.sessionID else { return .none }
                    return .run { [sessionID, databaseClient] send in
                        // Load segments, speaker tracks, and people in parallel
                        async let segmentsTask = databaseClient.fetchTranscriptSegments(sessionID)
                        async let tracksTask = databaseClient.fetchSpeakerTracks(sessionID)
                        async let peopleTask = databaseClient.fetchPeople()

                        let records = try await segmentsTask
                        let trackRecords = try await tracksTask
                        let people = try await peopleTask

                        // Create a lookup for person names
                        let personLookup = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.name) })

                        let segments = records.map { record in
                            LiveSegment(
                                id: TranscriptSegmentID(record.id),
                                machineSpeakerId: record.machineSpeakerId,
                                startMs: record.startMs,
                                endMs: record.endMs,
                                text: record.text,
                                isFinal: record.isFinal
                            )
                        }

                        // Map speaker tracks with person names
                        let tracks = trackRecords.map { record in
                            LiveSpeakerTrack(
                                id: record.id,
                                machineSpeakerId: record.machineSpeakerId,
                                displayOrder: record.displayOrder,
                                personId: record.personId,
                                personName: record.personId.flatMap { personLookup[$0] }
                            )
                        }

                        await send(.segmentsLoaded(segments, tracks))
                    }

                case .didPause:
                    state.isPaused = true
                    return .none

                case .didResume:
                    state.isPaused = false
                    return .none

                case .didFinish:
                    state.isRecording = false
                    state.isPaused = false
                    state.isListening = false
                    state.sessionID = nil
                    state.liveSegments = []
                    state.speakerTracks = []
                    state.speakerSetupExpanded = false
                    state.selectedSpeakerCount = nil
                    state.continuationSessionID = nil
                    state.timestampOffsetMs = 0
                    state.isFilePlayback = false
                    state.playbackSpeed = 1.0
                    // Keep elapsedSeconds for display until view navigates away
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .cancel(id: CancelID.processorEvents),
                        .run { [feedbackClient] _ in
                            await feedbackClient.triggerStopHaptic()
                            await feedbackClient.playStopSound()
                        }
                    )

                case .didDiscard:
                    state.isRecording = false
                    state.isPaused = false
                    state.isListening = false
                    state.sessionID = nil
                    state.liveSegments = []
                    state.speakerTracks = []
                    state.elapsedSeconds = 0
                    state.speakerSetupExpanded = false
                    state.selectedSpeakerCount = nil
                    state.continuationSessionID = nil
                    state.timestampOffsetMs = 0
                    state.isFilePlayback = false
                    state.playbackSpeed = 1.0
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .cancel(id: CancelID.processorEvents),
                        .run { [feedbackClient] _ in
                            await feedbackClient.triggerStopHaptic()
                            await feedbackClient.playStopSound()
                        }
                    )

                case let .didFail(errorMessage):
                    state.error = errorMessage
                    state.isRecording = false
                    state.isPaused = false
                    state.isListening = false
                    state.liveSegments = []
                    state.speakerTracks = []
                    // Create an error envelope and convert to alert with deterministic ID
                    let envelope = ErrorEnvelope.recordingFinalization(
                        sessionId: state.sessionID?.rawValue ?? "",
                        message: errorMessage
                    )
                    let alertInfo = envelope.toAlertInfo()
                    state.alertInfo = AlertInfo(
                        id: uuid().uuidString,
                        title: alertInfo.title,
                        message: alertInfo.message,
                        primaryButton: alertInfo.primaryButton,
                        secondaryButton: alertInfo.secondaryButton
                    )
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .cancel(id: CancelID.processorEvents)
                    )

                case .interrupted:
                    // Audio session was interrupted (phone call, Siri, etc.)
                    // The processor has already paused capture, update UI state
                    state.isPaused = true
                    return .none

                case let .interruptionEnded(shouldResume):
                    // Audio session interruption ended
                    // If shouldResume is true and we weren't manually paused, processor auto-resumes
                    if shouldResume {
                        state.isPaused = false
                    }
                    // Otherwise, stay paused until user manually resumes
                    return .none

                case .routeChanged:
                    // Audio route changed (headphones disconnected, etc.)
                    // The processor handles restarting capture if needed
                    // No UI state change needed
                    return .none

                case .transcriptionStarted:
                    // Transcription is working - clear any previous unavailable state
                    state.isTranscriptionAvailable = true
                    state.transcriptionUnavailableMessage = nil
                    return .none

                case let .transcriptionUnavailable(message):
                    // Transcription failed to start - audio recording continues
                    state.isTranscriptionAvailable = false
                    state.transcriptionUnavailableMessage = message
                    return .none
                }

            case let .recordingStarted(sessionID):
                state.sessionID = sessionID
                return .none

            case let .recordingFailed(errorMessage):
                state.isRecording = false
                state.error = errorMessage
                // Create an error envelope and convert to alert with deterministic ID
                let envelope = ErrorEnvelope.recordingStart(message: errorMessage)
                let alertInfo = envelope.toAlertInfo()
                state.alertInfo = AlertInfo(
                    id: uuid().uuidString,
                    title: alertInfo.title,
                    message: alertInfo.message,
                    primaryButton: alertInfo.primaryButton,
                    secondaryButton: alertInfo.secondaryButton
                )
                return .none

            case let .segmentsLoaded(segments, tracks):
                // Merge consecutive same-speaker segments for cleaner display
                state.liveSegments = RecordingSpeakerRendering.mergeConsecutiveSegments(segments)
                state.speakerTracks = tracks
                return .none

            case .onAppear:
                return .none

            case .onDisappear:
                // Cancel ongoing effects when view disappears
                return .merge(
                    .cancel(id: CancelID.timer),
                    .cancel(id: CancelID.processorEvents)
                )

            case let .alertActionTapped(action):
                state.alertInfo = nil
                switch action {
                case .retry:
                    // Retry starting recording if we have an audio directory
                    if let audioDirectory = state.audioDirectory {
                        return .send(.startRecording(audioDirectory: audioDirectory))
                    }
                    return .none
                case .dismiss:
                    return .none
                default:
                    return .none
                }

            case .alertDismissed:
                state.alertInfo = nil
                return .none

            case .moreButtonTapped:
                guard state.isRecording else { return .none }
                // Load current preference before showing menu
                state.audioRetentionMode = preferencesClient.getAudioRetentionMode()
                state.destination = .actionsMenu
                return .none

            case .actionsMenuDismissed:
                state.destination = nil
                return .none

            case let .setAudioRetentionMode(mode):
                state.audioRetentionMode = mode
                return .run { [preferencesClient] _ in
                    preferencesClient.setAudioRetentionMode(mode)
                }

            case .toggleSpeakerSetup:
                state.speakerSetupExpanded.toggle()
                return .none

            case let .selectSpeakerCount(count):
                state.selectedSpeakerCount = count
                return .none

            case .stopAndSave:
                guard state.isRecording, state.selectedSpeakerCount != nil else { return .none }
                let speakerCount = state.selectedSpeakerCount

                // Reset setup state
                state.speakerSetupExpanded = false
                state.selectedSpeakerCount = nil

                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in
                        await recordingProcessorClient.stopRecording(speakerCount)
                    }
                )

            case let .startFilePlayback(audioFileURL):
                guard !state.isRecording else { return .none }

                // No permission check needed — no mic
                state.isRecording = true
                state.isFilePlayback = true
                state.elapsedSeconds = 0
                state.error = nil
                state.isPermissionDenied = false

                return .run { [recordingProcessorClient] send in
                    do {
                        let eventStream = try await recordingProcessorClient.startFilePlayback(audioFileURL)
                        for await event in eventStream {
                            await send(.processorEvent(event))
                        }
                    } catch {
                        await send(.recordingFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.processorEvents, cancelInFlight: true)

            case let .setPlaybackSpeed(speed):
                state.playbackSpeed = speed
                return .run { [recordingProcessorClient] _ in
                    await recordingProcessorClient.setPlaybackSpeed(speed)
                }

            case let .speakerLabelTapped(_, machineSpeakerId):
                // Find the speaker track for this segment
                guard let machineSpeakerId = machineSpeakerId,
                      let sessionId = state.sessionID,
                      let track = state.speakerTracks.first(where: { $0.machineSpeakerId == machineSpeakerId }) else {
                    return .none
                }

                // Open the speaker picker modal
                state.speakerPicker = SpeakerPickerFeature.State(
                    speakerTrackId: track.id,
                    sessionId: sessionId,
                    displayOrder: track.displayOrder,
                    currentPersonId: track.personId.map { PersonID($0) },
                    userProfile: state.userProfile
                )
                return .none

            case .speakerPicker(.presented(.selectionConfirmed)):
                // Dismiss the modal and reload speaker tracks
                state.speakerPicker = nil
                guard let sessionID = state.sessionID else { return .none }
                return .run { [sessionID, databaseClient] send in
                    // Reload speaker tracks and people to get updated assignments
                    async let tracksTask = databaseClient.fetchSpeakerTracks(sessionID)
                    async let peopleTask = databaseClient.fetchPeople()

                    let trackRecords = try await tracksTask
                    let people = try await peopleTask

                    // Create a lookup for person names
                    let personLookup = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.name) })

                    // Map speaker tracks with person names
                    let tracks = trackRecords.map { record in
                        LiveSpeakerTrack(
                            id: record.id,
                            machineSpeakerId: record.machineSpeakerId,
                            displayOrder: record.displayOrder,
                            personId: record.personId,
                            personName: record.personId.flatMap { personLookup[$0] }
                        )
                    }

                    // Reload current segments too to update speaker display
                    let records = try await databaseClient.fetchTranscriptSegments(sessionID)
                    let segments = records.map { record in
                        LiveSegment(
                            id: TranscriptSegmentID(record.id),
                            machineSpeakerId: record.machineSpeakerId,
                            startMs: record.startMs,
                            endMs: record.endMs,
                            text: record.text,
                            isFinal: record.isFinal
                        )
                    }

                    await send(.segmentsLoaded(segments, tracks))
                }

            case .speakerPicker(.presented(.closeModal)):
                state.speakerPicker = nil
                return .none

            case .speakerPicker:
                // Other speaker picker actions handled by child reducer
                return .none
            }
        }
        .ifLet(\.$speakerPicker, action: \.speakerPicker) {
            SpeakerPickerFeature()
        }
    }
}
