import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence
import DesignSystem
import AudioPlayerFeature
import SpeakerPickerFeature
import Tagged
import Export

/// A transcript segment for display in session detail view
public struct DetailSegment: Equatable, Sendable, Identifiable {
    public let id: TranscriptSegmentID
    public let machineSpeakerId: String?
    public let startMs: Int
    public let endMs: Int
    public let text: String

    public init(
        id: TranscriptSegmentID,
        machineSpeakerId: String?,
        startMs: Int,
        endMs: Int,
        text: String
    ) {
        self.id = id
        self.machineSpeakerId = machineSpeakerId
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
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
            shareURL: URL? = nil
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
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case loadSession
        case sessionLoaded(SessionRecord?, [DetailSegment], [DetailSpeakerTrack])
        case loadFailed(String)
        case backTapped
        case audioPlayer(AudioPlayerFeature.Action)
        case speakerLabelTapped(segmentId: TranscriptSegmentID, machineSpeakerId: String?)
        case speakerPicker(PresentationAction<SpeakerPickerFeature.Action>)

        // Share actions
        case shareTapped
        case exportCompleted(URL)
        case exportFailed(String)
        case shareSheetDismissed
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.session == nil && !state.isLoading else {
                    return .none
                }
                return .send(.loadSession)

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
                state.segments = segments
                state.speakerTracks = tracks

                // Initialize audio player if session has audio
                if let audioPath = session?.audioPath {
                    let audioURL = URL(fileURLWithPath: audioPath)
                    let durationSeconds = session?.durationMs.map { TimeInterval($0) / 1000.0 } ?? 0
                    state.audioPlayer = AudioPlayerFeature.State(
                        audioURL: audioURL,
                        duration: durationSeconds
                    )
                }
                return .none

            case let .loadFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                return .none

            case .backTapped:
                // Navigation intent - handled by parent
                return .none

            case .audioPlayer:
                // Handled by child reducer
                return .none

            case let .speakerLabelTapped(_, machineSpeakerId):
                // Find the speaker track for this segment
                guard let speakerId = machineSpeakerId,
                      let track = state.speakerTracks.first(where: { $0.machineSpeakerId == speakerId }) else {
                    return .none
                }

                // Open the speaker picker modal
                state.speakerPicker = SpeakerPickerFeature.State(
                    speakerTrackId: track.id,
                    sessionId: state.sessionID,
                    displayOrder: track.displayOrder,
                    currentPersonId: track.personId.map { PersonID($0) }
                )
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

            // MARK: - Share Actions

            case .shareTapped:
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
