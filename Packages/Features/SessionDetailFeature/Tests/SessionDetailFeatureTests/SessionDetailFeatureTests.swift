import Testing
import Foundation
import ComposableArchitecture
import DesignSystem
import Models
import Persistence
import Processing
import AudioPlayerFeature
import SpeakerPickerFeature
@testable import SessionDetailFeature

// Actor for thread-safe capture of DB operations in tests
private actor CapturedTrackState {
    var createdTrack: SpeakerTrackRecord?
    var updatedSegment: TranscriptSegmentRecord?

    func setCreatedTrack(_ track: SpeakerTrackRecord) {
        createdTrack = track
    }

    func setUpdatedSegment(_ segment: TranscriptSegmentRecord) {
        updatedSegment = segment
    }
}

@MainActor
struct SessionDetailFeatureTests {

    // MARK: - testLoadSegments

    @Test
    func testLoadSegments() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Team Meeting",
            previewText: "Let's discuss the project",
            durationMs: 300000,
            audioPath: "/audio/session-123.caf",
            processingState: .processed,
            speakerCount: 2,
            updatedAt: mockDate
        )

        let mockSegmentRecords = [
            TranscriptSegmentRecord(
                id: "seg-1",
                sessionId: sessionID.rawValue,
                startMs: 0,
                endMs: 5000,
                machineSpeakerId: "spk_0",
                text: "Hello everyone, let's get started.",
                confidence: 0.95,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            TranscriptSegmentRecord(
                id: "seg-2",
                sessionId: sessionID.rawValue,
                startMs: 5000,
                endMs: 10000,
                machineSpeakerId: "spk_1",
                text: "Thanks for setting this up.",
                confidence: 0.92,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            TranscriptSegmentRecord(
                id: "seg-3",
                sessionId: sessionID.rawValue,
                startMs: 10000,
                endMs: 15000,
                machineSpeakerId: "spk_0",
                text: "First topic is the new feature.",
                confidence: 0.89,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let mockSpeakerTracks = [
            SpeakerTrackRecord(
                id: "track-1",
                sessionId: sessionID.rawValue,
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: "person-1"
            ),
            SpeakerTrackRecord(
                id: "track-2",
                sessionId: sessionID.rawValue,
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personId: nil
            )
        ]

        let mockPeople = [
            PersonRecord(
                id: "person-1",
                name: "Alice",
                colorToken: "sky",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.fetchSession = { id in
                #expect(id == sessionID)
                return mockSession
            }
            $0.databaseClient.fetchTranscriptSegments = { id in
                #expect(id == sessionID)
                return mockSegmentRecords
            }
            $0.databaseClient.fetchSpeakerTracks = { id in
                #expect(id == sessionID)
                return mockSpeakerTracks
            }
            $0.databaseClient.fetchPeople = {
                return mockPeople
            }
        }

        // onAppear triggers loadSession
        await store.send(.onAppear)

        // loadSession is sent
        await store.receive(\.loadSession) {
            $0.isLoading = true
        }

        // Data is loaded
        // Speaker 1 (spk_0) is assigned to Alice, Speaker 2 (spk_1) is unassigned
        let expectedSegments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello everyone, let's get started.",
                speakerType: .speaker(name: "Alice", color: SpeakerColor.forIndex(0).color)
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_1",
                startMs: 5000,
                endMs: 10000,
                text: "Thanks for setting this up.",
                speakerType: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color)
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_0",
                startMs: 10000,
                endMs: 15000,
                text: "First topic is the new feature.",
                speakerType: .speaker(name: "Alice", color: SpeakerColor.forIndex(0).color)
            )
        ]

        let expectedTracks = [
            DetailSpeakerTrack(
                id: "track-1",
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: "person-1",
                personName: "Alice"
            ),
            DetailSpeakerTrack(
                id: "track-2",
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personId: nil,
                personName: nil
            )
        ]

        await store.receive(\.sessionLoaded) {
            $0.isLoading = false
            $0.session = mockSession
            $0.segments = expectedSegments
            $0.speakerTracks = expectedTracks
            // Audio player initialized from session's audioPath and durationMs
            $0.audioPlayer = AudioPlayerFeature.State(
                audioURL: URL(fileURLWithPath: "/audio/session-123.caf"),
                duration: 300.0  // 300000ms = 300s
            )
        }

        // Verify final state
        #expect(store.state.segments.count == 3)
        #expect(store.state.speakerTracks.count == 2)
        #expect(store.state.speakerTracks[0].personName == "Alice")
        #expect(store.state.speakerTracks[1].personName == nil)
    }

    // MARK: - testLoadSessionNotFound

    @Test
    func testLoadSessionNotFound() async {
        let sessionID = SessionID("non-existent")

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.fetchSession = { _ in nil }
            $0.databaseClient.fetchTranscriptSegments = { _ in [] }
            $0.databaseClient.fetchSpeakerTracks = { _ in [] }
            $0.databaseClient.fetchPeople = { [] }
        }

        await store.send(.loadSession) {
            $0.isLoading = true
        }

        await store.receive(\.sessionLoaded) {
            $0.isLoading = false
            $0.session = nil
            $0.segments = []
            $0.speakerTracks = []
        }
    }

    // MARK: - testLoadError

    @Test
    func testLoadError() async {
        let sessionID = SessionID("session-123")

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database error" }
        }

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.fetchSession = { _ in
                throw TestError()
            }
            // Mock remaining methods to avoid "unimplemented" errors
            // They won't actually be called since fetchSession throws first
            $0.databaseClient.fetchTranscriptSegments = { _ in [] }
            $0.databaseClient.fetchSpeakerTracks = { _ in [] }
            $0.databaseClient.fetchPeople = { [] }
        }

        await store.send(.loadSession) {
            $0.isLoading = true
        }

        await store.receive(\.loadFailed) {
            $0.isLoading = false
            $0.error = "Database error"
        }
    }

    // MARK: - testOnAppearDoesNotReloadIfAlreadyLoaded

    @Test
    func testOnAppearDoesNotReloadIfAlreadyLoaded() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")

        let existingSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: nil,
            title: "Existing",
            previewText: nil,
            durationMs: nil,
            audioPath: nil,
            processingState: .processed,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: existingSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            // Should never be called since session already loaded
            $0.databaseClient.fetchSession = { _ in
                Issue.record("Should not reload when session already exists")
                return nil
            }
        }

        // onAppear should not trigger reload when session already exists
        await store.send(.onAppear)
    }

    // MARK: - testBackTappedIsNavigationIntent

    @Test
    func testBackTappedIsNavigationIntent() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        }

        // backTapped is a navigation intent - no state change expected
        await store.send(.backTapped)
    }

    // MARK: - testOnAppearDoesNotReloadIfLoading

    @Test
    func testOnAppearDoesNotReloadIfLoading() async {
        let sessionID = SessionID("session-123")

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                isLoading: true
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            // Should never be called since already loading
            $0.databaseClient.fetchSession = { _ in
                Issue.record("Should not reload when already loading")
                return nil
            }
        }

        // onAppear should not trigger another load when already loading
        await store.send(.onAppear)
    }

    // MARK: - testRetryTranscriptionSuccess

    @Test
    func testRetryTranscriptionSuccess() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")

        let failedSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Failed Recording",
            previewText: nil,
            durationMs: 300000,
            audioPath: "/audio/session-123.caf",
            processingState: .failed,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let processedSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Failed Recording",
            previewText: "Now transcribed",
            durationMs: 300000,
            audioPath: "/audio/session-123.caf",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let mockSegments = [
            TranscriptSegmentRecord(
                id: "seg-1",
                sessionId: sessionID.rawValue,
                startMs: 0,
                endMs: 5000,
                machineSpeakerId: "spk_0",
                text: "Hello world",
                confidence: 0.95,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        var retryWasCalled = false

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: failedSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.recordingProcessorClient.retryOfflineTranscription = { id in
                #expect(id == sessionID)
                retryWasCalled = true
                return true
            }
            $0.databaseClient.fetchSession = { _ in processedSession }
            $0.databaseClient.fetchTranscriptSegments = { _ in mockSegments }
            $0.databaseClient.fetchSpeakerTracks = { _ in [] }
            $0.databaseClient.fetchPeople = { [] }
        }

        await store.send(.retryTranscriptionTapped) {
            $0.isRetrying = true
            $0.error = nil
        }

        await store.receive(\.retryTranscriptionCompleted) {
            $0.isRetrying = false
        }

        // loadSession is triggered after retry completes
        await store.receive(\.loadSession) {
            $0.isLoading = true
        }

        await store.receive(\.sessionLoaded) {
            $0.isLoading = false
            $0.session = processedSession
            // No speaker tracks, so speaker type defaults to unassigned Speaker 1
            $0.segments = [
                DetailSegment(
                    id: TranscriptSegmentID("seg-1"),
                    machineSpeakerId: "spk_0",
                    startMs: 0,
                    endMs: 5000,
                    text: "Hello world",
                    speakerType: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
                )
            ]
            $0.speakerTracks = []
            $0.audioPlayer = AudioPlayerFeature.State(
                audioURL: URL(fileURLWithPath: "/audio/session-123.caf"),
                duration: 300.0
            )
        }

        #expect(retryWasCalled)
    }

    // MARK: - testRetryTranscriptionFailure

    @Test
    func testRetryTranscriptionFailure() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")

        let failedSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Failed Recording",
            previewText: nil,
            durationMs: 300000,
            audioPath: "/audio/session-123.caf",
            processingState: .failed,
            speakerCount: 0,
            updatedAt: mockDate
        )

        struct RetryError: Error, LocalizedError {
            var errorDescription: String? { "Transcription engine unavailable" }
        }

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: failedSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.recordingProcessorClient.retryOfflineTranscription = { _ in
                throw RetryError()
            }
        }

        await store.send(.retryTranscriptionTapped) {
            $0.isRetrying = true
            $0.error = nil
        }

        await store.receive(\.retryTranscriptionFailed) {
            $0.isRetrying = false
            $0.error = "Transcription engine unavailable"
        }
    }

    // MARK: - testRetryTranscriptionNotAllowedWhenProcessed

    @Test
    func testRetryTranscriptionNotAllowedWhenProcessed() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")

        let processedSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Processed Recording",
            previewText: "Already transcribed",
            durationMs: 300000,
            audioPath: "/audio/session-123.caf",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: processedSession
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.recordingProcessorClient.retryOfflineTranscription = { _ in
                Issue.record("Should not call retry for processed session")
                return false
            }
        }

        // Retry should be ignored for processed sessions
        await store.send(.retryTranscriptionTapped)
    }

    // MARK: - testRetryTranscriptionNotAllowedWhenAlreadyRetrying

    @Test
    func testRetryTranscriptionNotAllowedWhenAlreadyRetrying() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")

        let failedSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Failed Recording",
            previewText: nil,
            durationMs: 300000,
            audioPath: "/audio/session-123.caf",
            processingState: .failed,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: failedSession,
                isRetrying: true
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.recordingProcessorClient.retryOfflineTranscription = { _ in
                Issue.record("Should not call retry when already retrying")
                return false
            }
        }

        // Retry should be ignored when already retrying
        await store.send(.retryTranscriptionTapped)
    }

    // MARK: - testSpeakerAssignmentUpdatesAllSegments

    /// Regression test for bd-1z6l: Verifies that when a speaker is assigned,
    /// ALL segments with that machineSpeakerId get updated speakerType (not just first and last).
    @Test
    func testSpeakerAssignmentUpdatesAllSegments() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let sessionID = SessionID("session-123")

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Conversation",
            previewText: nil,
            durationMs: 300000,
            audioPath: nil,
            processingState: .processed,
            speakerCount: 2,
            updatedAt: mockDate
        )

        // 5 segments alternating between two speakers
        // Speaker 0 (spk_0): segments 1, 3, 5
        // Speaker 1 (spk_1): segments 2, 4
        let mockSegmentRecords = [
            TranscriptSegmentRecord(
                id: "seg-1",
                sessionId: sessionID.rawValue,
                startMs: 0,
                endMs: 5000,
                machineSpeakerId: "spk_0",
                text: "First from speaker 0",
                confidence: 0.95,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            TranscriptSegmentRecord(
                id: "seg-2",
                sessionId: sessionID.rawValue,
                startMs: 5000,
                endMs: 10000,
                machineSpeakerId: "spk_1",
                text: "First from speaker 1",
                confidence: 0.92,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            TranscriptSegmentRecord(
                id: "seg-3",
                sessionId: sessionID.rawValue,
                startMs: 10000,
                endMs: 15000,
                machineSpeakerId: "spk_0",
                text: "Second from speaker 0 (middle segment)",
                confidence: 0.91,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            TranscriptSegmentRecord(
                id: "seg-4",
                sessionId: sessionID.rawValue,
                startMs: 15000,
                endMs: 20000,
                machineSpeakerId: "spk_1",
                text: "Second from speaker 1",
                confidence: 0.93,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            ),
            TranscriptSegmentRecord(
                id: "seg-5",
                sessionId: sessionID.rawValue,
                startMs: 20000,
                endMs: 25000,
                machineSpeakerId: "spk_0",
                text: "Third from speaker 0 (last for this speaker)",
                confidence: 0.89,
                isFinal: true,
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        // Speaker tracks AFTER assignment - spk_0 is now assigned to "Alice"
        let mockSpeakerTracksAfterAssignment = [
            SpeakerTrackRecord(
                id: "track-1",
                sessionId: sessionID.rawValue,
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personId: "person-alice"
            ),
            SpeakerTrackRecord(
                id: "track-2",
                sessionId: sessionID.rawValue,
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personId: nil
            )
        ]

        let mockPeople = [
            PersonRecord(
                id: "person-alice",
                name: "Alice",
                colorToken: "sky",
                createdAt: mockDate,
                updatedAt: mockDate
            )
        ]

        let store = TestStore(initialState: SessionDetailFeature.State(sessionID: sessionID)) {
            SessionDetailFeature()
        } withDependencies: {
            $0.databaseClient.fetchSession = { _ in mockSession }
            $0.databaseClient.fetchTranscriptSegments = { _ in mockSegmentRecords }
            $0.databaseClient.fetchSpeakerTracks = { _ in mockSpeakerTracksAfterAssignment }
            $0.databaseClient.fetchPeople = { mockPeople }
        }

        await store.send(.loadSession) {
            $0.isLoading = true
        }

        // Expected: ALL segments with spk_0 should have speakerType = .speaker(name: "Alice", ...)
        // This is the key assertion for the bug fix - middle segments (seg-3) must also update
        let aliceSpeakerType = SpeakerType.speaker(name: "Alice", color: SpeakerColor.forIndex(0).color)
        let unassignedSpeaker2 = SpeakerType.unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color)

        await store.receive(\.sessionLoaded) {
            $0.isLoading = false
            $0.session = mockSession
            $0.speakerTracks = [
                DetailSpeakerTrack(
                    id: "track-1",
                    machineSpeakerId: "spk_0",
                    displayOrder: 1,
                    personId: "person-alice",
                    personName: "Alice"
                ),
                DetailSpeakerTrack(
                    id: "track-2",
                    machineSpeakerId: "spk_1",
                    displayOrder: 2,
                    personId: nil,
                    personName: nil
                )
            ]
            // Verify ALL segments for spk_0 have the correct speaker type (not just first and last)
            $0.segments = [
                DetailSegment(
                    id: TranscriptSegmentID("seg-1"),
                    machineSpeakerId: "spk_0",
                    startMs: 0,
                    endMs: 5000,
                    text: "First from speaker 0",
                    speakerType: aliceSpeakerType  // First segment - should be Alice
                ),
                DetailSegment(
                    id: TranscriptSegmentID("seg-2"),
                    machineSpeakerId: "spk_1",
                    startMs: 5000,
                    endMs: 10000,
                    text: "First from speaker 1",
                    speakerType: unassignedSpeaker2
                ),
                DetailSegment(
                    id: TranscriptSegmentID("seg-3"),
                    machineSpeakerId: "spk_0",
                    startMs: 10000,
                    endMs: 15000,
                    text: "Second from speaker 0 (middle segment)",
                    speakerType: aliceSpeakerType  // MIDDLE segment - must also be Alice (was the bug)
                ),
                DetailSegment(
                    id: TranscriptSegmentID("seg-4"),
                    machineSpeakerId: "spk_1",
                    startMs: 15000,
                    endMs: 20000,
                    text: "Second from speaker 1",
                    speakerType: unassignedSpeaker2
                ),
                DetailSegment(
                    id: TranscriptSegmentID("seg-5"),
                    machineSpeakerId: "spk_0",
                    startMs: 20000,
                    endMs: 25000,
                    text: "Third from speaker 0 (last for this speaker)",
                    speakerType: aliceSpeakerType  // Last segment - should be Alice
                )
            ]
        }

        // Additional verification: all segments for spk_0 have correct speakerType
        let spk0Segments = store.state.segments.filter { $0.machineSpeakerId == "spk_0" }
        #expect(spk0Segments.count == 3)
        for segment in spk0Segments {
            #expect(segment.speakerType == aliceSpeakerType, "All spk_0 segments should have Alice as speaker, but segment \(segment.id) did not")
        }
    }

    // MARK: - testSpeakerLabelTappedWithExistingTrack

    @Test
    func testSpeakerLabelTappedWithExistingTrack() async {
        let sessionID = SessionID("session-123")
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Test Session",
            previewText: nil,
            durationMs: 300000,
            audioPath: nil,
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let existingTrack = DetailSpeakerTrack(
            id: "track-1",
            machineSpeakerId: "spk_0",
            displayOrder: 1,
            personId: nil,
            personName: nil
        )

        let existingSegment = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0",
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            speakerType: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
        )

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession,
                segments: [existingSegment],
                speakerTracks: [existingTrack]
            )
        ) {
            SessionDetailFeature()
        }

        // Tap speaker label on segment with existing track
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0"
        )) {
            // Should open speaker picker modal with existing track info
            $0.speakerPicker = SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: sessionID,
                displayOrder: 1,
                currentPersonId: nil,
                userProfile: .empty
            )
        }
    }

    // MARK: - testSpeakerLabelTappedWithNilMachineSpeakerId

    /// Regression test for bd-3t9s: Verifies that tapping a speaker label on a segment
    /// with nil machineSpeakerId creates a new speaker track and opens the picker.
    @Test
    func testSpeakerLabelTappedWithNilMachineSpeakerId() async {
        let sessionID = SessionID("session-123")
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Test Session",
            previewText: nil,
            durationMs: 300000,
            audioPath: nil,
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        // Segment with nil machineSpeakerId (the bug case)
        let segmentWithNilSpeaker = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil,  // This is the key - nil speaker
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            speakerType: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
        )

        // The segment record in DB (with nil machineSpeakerId)
        let segmentRecord = TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: sessionID.rawValue,
            startMs: 0,
            endMs: 5000,
            machineSpeakerId: nil,
            text: "Hello",
            confidence: nil,
            isFinal: true,
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let testUUID1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let testUUID2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        // Use actor for thread-safe capture of mutable state
        let capturedState = CapturedTrackState()

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession,
                segments: [segmentWithNilSpeaker],
                speakerTracks: []  // No existing tracks
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            // Use deterministic UUIDs: first for machineSpeakerId, second for trackId
            var uuids = [testUUID1, testUUID2].makeIterator()
            $0.uuid = .init { uuids.next()! }
            $0.databaseClient.createSpeakerTrack = { record in
                await capturedState.setCreatedTrack(record)
            }
            $0.databaseClient.fetchTranscriptSegments = { _ in
                [segmentRecord]
            }
            $0.databaseClient.updateTranscriptSegment = { record in
                await capturedState.setUpdatedSegment(record)
            }
        }

        // Tap speaker label on segment with nil machineSpeakerId
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil
        ))

        // Should receive speakerTrackCreated with new track info
        await store.receive(\.speakerTrackCreated) {
            // Speaker picker modal should open with the new track
            $0.speakerPicker = SpeakerPickerFeature.State(
                speakerTrackId: testUUID2.uuidString,  // Second UUID is the track ID
                sessionId: sessionID,
                displayOrder: 1  // First speaker track
            )
        }

        // Verify the speaker track was created with correct data
        let createdTrack = await capturedState.createdTrack
        #expect(createdTrack != nil)
        #expect(createdTrack?.id == testUUID2.uuidString)
        #expect(createdTrack?.sessionId == sessionID.rawValue)
        #expect(createdTrack?.machineSpeakerId == testUUID1.uuidString)  // First UUID is the new machineSpeakerId
        #expect(createdTrack?.displayOrder == 1)

        // Verify the segment was updated with the new machineSpeakerId
        let updatedSeg = await capturedState.updatedSegment
        #expect(updatedSeg != nil)
        #expect(updatedSeg?.id == "seg-1")
        #expect(updatedSeg?.machineSpeakerId == testUUID1.uuidString)
    }

    // MARK: - testSpeakerLabelTappedWithNilMachineSpeakerIdError

    @Test
    func testSpeakerLabelTappedWithNilMachineSpeakerIdError() async {
        let sessionID = SessionID("session-123")
        let mockDate = Date(timeIntervalSince1970: 1000000)

        let mockSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(300),
            title: "Test Session",
            previewText: nil,
            durationMs: 300000,
            audioPath: nil,
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let segmentWithNilSpeaker = DetailSegment(
            id: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil,
            startMs: 0,
            endMs: 5000,
            text: "Hello",
            speakerType: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color)
        )

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Database error" }
        }

        let store = TestStore(
            initialState: SessionDetailFeature.State(
                sessionID: sessionID,
                session: mockSession,
                segments: [segmentWithNilSpeaker],
                speakerTracks: []
            )
        ) {
            SessionDetailFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.databaseClient.createSpeakerTrack = { _ in
                throw TestError()
            }
        }

        // Tap speaker label on segment with nil machineSpeakerId
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil
        ))

        // Should receive error
        await store.receive(\.speakerTrackCreationFailed) {
            $0.error = "Database error"
        }
    }
}
