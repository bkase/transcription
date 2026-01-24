import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence
import DesignSystem
import Tagged

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
public struct SessionDetailFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient

    @ObservableState
    public struct State: Equatable {
        public var sessionID: SessionID
        public var session: SessionRecord?
        public var segments: [DetailSegment] = []
        public var speakerTracks: [DetailSpeakerTrack] = []
        public var isLoading: Bool = false
        public var error: String?

        public init(
            sessionID: SessionID,
            session: SessionRecord? = nil,
            segments: [DetailSegment] = [],
            speakerTracks: [DetailSpeakerTrack] = [],
            isLoading: Bool = false,
            error: String? = nil
        ) {
            self.sessionID = sessionID
            self.session = session
            self.segments = segments
            self.speakerTracks = speakerTracks
            self.isLoading = isLoading
            self.error = error
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case loadSession
        case sessionLoaded(SessionRecord?, [DetailSegment], [DetailSpeakerTrack])
        case loadFailed(String)
        case backTapped
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
                            machineSpeakerId: record.machineSpeakerId,
                            displayOrder: record.displayOrder,
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
                return .none

            case let .loadFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                return .none

            case .backTapped:
                // Navigation intent - handled by parent
                return .none
            }
        }
    }
}
