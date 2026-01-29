import CasePaths
import ComposableArchitecture
import CoreGraphics
import Dependencies
import Foundation
import Models
import Persistence
import Processing
import DesignSystem
import AudioPlayerFeature
import SpeakerPickerFeature
import Tagged
import Export
import Observability

/// A transcript segment for display in session detail view
public struct DetailSegment: Equatable, Sendable, Identifiable {
    public let id: TranscriptSegmentID
    public let machineSpeakerId: String?
    public let startMs: Int
    public let endMs: Int
    public let text: String
    /// Pre-resolved speaker type for display. This ensures SwiftUI detects changes when speaker assignments update.
    public let speakerType: SpeakerType

    public init(
        id: TranscriptSegmentID,
        machineSpeakerId: String?,
        startMs: Int,
        endMs: Int,
        text: String,
        speakerType: SpeakerType = .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
    ) {
        self.id = id
        self.machineSpeakerId = machineSpeakerId
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
        self.speakerType = speakerType
    }
}

/// A speaker track with optional person assignment
public struct DetailSpeakerTrack: Equatable, Sendable {
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
public struct SessionDetailFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.exportClient) var exportClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.recordingProcessorClient) var recordingProcessorClient
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case transcriptionPolling
    }

    @ObservableState
    public struct State: Equatable {
        public var sessionID: SessionID
        public var session: SessionRecord?
        public var segments: [DetailSegment] = []
        public var speakerTracks: [DetailSpeakerTrack] = []
        public var isLoading: Bool = false
        public var error: String?
        public var audioPlayer: AudioPlayerFeature.State?
        @Presents public var speakerPicker: SpeakerPickerFeature.State?

        // Share sheet state
        public var isExporting: Bool = false
        public var shareURL: URL?

        // Actions menu state
        public var isShowingActionsMenu: Bool = false
        /// The anchor point for positioning the actions menu near the tap location
        public var menuAnchorPoint: CGPoint = .zero

        // Delete flow state
        public var isShowingDeleteConfirmation: Bool = false
        public var isDeleting: Bool = false
        public var alertInfo: AlertInfo?

        // Title editing state
        public var isEditingTitle: Bool = false
        public var editedTitle: String = ""

        // Retry transcription state
        public var isRetrying: Bool = false

        public init(
            sessionID: SessionID,
            session: SessionRecord? = nil,
            segments: [DetailSegment] = [],
            speakerTracks: [DetailSpeakerTrack] = [],
            isLoading: Bool = false,
            error: String? = nil,
            audioPlayer: AudioPlayerFeature.State? = nil,
            speakerPicker: SpeakerPickerFeature.State? = nil,
            isExporting: Bool = false,
            shareURL: URL? = nil,
            isShowingActionsMenu: Bool = false,
            menuAnchorPoint: CGPoint = .zero,
            isShowingDeleteConfirmation: Bool = false,
            isDeleting: Bool = false,
            alertInfo: AlertInfo? = nil,
            isEditingTitle: Bool = false,
            editedTitle: String = "",
            isRetrying: Bool = false
        ) {
            self.sessionID = sessionID
            self.session = session
            self.segments = segments
            self.speakerTracks = speakerTracks
            self.isLoading = isLoading
            self.error = error
            self.audioPlayer = audioPlayer
            self.speakerPicker = speakerPicker
            self.isExporting = isExporting
            self.shareURL = shareURL
            self.isShowingActionsMenu = isShowingActionsMenu
            self.menuAnchorPoint = menuAnchorPoint
            self.isShowingDeleteConfirmation = isShowingDeleteConfirmation
            self.isDeleting = isDeleting
            self.alertInfo = alertInfo
            self.isEditingTitle = isEditingTitle
            self.editedTitle = editedTitle
            self.isRetrying = isRetrying
        }
    }

    /// Delegate actions for parent feature coordination
    @CasePathable
    public enum Delegate: Equatable, Sendable {
        /// Request to continue recording for this session
        case continueRecordingRequested(sessionID: SessionID, currentDurationMs: Int)
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case onDisappear
        case loadSession
        case sessionLoaded(SessionRecord?, [DetailSegment], [DetailSpeakerTrack])
        case loadFailed(String)
        case pollTranscriptionStatus
        case processingStatusUpdated(SessionRecord?)
        case backTapped
        case audioPlayer(AudioPlayerFeature.Action)
        case speakerLabelTapped(segmentId: TranscriptSegmentID, machineSpeakerId: String?)
        case speakerPicker(PresentationAction<SpeakerPickerFeature.Action>)
        case delegate(Delegate)

        // Title editing
        case titleTapped
        case titleChanged(String)
        case saveTitle
        case cancelTitleEdit
        case titleSaved
        case titleSaveFailed(String)

        // Actions menu
        case moreButtonTapped(anchorPoint: CGPoint)
        case actionsMenuDismissed

        // Share actions
        case shareTapped
        case exportTapped
        case exportCompleted(URL)
        case exportFailed(String)
        case shareSheetDismissed

        // Continue recording action
        case continueRecordingTapped

        // Delete actions
        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case deleteCompleted
        case deleteFailed(String)
        case alertActionTapped(RecoveryAction)
        case alertDismissed

        // Retry transcription actions
        case retryTranscriptionTapped
        case retryTranscriptionCompleted
        case retryTranscriptionFailed(String)

        // Create speaker track for untracked segment
        case speakerTrackCreated(trackId: String, displayOrder: Int)
        case speakerTrackCreationFailed(String)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.session == nil && !state.isLoading else {
                    return .none
                }
                return .send(.loadSession)

            case .onDisappear:
                // Cancel polling when view disappears
                return .cancel(id: CancelID.transcriptionPolling)

            case .loadSession:
                state.isLoading = true
                state.error = nil

                return .run { [sessionID = state.sessionID, databaseClient] send in
                    // Load session, segments, and speaker tracks in parallel
                    async let sessionTask = databaseClient.fetchSession(sessionID)
                    async let segmentsTask = databaseClient.fetchTranscriptSegments(sessionID)
                    async let tracksTask = databaseClient.fetchSpeakerTracks(sessionID)
                    async let peopleTask = databaseClient.fetchPeople()

                    let session = try await sessionTask
                    let segmentRecords = try await segmentsTask
                    let trackRecords = try await tracksTask
                    let people = try await peopleTask

                    // Create a lookup for person names
                    let personLookup = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.name) })

                    // Map segment records to detail segments
                    let segments = segmentRecords.map { record in
                        DetailSegment(
                            id: TranscriptSegmentID(record.id),
                            machineSpeakerId: record.machineSpeakerId,
                            startMs: record.startMs,
                            endMs: record.endMs,
                            text: record.text
                        )
                    }

                    // Map speaker tracks with person names
                    let tracks = trackRecords.map { record in
                        DetailSpeakerTrack(
                            id: record.id,
                            machineSpeakerId: record.machineSpeakerId,
                            displayOrder: record.displayOrder,
                            personId: record.personId,
                            personName: record.personId.flatMap { personLookup[$0] }
                        )
                    }

                    await send(.sessionLoaded(session, segments, tracks))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }

            case let .sessionLoaded(session, segments, tracks):
                state.isLoading = false
                state.session = session
                state.speakerTracks = tracks
                // Merge consecutive same-speaker segments for cleaner display
                let mergedSegments = TranscriptRendering.mergeConsecutiveSegments(segments)
                // Resolve speaker types for each segment using the loaded tracks
                // This ensures SwiftUI detects changes when speaker assignments update
                state.segments = TranscriptRendering.resolveSegmentSpeakerTypes(
                    mergedSegments,
                    speakerTracks: tracks
                )

                // Initialize audio player if session has audio
                if let audioPath = session?.audioPath {
                    let audioURL = URL(fileURLWithPath: audioPath)
                    let durationSeconds = session?.durationMs.map { TimeInterval($0) / 1000.0 } ?? 0
                    state.audioPlayer = AudioPlayerFeature.State(
                        audioURL: audioURL,
                        duration: durationSeconds
                    )
                }

                // Start polling if session is being transcribed
                if session?.processingState == .transcribing {
                    return .run { send in
                        // Poll every 2 seconds
                        try? await Task.sleep(for: .seconds(2))
                        await send(.pollTranscriptionStatus)
                    }
                    .cancellable(id: CancelID.transcriptionPolling, cancelInFlight: true)
                }
                return .none

            case .pollTranscriptionStatus:
                // Lightweight poll - only fetch session, don't reload everything with loading indicator
                return .run { [sessionID = state.sessionID, databaseClient] send in
                    let session = try? await databaseClient.fetchSession(sessionID)
                    await send(.processingStatusUpdated(session))
                }

            case let .processingStatusUpdated(session):
                // Update session without showing loading indicator
                if let session = session {
                    state.session = session

                    // If transcription is complete, do a full reload to get segments
                    if session.processingState == .processed || session.processingState == .partial {
                        return .send(.loadSession)
                    }

                    // If still transcribing, continue polling
                    if session.processingState == .transcribing {
                        return .run { send in
                            try? await Task.sleep(for: .seconds(2))
                            await send(.pollTranscriptionStatus)
                        }
                        .cancellable(id: CancelID.transcriptionPolling, cancelInFlight: true)
                    }
                }
                return .none

            case let .loadFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                return .none

            case .backTapped:
                // Navigation intent - handled by parent
                return .none

            // MARK: - Title Editing

            case .titleTapped:
                guard !state.isEditingTitle else { return .none }
                state.isEditingTitle = true
                state.editedTitle = state.session?.title ?? ""
                return .none

            case let .titleChanged(newTitle):
                state.editedTitle = newTitle
                return .none

            case .saveTitle:
                guard state.isEditingTitle, var session = state.session else { return .none }
                let trimmedTitle = state.editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                session.title = trimmedTitle.isEmpty ? nil : trimmedTitle
                state.session = session
                state.isEditingTitle = false

                return .run { [databaseClient, session] send in
                    try await databaseClient.updateSession(session)
                    await send(.titleSaved)
                } catch: { error, send in
                    await send(.titleSaveFailed(error.localizedDescription))
                }

            case .cancelTitleEdit:
                state.isEditingTitle = false
                state.editedTitle = ""
                return .none

            case .titleSaved:
                // Title saved successfully, nothing more to do
                return .none

            case let .titleSaveFailed(errorMessage):
                // Revert the title in state on error
                state.error = errorMessage
                return .send(.loadSession)

            case .audioPlayer:
                // Handled by child reducer
                return .none

            case let .speakerLabelTapped(segmentId, machineSpeakerId):
                // If we have a machineSpeakerId, find the corresponding track
                if let speakerId = machineSpeakerId,
                   let track = state.speakerTracks.first(where: { $0.machineSpeakerId == speakerId }) {
                    // Open the speaker picker modal with existing track
                    state.speakerPicker = SpeakerPickerFeature.State(
                        speakerTrackId: track.id,
                        sessionId: state.sessionID,
                        displayOrder: track.displayOrder,
                        currentPersonId: track.personId.map { PersonID($0) }
                    )
                    return .none
                }

                // No machineSpeakerId (or no matching track) - create a new speaker track
                let newMachineSpeakerId = uuid().uuidString
                let newTrackId = uuid().uuidString
                let newDisplayOrder = state.speakerTracks.count + 1
                let sessionIdString = state.sessionID.rawValue

                return .run { [databaseClient, segmentId, newMachineSpeakerId, newTrackId, newDisplayOrder, sessionIdString] send in
                    // Create a new speaker track for this segment
                    let newTrack = SpeakerTrackRecord(
                        id: newTrackId,
                        sessionId: sessionIdString,
                        machineSpeakerId: newMachineSpeakerId,
                        displayOrder: newDisplayOrder
                    )
                    try await databaseClient.createSpeakerTrack(newTrack)

                    // Update the segment with the new machineSpeakerId
                    let segments = try await databaseClient.fetchTranscriptSegments(SessionID(sessionIdString))
                    if let segmentRecord = segments.first(where: { $0.id == segmentId.rawValue }) {
                        var updatedSegment = segmentRecord
                        updatedSegment.machineSpeakerId = newMachineSpeakerId
                        try await databaseClient.updateTranscriptSegment(updatedSegment)
                    }

                    await send(.speakerTrackCreated(trackId: newTrackId, displayOrder: newDisplayOrder))
                } catch: { error, send in
                    await send(.speakerTrackCreationFailed(error.localizedDescription))
                }

            case let .speakerTrackCreated(trackId, displayOrder):
                // Open the speaker picker modal with the newly created track
                state.speakerPicker = SpeakerPickerFeature.State(
                    speakerTrackId: trackId,
                    sessionId: state.sessionID,
                    displayOrder: displayOrder,
                    currentPersonId: nil
                )
                return .none

            case let .speakerTrackCreationFailed(errorMessage):
                state.error = errorMessage
                return .none

            case .speakerPicker(.presented(.selectionConfirmed)):
                // Dismiss the modal and reload to get updated speaker tracks
                state.speakerPicker = nil
                return .send(.loadSession)

            case .speakerPicker(.presented(.closeModal)):
                state.speakerPicker = nil
                return .none

            case .speakerPicker:
                // Other speaker picker actions handled by child reducer
                return .none

            // MARK: - Actions Menu

            case let .moreButtonTapped(anchorPoint):
                state.menuAnchorPoint = anchorPoint
                state.isShowingActionsMenu = true
                return .none

            case .actionsMenuDismissed:
                state.isShowingActionsMenu = false
                return .none

            // MARK: - Share Actions

            case .shareTapped:
                // Share action from menu - triggers export then share
                state.isShowingActionsMenu = false
                guard !state.isExporting else { return .none }
                state.isExporting = true
                state.error = nil

                return .run { [sessionID = state.sessionID, exportClient] send in
                    let bundleURL = try await exportClient.exportBundle(sessionID)
                    await send(.exportCompleted(bundleURL))
                } catch: { error, send in
                    await send(.exportFailed(error.localizedDescription))
                }

            case .exportTapped:
                // Export action from menu - same as share for now
                state.isShowingActionsMenu = false
                guard !state.isExporting else { return .none }
                state.isExporting = true
                state.error = nil

                return .run { [sessionID = state.sessionID, exportClient] send in
                    let bundleURL = try await exportClient.exportBundle(sessionID)
                    await send(.exportCompleted(bundleURL))
                } catch: { error, send in
                    await send(.exportFailed(error.localizedDescription))
                }

            case let .exportCompleted(url):
                state.isExporting = false
                state.shareURL = url
                return .none

            case let .exportFailed(errorMessage):
                state.isExporting = false
                state.error = errorMessage
                return .none

            case .shareSheetDismissed:
                state.shareURL = nil
                return .none

            // MARK: - Continue Recording

            case .continueRecordingTapped:
                state.isShowingActionsMenu = false
                // Only allow continuation for processed or partial sessions with audio
                guard let session = state.session,
                      (session.processingState == .processed || session.processingState == .partial),
                      session.audioPath != nil else {
                    return .none
                }
                let currentDurationMs = session.durationMs ?? 0
                return .send(.delegate(.continueRecordingRequested(
                    sessionID: state.sessionID,
                    currentDurationMs: currentDurationMs
                )))

            case .delegate:
                // Delegate actions are handled by parent
                return .none

            // MARK: - Delete Actions

            case .deleteTapped:
                state.isShowingActionsMenu = false
                state.isShowingDeleteConfirmation = true
                return .none

            case .deleteConfirmed:
                state.isShowingDeleteConfirmation = false
                guard !state.isDeleting else { return .none }
                state.isDeleting = true

                return .run { [sessionID = state.sessionID, session = state.session, databaseClient, fileClient] send in
                    // Delete audio file if it exists
                    if let audioPath = session?.audioPath {
                        let audioURL = URL(fileURLWithPath: audioPath)
                        if fileClient.exists(audioURL) {
                            try? await fileClient.delete(audioURL)
                        }
                    }

                    // Delete session from database (cascades to segments, tracks, etc.)
                    try await databaseClient.deleteSession(sessionID)

                    await send(.deleteCompleted)
                } catch: { error, send in
                    await send(.deleteFailed(error.localizedDescription))
                }

            case .deleteCancelled:
                state.isShowingDeleteConfirmation = false
                return .none

            case .deleteCompleted:
                state.isDeleting = false
                // Navigation back handled by parent - this is a signal that deletion succeeded
                return .none

            case let .deleteFailed(errorMessage):
                state.isDeleting = false
                let envelope = ErrorEnvelope.databaseWrite(message: errorMessage)
                let alertInfo = envelope.toAlertInfo()
                state.alertInfo = AlertInfo(
                    id: uuid().uuidString,
                    title: alertInfo.title,
                    message: alertInfo.message,
                    primaryButton: alertInfo.primaryButton,
                    secondaryButton: alertInfo.secondaryButton
                )
                return .none

            case let .alertActionTapped(action):
                state.alertInfo = nil
                switch action {
                case .retry:
                    return .send(.deleteConfirmed)
                case .dismiss:
                    return .none
                default:
                    return .none
                }

            case .alertDismissed:
                state.alertInfo = nil
                return .none

            // MARK: - Retry Transcription

            case .retryTranscriptionTapped:
                guard !state.isRetrying else { return .none }
                guard let session = state.session,
                      session.processingState == .failed || session.processingState == .partial else {
                    return .none
                }

                state.isRetrying = true
                state.error = nil

                return .run { [sessionID = state.sessionID, recordingProcessorClient] send in
                    _ = try await recordingProcessorClient.retryOfflineTranscription(sessionID)
                    await send(.retryTranscriptionCompleted)
                } catch: { error, send in
                    await send(.retryTranscriptionFailed(error.localizedDescription))
                }

            case .retryTranscriptionCompleted:
                state.isRetrying = false
                // Reload session to get updated state and segments
                // Note: Parent (AppFeature) listens for this action to refresh the timeline
                return .send(.loadSession)

            case let .retryTranscriptionFailed(errorMessage):
                state.isRetrying = false
                state.error = errorMessage
                return .none
            }
        }
        .ifLet(\.audioPlayer, action: \.audioPlayer) {
            AudioPlayerFeature()
        }
        .ifLet(\.$speakerPicker, action: \.speakerPicker) {
            SpeakerPickerFeature()
        }
    }
}
