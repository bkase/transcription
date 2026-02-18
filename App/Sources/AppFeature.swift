import ComposableArchitecture
import Foundation
import OrderedCollections
import TimelineFeature
import RecordingFeature
import SessionDetailFeature
import PeopleFeature
import ProfileFeature
import PersonTimelineFeature
import Persistence
import Processing
import Models
import Export
import Routing
import URLRouting

// MARK: - AppPath (Navigation Stack)

@Reducer(state: .equatable)
public enum AppPath {
    case sessionDetail(SessionDetailFeature)
    case profile(ProfileFeature)
    case personTimeline(PersonTimelineFeature)
    case people(PeopleFeature)
}

// MARK: - AppFeature

@Reducer
public struct AppFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var path: StackState<AppPath.State> = StackState()
        public var timeline: TimelineFeature.State
        @Presents public var recording: RecordingFeature.State?
        public var userProfile: UserProfile = .empty

        public init(
            path: StackState<AppPath.State> = StackState(),
            timeline: TimelineFeature.State = .init(),
            recording: RecordingFeature.State? = nil,
            userProfile: UserProfile = .empty
        ) {
            self.path = path
            self.timeline = timeline
            self.recording = recording
            self.userProfile = userProfile
        }
    }

    public enum Action {
        case onAppear
        case deepLinkOpened(URL)
        case path(StackAction<AppPath.State, AppPath.Action>)
        case timeline(TimelineFeature.Action)
        case recording(PresentationAction<RecordingFeature.Action>)
        case dismissRecording
        case userProfileLoaded(UserProfile)
        case personLoaded(PersonRecord)
        case personLoadFailed(String)
    }

    @Dependency(\.recoveryRoutineClient) var recoveryRoutineClient
    @Dependency(\.userProfileClient) var userProfileClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.fluidAudioClient) var fluidAudioClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    public var body: some ReducerOf<Self> {
        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                // Run recovery routine and load user profile on app start
                return .run { [userProfileClient] send in
                    _ = try? await recoveryRoutineClient.run()
                    let profile = try await userProfileClient.load()
                    await send(.userProfileLoaded(profile))
                }

            case let .deepLinkOpened(url):
                // Parse the URL using AppRouter to determine the route
                guard let requestData = URLRequestData(url: url) else { return .none }
                guard let route = try? AppRouter().parse(requestData) else { return .none }

                switch route {
                case .timeline:
                    // Pop to root (timeline is the root view)
                    state.path.removeAll()
                    return .none

                case let .session(sessionID):
                    // Pop to root then push session detail
                    state.path.removeAll()
                    state.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
                    return .none

                case .people:
                    // Pop to root then push people directory
                    state.path.removeAll()
                    state.path.append(.people(PeopleFeature.State(userProfile: state.userProfile)))
                    return .none

                case .record:
                    // Pop to root and start a new recording
                    state.path.removeAll()
                    return .send(.timeline(.newRecordingTapped))
                }

            case let .userProfileLoaded(profile):
                state.userProfile = profile
                // Sync profile to timeline feature (has settings icon but may need profile for recording)
                state.timeline.userProfile = profile
                // Sync to any features in the navigation path that need userProfile
                state.syncUserProfileToPath(profile)
                return .none

            // MARK: - Navigation Stack Actions

            case .path(.element(id: _, action: .sessionDetail(.backTapped))):
                // Pop the navigation stack when back is tapped
                _ = state.path.popLast()
                return .none

            case .path(.element(id: _, action: .profile(.backTapped))):
                // Pop the navigation stack when back is tapped in profile
                _ = state.path.popLast()
                return .none

            case let .path(.element(id: _, action: .profile(.delegate(.didSaveProfile(profile))))):
                // Update app-level profile state when profile is saved
                state.userProfile = profile
                // Sync to timeline feature
                state.timeline.userProfile = profile
                // Sync to any features in the navigation path that need userProfile
                state.syncUserProfileToPath(profile)
                return .none

            case .path(.element(id: _, action: .profile(.delegate(.didDeleteAllData)))):
                // Pop to root and reload timeline
                state.path.removeAll()
                return .send(.timeline(.loadSessions))

            case let .path(.element(id: _, action: .profile(.delegate(.navigateToSession(sessionID))))):
                // Navigate to session detail from profile (e.g., after test processing)
                state.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
                return .none

            case .path(.element(id: _, action: .profile(.delegate(.runFilePlayback)))):
                // Present RecordingView in file playback mode
                state.recording = RecordingFeature.State(userProfile: state.userProfile)
                guard let audioURL = Bundle.main.url(forResource: "test-diarization-audio", withExtension: "caf") else {
                    NSLog("[AppFeature] test-diarization-audio.caf not found in bundle")
                    return .none
                }
                return .send(.recording(.presented(.startFilePlayback(audioFileURL: audioURL))))

            case let .path(.element(id: id, action: .profile(.delegate(.runTestTranscription)))):
                // Run test processing from profile debug section
                return .run { [databaseClient, fluidAudioClient, uuid, date] send in
                    func updateProfile(_ action: ProfileFeature.Action) async {
                        await send(.path(.element(id: id, action: .profile(action))))
                    }

                    guard let audioURL = Bundle.main.url(forResource: "test-diarization-audio", withExtension: "caf") else {
                        await updateProfile(.testProcessingFailed("Test audio file not found in app bundle"))
                        return
                    }
                    let audioPath = audioURL.path

                    // 1. Create a session record
                    let sessionId = uuid().uuidString
                    let now = date.now
                    let session = SessionRecord(
                        id: sessionId,
                        startedAt: now,
                        endedAt: now,
                        title: "Test Diarization (2 speakers)",
                        audioPath: audioPath,
                        processingState: .transcribing,
                        updatedAt: now
                    )
                    try await databaseClient.createSession(session)
                    await updateProfile(.testProcessingUpdate("Session created. Transcribing file..."))

                    // 2. Transcribe the file
                    let segments: [TranscriptSegment]
                    do {
                        segments = try await fluidAudioClient.transcribeFile(audioURL)
                    } catch {
                        await updateProfile(.testProcessingFailed("Transcription failed: \(error.localizedDescription)"))
                        return
                    }
                    await updateProfile(.testProcessingUpdate("Got \(segments.count) segments. Diarizing (2 speakers)..."))

                    guard !segments.isEmpty else {
                        var s = session
                        s.processingState = .failed
                        s.processingError = "No segments from transcription"
                        try? await databaseClient.updateSession(s)
                        await updateProfile(.testProcessingFailed("Transcription returned no segments"))
                        return
                    }

                    // 3. Diarize with exactly 2 speakers
                    let speakerSegments: [DiarizationMapping.SpeakerSegment]
                    do {
                        speakerSegments = try await fluidAudioClient.diarizeFile(audioURL, 2)
                    } catch {
                        await updateProfile(.testProcessingUpdate("Diarization failed: \(error.localizedDescription). Saving without speakers."))
                        // Save segments without speaker IDs
                        for segment in segments {
                            let record = TranscriptSegmentRecord(
                                id: segment.id.rawValue,
                                sessionId: sessionId,
                                startMs: Int(segment.startMs),
                                endMs: Int(segment.endMs),
                                text: segment.text,
                                isFinal: segment.isFinal,
                                createdAt: now,
                                updatedAt: now
                            )
                            try? await databaseClient.createTranscriptSegment(record)
                        }
                        var s = session
                        s.processingState = .processed
                        s.previewText = segments.prefix(3).map(\.text).joined(separator: " ").prefix(200).description
                        s.updatedAt = date.now
                        try? await databaseClient.updateSession(s)
                        await updateProfile(.testProcessingCompleted(SessionID(sessionId)))
                        return
                    }
                    await updateProfile(.testProcessingUpdate("Got \(speakerSegments.count) speaker segments. Mapping..."))

                    // 4. Map speakers onto transcript segments
                    let intervals = segments.map { seg in
                        DiarizationMapping.TranscriptInterval(
                            id: seg.id,
                            startTimeSeconds: Float(seg.startMs) / 1000.0,
                            endTimeSeconds: Float(seg.endMs) / 1000.0
                        )
                    }
                    let mappingResult = DiarizationMapping.mapSpeakers(
                        intervals: intervals,
                        speakerSegments: speakerSegments
                    )

                    var speakerByIntervalId: [TranscriptSegmentID: String] = [:]
                    for assignment in mappingResult.assignments {
                        if let speakerId = assignment.speakerId {
                            speakerByIntervalId[assignment.intervalId] = speakerId
                        }
                    }

                    let enrichedSegments = segments.map { seg in
                        TranscriptSegment(
                            id: seg.id,
                            text: seg.text,
                            startMs: seg.startMs,
                            endMs: seg.endMs,
                            speakerId: speakerByIntervalId[seg.id],
                            isFinal: seg.isFinal
                        )
                    }

                    // 5. Persist segments and speaker tracks
                    var seenSpeakers: Set<String> = []
                    for segment in enrichedSegments {
                        if let speakerId = segment.speakerId, !seenSpeakers.contains(speakerId) {
                            seenSpeakers.insert(speakerId)
                            let track = SpeakerTrackRecord(
                                id: uuid().uuidString,
                                sessionId: sessionId,
                                machineSpeakerId: speakerId,
                                displayOrder: seenSpeakers.count
                            )
                            try? await databaseClient.createSpeakerTrack(track)
                        }

                        let record = TranscriptSegmentRecord(
                            id: segment.id.rawValue,
                            sessionId: sessionId,
                            startMs: Int(segment.startMs),
                            endMs: Int(segment.endMs),
                            machineSpeakerId: segment.speakerId,
                            text: segment.text,
                            isFinal: segment.isFinal,
                            createdAt: now,
                            updatedAt: now
                        )
                        try? await databaseClient.createTranscriptSegment(record)
                    }

                    // 6. Update session to processed
                    let assignedCount = enrichedSegments.filter { $0.speakerId != nil }.count
                    let previewText = enrichedSegments
                        .filter { $0.isFinal }
                        .prefix(3)
                        .map(\.text)
                        .joined(separator: " ")

                    var finalSession = session
                    finalSession.previewText = previewText.isEmpty ? nil : String(previewText.prefix(200))
                    finalSession.speakerCount = seenSpeakers.count
                    finalSession.processingState = .processed
                    finalSession.updatedAt = date.now
                    try? await databaseClient.updateSession(finalSession)

                    await updateProfile(.testProcessingUpdate("Done! \(segments.count) segments, \(seenSpeakers.count) speakers, \(assignedCount) assigned."))
                    await updateProfile(.testProcessingCompleted(SessionID(sessionId)))
                } catch: { error, send in
                    await send(.path(.element(id: id, action: .profile(.testProcessingFailed(error.localizedDescription)))))
                }

            case let .path(.element(id: id, action: .profile(.delegate(.loadAssemblyAITranscription)))):
                // Load pre-fetched AssemblyAI ground truth transcription from bundle
                return .run { [databaseClient, uuid, date] send in
                    func updateProfile(_ action: ProfileFeature.Action) async {
                        await send(.path(.element(id: id, action: .profile(action))))
                    }

                    guard let jsonURL = Bundle.main.url(forResource: "assemblyai-ground-truth", withExtension: "json") else {
                        await updateProfile(.testProcessingFailed("AssemblyAI JSON not found in app bundle"))
                        return
                    }

                    let data = try Data(contentsOf: jsonURL)
                    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                    let utterances = json["utterances"] as! [[String: Any]]

                    let sessionId = uuid().uuidString
                    let now = date.now

                    // Create session
                    let session = SessionRecord(
                        id: sessionId,
                        startedAt: now,
                        endedAt: now,
                        title: "AssemblyAI Ground Truth (2 speakers)",
                        audioPath: nil,
                        processingState: .processed,
                        updatedAt: now
                    )
                    try await databaseClient.createSession(session)

                    // Create speaker tracks for A and B
                    var speakerTracks: [String: String] = [:]  // "A" -> trackId
                    for (i, speaker) in ["A", "B"].enumerated() {
                        let trackId = uuid().uuidString
                        let track = SpeakerTrackRecord(
                            id: trackId,
                            sessionId: sessionId,
                            machineSpeakerId: speaker,
                            displayOrder: i + 1
                        )
                        try await databaseClient.createSpeakerTrack(track)
                        speakerTracks[speaker] = speaker
                    }

                    // Create transcript segments from utterances
                    for utterance in utterances {
                        let speaker = utterance["speaker"] as? String
                        let text = utterance["text"] as? String ?? ""
                        let startMs = utterance["start"] as? Int ?? 0
                        let endMs = utterance["end"] as? Int ?? 0

                        let segment = TranscriptSegmentRecord(
                            id: uuid().uuidString,
                            sessionId: sessionId,
                            startMs: startMs,
                            endMs: endMs,
                            machineSpeakerId: speaker,
                            text: text,
                            isFinal: true,
                            createdAt: now,
                            updatedAt: now
                        )
                        try await databaseClient.createTranscriptSegment(segment)
                    }

                    // Update session with preview text and speaker count
                    let previewText = utterances.prefix(3).compactMap { $0["text"] as? String }.joined(separator: " ")
                    var finalSession = session
                    finalSession.previewText = String(previewText.prefix(200))
                    finalSession.speakerCount = 2
                    finalSession.updatedAt = date.now
                    try await databaseClient.updateSession(finalSession)

                    await updateProfile(.testProcessingUpdate("Loaded \(utterances.count) utterances from AssemblyAI"))
                    await updateProfile(.testProcessingCompleted(SessionID(sessionId)))
                } catch: { error, send in
                    await send(.path(.element(id: id, action: .profile(.testProcessingFailed(error.localizedDescription)))))
                }

            case .path(.element(id: _, action: .sessionDetail(.deleteCompleted))):
                // Pop the navigation stack and reload timeline when session is deleted
                _ = state.path.popLast()
                return .send(.timeline(.loadSessions))

            case .path(.element(id: _, action: .sessionDetail(.retryTranscriptionCompleted))):
                // Reload timeline when retry transcription completes so the partial chip is removed
                return .send(.timeline(.loadSessions))

            case let .path(.element(id: _, action: .sessionDetail(.delegate(.continueRecordingRequested(sessionID, currentDurationMs))))):
                // Present recording screen in continuation mode
                var recordingState = RecordingFeature.State(userProfile: state.userProfile)
                recordingState.continuationSessionID = sessionID
                recordingState.timestampOffsetMs = currentDurationMs
                state.recording = recordingState

                // Get audio directory from caches
                let audioDir = fileClient.cachesDirectory()
                    .appendingPathComponent("recordings", isDirectory: true)
                // Create directory if needed
                return .run { [fileClient] send in
                    try? await fileClient.createDirectory(audioDir)
                    await send(.recording(.presented(.continueRecording(
                        audioDirectory: audioDir,
                        sessionID: sessionID,
                        timestampOffsetMs: currentDurationMs
                    ))))
                }

            case .path(.element(id: _, action: .sessionDetail(.titleSaved))):
                // Reload timeline when session title is saved so the updated title is visible
                return .send(.timeline(.loadSessions))

            case .path(.element(id: _, action: .sessionDetail(.speakerPicker(.presented(.selectionConfirmed))))):
                // Reload timeline when speaker assignment changes so avatar circles update
                return .send(.timeline(.loadSessions))

            case .path(.element(id: _, action: .personTimeline(.backTapped))):
                // Pop the navigation stack when back is tapped in person timeline
                _ = state.path.popLast()
                return .none

            case let .path(.element(id: _, action: .personTimeline(.sessionTapped(sessionID)))):
                // Push session detail onto navigation stack from person timeline
                state.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
                return .none

            case .path(.element(id: _, action: .personTimeline(.avatarTapped))):
                // Push profile onto navigation stack from person timeline
                state.path.append(.profile(ProfileFeature.State(profile: state.userProfile)))
                return .none

            case .path(.element(id: _, action: .people(.backTapped))):
                // Pop the navigation stack when back is tapped in people directory
                _ = state.path.popLast()
                return .none

            case .path(.element(id: _, action: .people(.selfTapped))):
                // Navigate to profile when user taps on themselves in people directory
                state.path.append(.profile(ProfileFeature.State(profile: state.userProfile)))
                return .none

            case let .path(.element(id: _, action: .people(.personTapped(personId)))):
                // Fetch person record and navigate to person timeline
                return .run { [databaseClient] send in
                    if let person = try await databaseClient.fetchPerson(personId) {
                        await send(.personLoaded(person))
                    } else {
                        await send(.personLoadFailed("Person not found"))
                    }
                } catch: { error, send in
                    await send(.personLoadFailed(error.localizedDescription))
                }

            case .path:
                // Other path actions are handled by forEach below
                return .none

            // MARK: - Timeline Actions

            case let .timeline(.sessionTapped(sessionID)):
                // Push session detail onto navigation stack
                state.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
                return .none

            case .timeline(.newRecordingTapped):
                // Present recording screen and start recording
                state.recording = RecordingFeature.State(userProfile: state.userProfile)
                // Get audio directory from caches
                let audioDir = fileClient.cachesDirectory()
                    .appendingPathComponent("recordings", isDirectory: true)
                // Create directory if needed
                return .run { [fileClient] send in
                    try? await fileClient.createDirectory(audioDir)
                    await send(.recording(.presented(.startRecording(audioDirectory: audioDir))))
                }

            case .timeline(.peopleTapped):
                // Push people directory onto navigation stack with current user profile
                state.path.append(.people(PeopleFeature.State(userProfile: state.userProfile)))
                return .none

            case .timeline(.avatarTapped):
                // Push profile onto navigation stack with current user profile
                state.path.append(.profile(ProfileFeature.State(profile: state.userProfile)))
                return .none

            case .timeline:
                return .none

            // MARK: - People Navigation Results

            case let .personLoaded(person):
                // Push person timeline onto navigation stack
                state.path.append(.personTimeline(PersonTimelineFeature.State(
                    personId: PersonID(person.id),
                    personName: person.name
                )))
                return .none

            case .personLoadFailed:
                // Silently fail - could add error handling UI later
                return .none

            // MARK: - Recording Actions

            case let .recording(.presented(.processorEvent(.didFinish(sessionID)))):
                // Recording finished - navigate to session detail view
                state.recording = nil
                // Push session detail onto navigation stack
                state.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
                // Also reload timeline in background so it's up to date when user goes back
                return .send(.timeline(.loadSessions))

            case .recording(.presented(.processorEvent(.didDiscard(_)))):
                // Recording discarded - dismiss and reload timeline
                state.recording = nil
                return .send(.timeline(.loadSessions))

            case .recording(.dismiss):
                // Stop recording if still in progress when dismissed
                if let recording = state.recording, recording.isRecording {
                    return .send(.recording(.presented(.stopRecording)))
                }
                return .none

            case .recording:
                return .none

            case .dismissRecording:
                // Stop recording if still in progress
                if let recording = state.recording, recording.isRecording {
                    return .merge(
                        .send(.recording(.presented(.stopRecording))),
                        .run { send in
                            // Wait a moment for recording to stop, then dismiss
                            try? await clock.sleep(for: .milliseconds(100))
                            await send(.recording(.dismiss))
                        }
                    )
                }
                state.recording = nil
                return .send(.timeline(.loadSessions))
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$recording, action: \.recording) {
            RecordingFeature()
        }
    }
}

// MARK: - Helper Functions

extension AppFeature.State {
    /// Syncs the user profile to all features in the navigation path that need it.
    /// This ensures avatar displays are updated when the profile changes while in a child screen.
    mutating func syncUserProfileToPath(_ profile: UserProfile) {
        // Iterate using zip with ids to preserve element IDs during mutation
        for (id, element) in zip(path.ids, path) {
            switch element {
            case .sessionDetail:
                // SessionDetail no longer has avatar - no profile sync needed
                break
            case .profile(var profileState):
                profileState.profile = profile
                path[id: id] = .profile(profileState)
            case .personTimeline:
                // PersonTimeline uses settings icon, not avatar - no profile sync needed
                break
            case .people(var peopleState):
                // Sync profile to PeopleFeature so it can detect current user
                peopleState.userProfile = profile
                path[id: id] = .people(peopleState)
            }
        }
    }
}
