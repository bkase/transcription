import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Observability
import Persistence
import DesignSystem
import Export
import Processing

@Reducer
public struct TimelineFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.date) var date
    @Dependency(\.uuid) var uuid
    @Dependency(\.fluidAudioClient) var fluidAudioClient

    private enum CancelID {
        case transcriptionPolling
    }

    @ObservableState
    public struct State: Equatable {
        public var searchQuery: String = ""
        public var sessionGroups: [SessionGroup] = []
        public var searchResults: [SessionRecord] = []
        public var isLoading: Bool = false
        public var error: String?
        /// Alert info for displaying errors with recovery options
        public var alertInfo: AlertInfo?

        // Delete flow state
        public var sessionToDelete: SessionRecord?
        public var isShowingDeleteConfirmation: Bool = false
        public var isDeleting: Bool = false

        // Model preparation state
        public var modelPreparationState: ModelPreparationState = .idle

        // User profile for avatar display
        public var userProfile: UserProfile = .empty

        // Speaker info for session cards
        public var speakerInfoBySession: [String: [SessionSpeakerInfo]] = [:]

        /// Whether the user is actively searching (non-empty query)
        public var isSearching: Bool {
            !searchQuery.isEmpty
        }

        /// Whether recording is enabled (models ready)
        public var isRecordEnabled: Bool {
            modelPreparationState == .ready
        }

        /// Whether any visible sessions are currently being transcribed
        public var hasTranscribingSessions: Bool {
            sessionGroups.contains { group in
                group.sessions.contains { $0.processingState == .transcribing }
            }
        }

        /// Compute initials from the profile name for avatar display
        public var initials: String {
            let components = userProfile.name.split(separator: " ")
            if components.count >= 2 {
                let first = components[0].prefix(1)
                let last = components[components.count - 1].prefix(1)
                return "\(first)\(last)".uppercased()
            } else if let first = components.first?.prefix(1) {
                return String(first).uppercased()
            }
            return ""
        }

        public init(
            searchQuery: String = "",
            sessionGroups: [SessionGroup] = [],
            searchResults: [SessionRecord] = [],
            isLoading: Bool = false,
            error: String? = nil,
            alertInfo: AlertInfo? = nil,
            sessionToDelete: SessionRecord? = nil,
            isShowingDeleteConfirmation: Bool = false,
            isDeleting: Bool = false,
            modelPreparationState: ModelPreparationState = .idle,
            userProfile: UserProfile = .empty,
            speakerInfoBySession: [String: [SessionSpeakerInfo]] = [:]
        ) {
            self.searchQuery = searchQuery
            self.sessionGroups = sessionGroups
            self.searchResults = searchResults
            self.isLoading = isLoading
            self.error = error
            self.alertInfo = alertInfo
            self.sessionToDelete = sessionToDelete
            self.isShowingDeleteConfirmation = isShowingDeleteConfirmation
            self.isDeleting = isDeleting
            self.modelPreparationState = modelPreparationState
            self.userProfile = userProfile
            self.speakerInfoBySession = speakerInfoBySession
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case onDisappear
        case searchQueryChanged(String)
        case loadSessions
        case sessionsLoaded([SessionGroup], [String: [SessionSpeakerInfo]])
        case sessionsFailed(String)
        case searchPerformed([SessionRecord], [String: [SessionSpeakerInfo]])
        case sessionTapped(SessionID)
        case newRecordingTapped
        /// User tapped the header avatar to navigate to profile
        case avatarTapped
        /// User tapped a recovery action in the alert
        case alertActionTapped(RecoveryAction)
        /// Alert was dismissed
        case alertDismissed

        // Delete actions
        case deleteSessionTapped(SessionRecord)
        case deleteConfirmed
        case deleteCancelled
        case deleteCompleted(SessionID)
        case deleteFailed(String)

        // Model preparation actions
        case prepareModels
        case modelPreparationSucceeded
        case modelPreparationFailed(String)

        // Transcription polling actions
        case pollTranscribingSessions
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Start model preparation if not already ready or downloading
                let shouldPrepareModels = state.modelPreparationState == .idle

                // Always load sessions on appear to ensure fresh data after navigation.
                // This ensures changes made in child features (title edits, speaker assignments)
                // are visible immediately when returning to the timeline. (bd-16zo fix)
                let shouldLoadSessions = !state.isLoading

                // Start polling if there are transcribing sessions
                let shouldStartPolling = state.hasTranscribingSessions

                var effects: [Effect<Action>] = []
                if shouldPrepareModels {
                    effects.append(.send(.prepareModels))
                }
                if shouldLoadSessions {
                    effects.append(.send(.loadSessions))
                }
                if shouldStartPolling {
                    effects.append(
                        .run { send in
                            try? await Task.sleep(for: .seconds(5))
                            await send(.pollTranscribingSessions)
                        }
                        .cancellable(id: CancelID.transcriptionPolling, cancelInFlight: true)
                    )
                }

                guard !effects.isEmpty else { return .none }
                return .merge(effects)

            case .onDisappear:
                // Cancel polling when view disappears
                return .cancel(id: CancelID.transcriptionPolling)

            case let .searchQueryChanged(query):
                state.searchQuery = query

                if query.isEmpty {
                    state.searchResults = []
                    // Reload all sessions when clearing search
                    return .send(.loadSessions)
                }

                // Perform FTS search with full session details
                return .run { send in
                    let results = try await databaseClient.searchSessionsWithDetails(query)

                    // Fetch speaker info for search results
                    let sessionIds = results.map { SessionID(rawValue: $0.id) }
                    let speakerInfo = try await databaseClient.fetchSpeakerInfoForSessions(sessionIds)

                    await send(.searchPerformed(results, speakerInfo))
                } catch: { error, send in
                    await send(.sessionsFailed(error.localizedDescription))
                }

            case .loadSessions:
                state.isLoading = true
                state.error = nil

                return .run { [date] send in
                    let groups = try await databaseClient.fetchSessionsGroupedByDate(date.now)

                    // Collect all session IDs to fetch speaker info
                    var sessionIds: [SessionID] = []
                    for group in groups {
                        for session in group.sessions {
                            sessionIds.append(SessionID(rawValue: session.id))
                        }
                    }

                    // Fetch speaker info for all sessions
                    let speakerInfo = try await databaseClient.fetchSpeakerInfoForSessions(sessionIds)

                    await send(.sessionsLoaded(groups, speakerInfo))
                } catch: { error, send in
                    await send(.sessionsFailed(error.localizedDescription))
                }

            case let .sessionsLoaded(groups, speakerInfo):
                state.isLoading = false
                state.sessionGroups = groups
                state.speakerInfoBySession = speakerInfo

                // Start polling if any sessions are transcribing
                let hasTranscribing = groups.contains { group in
                    group.sessions.contains { $0.processingState == .transcribing }
                }
                if hasTranscribing {
                    return .run { send in
                        try? await Task.sleep(for: .seconds(5))
                        await send(.pollTranscribingSessions)
                    }
                    .cancellable(id: CancelID.transcriptionPolling, cancelInFlight: true)
                }
                return .none

            case let .sessionsFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                // Create an error envelope and convert to alert with deterministic ID
                let envelope = ErrorEnvelope.databaseRead(message: errorMessage)
                let alertInfo = envelope.toAlertInfo()
                state.alertInfo = AlertInfo(
                    id: uuid().uuidString,
                    title: alertInfo.title,
                    message: alertInfo.message,
                    primaryButton: alertInfo.primaryButton,
                    secondaryButton: alertInfo.secondaryButton
                )
                return .none

            case let .searchPerformed(results, speakerInfo):
                state.searchResults = results
                // Merge speaker info into existing map (search results may overlap with current sessions)
                for (sessionId, info) in speakerInfo {
                    state.speakerInfoBySession[sessionId] = info
                }
                return .none

            case .sessionTapped:
                // Navigation intent - will be handled by parent
                return .none

            case .newRecordingTapped:
                // Gate recording: only proceed if models are ready
                guard state.isRecordEnabled else {
                    return .none
                }
                // Navigation intent - will be handled by parent
                return .none

            case .avatarTapped:
                // Navigation intent - will be handled by parent
                return .none

            case let .alertActionTapped(action):
                state.alertInfo = nil
                switch action {
                case .retry:
                    return .send(.loadSessions)
                case .dismiss:
                    return .none
                default:
                    return .none
                }

            case .alertDismissed:
                state.alertInfo = nil
                return .none

            // MARK: - Delete Actions

            case let .deleteSessionTapped(session):
                state.sessionToDelete = session
                state.isShowingDeleteConfirmation = true
                return .none

            case .deleteConfirmed:
                state.isShowingDeleteConfirmation = false
                guard let session = state.sessionToDelete, !state.isDeleting else { return .none }
                state.isDeleting = true
                let sessionID = SessionID(rawValue: session.id)

                return .run { [session, databaseClient, fileClient] send in
                    // Delete audio file if it exists
                    if let audioPath = session.audioPath {
                        let audioURL = URL(fileURLWithPath: audioPath)
                        if fileClient.exists(audioURL) {
                            try? await fileClient.delete(audioURL)
                        }
                    }

                    // Delete session from database (cascades to segments, tracks, etc.)
                    try await databaseClient.deleteSession(sessionID)

                    await send(.deleteCompleted(sessionID))
                } catch: { error, send in
                    await send(.deleteFailed(error.localizedDescription))
                }

            case .deleteCancelled:
                state.isShowingDeleteConfirmation = false
                state.sessionToDelete = nil
                return .none

            case let .deleteCompleted(sessionID):
                state.isDeleting = false
                state.sessionToDelete = nil
                // Remove from local state - recreate groups without the deleted session
                state.sessionGroups = state.sessionGroups.compactMap { group in
                    let filteredSessions = group.sessions.filter { $0.id != sessionID.rawValue }
                    guard !filteredSessions.isEmpty else { return nil }
                    return SessionGroup(bucket: group.bucket, sessions: filteredSessions)
                }
                // Remove from search results if present
                state.searchResults.removeAll { $0.id == sessionID.rawValue }
                return .none

            case let .deleteFailed(errorMessage):
                state.isDeleting = false
                state.sessionToDelete = nil
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

            // MARK: - Model Preparation Actions

            case .prepareModels:
                // Set state to downloading immediately
                state.modelPreparationState = .downloading
                return .run { [fluidAudioClient] send in
                    await fluidAudioClient.prepareModels()
                    let status = await fluidAudioClient.modelStatus()
                    switch status {
                    case .ready:
                        await send(.modelPreparationSucceeded)
                    case .failed(let message):
                        await send(.modelPreparationFailed(message))
                    case .idle, .downloading:
                        // Shouldn't happen after prepareModels completes, but handle gracefully
                        await send(.modelPreparationFailed("Model preparation did not complete"))
                    }
                }

            case .modelPreparationSucceeded:
                state.modelPreparationState = .ready
                return .none

            case let .modelPreparationFailed(message):
                state.modelPreparationState = .failed(message)
                return .none

            // MARK: - Transcription Polling

            case .pollTranscribingSessions:
                // Only poll if there are transcribing sessions visible
                guard state.hasTranscribingSessions else {
                    return .cancel(id: CancelID.transcriptionPolling)
                }

                // Reload sessions to get updated processing states
                return .run { [date] send in
                    let groups = try await databaseClient.fetchSessionsGroupedByDate(date.now)

                    // Collect all session IDs to fetch speaker info
                    var sessionIds: [SessionID] = []
                    for group in groups {
                        for session in group.sessions {
                            sessionIds.append(SessionID(rawValue: session.id))
                        }
                    }

                    // Fetch speaker info for all sessions
                    let speakerInfo = try await databaseClient.fetchSpeakerInfoForSessions(sessionIds)

                    await send(.sessionsLoaded(groups, speakerInfo))
                } catch: { _, _ in
                    // Silently continue polling on error
                }
            }
        }
    }
}
