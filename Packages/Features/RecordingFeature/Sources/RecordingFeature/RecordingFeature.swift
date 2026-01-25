import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence
import Audio
import Processing
import DesignSystem

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
    public let machineSpeakerId: String
    public let displayOrder: Int
    public let personName: String?

    public init(
        machineSpeakerId: String,
        displayOrder: Int,
        personName: String?
    ) {
        self.machineSpeakerId = machineSpeakerId
        self.displayOrder = displayOrder
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
            isPermissionDenied: Bool = false
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
        }
    }

    public enum Action: Equatable, Sendable {
        /// Start recording with the given audio directory
        case startRecording(audioDirectory: URL)
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

                return .run { send in
                    do {
                        let eventStream = try await recordingProcessorClient.startRecording(audioDirectory)

                        // Listen for events
                        for await event in eventStream {
                            await send(.processorEvent(event))
                        }
                    } catch {
                        await send(.recordingFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.processorEvents, cancelInFlight: true)

            case .permissionDenied:
                state.isPermissionDenied = true
                state.error = "Microphone access is required to record. Please enable it in Settings."
                return .none

            case .openSettingsTapped:
                return .run { [microphonePermissionClient] _ in
                    await microphonePermissionClient.openSettings()
                }

            case .stopRecording:
                guard state.isRecording else { return .none }

                // Don't cancel processor events here - let the processor emit
                // .didFinish and finish the stream naturally
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in
                        await recordingProcessorClient.stopRecording()
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
                state.elapsedSeconds += 1
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
                                machineSpeakerId: record.machineSpeakerId,
                                displayOrder: record.displayOrder,
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
                    // Keep elapsedSeconds for display until view navigates away
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .cancel(id: CancelID.processorEvents)
                    )

                case let .didFail(errorMessage):
                    state.error = errorMessage
                    state.isRecording = false
                    state.isPaused = false
                    state.isListening = false
                    state.liveSegments = []
                    state.speakerTracks = []
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .cancel(id: CancelID.processorEvents)
                    )
                }

            case let .recordingStarted(sessionID):
                state.sessionID = sessionID
                return .none

            case let .recordingFailed(errorMessage):
                state.isRecording = false
                state.error = errorMessage
                return .none

            case let .segmentsLoaded(segments, tracks):
                state.liveSegments = segments
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
            }
        }
    }
}
