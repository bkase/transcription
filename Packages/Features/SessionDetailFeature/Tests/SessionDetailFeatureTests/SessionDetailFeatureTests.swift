import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import SessionDetailFeature

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
        let expectedSegments = [
            DetailSegment(
                id: TranscriptSegmentID("seg-1"),
                machineSpeakerId: "spk_0",
                startMs: 0,
                endMs: 5000,
                text: "Hello everyone, let's get started."
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-2"),
                machineSpeakerId: "spk_1",
                startMs: 5000,
                endMs: 10000,
                text: "Thanks for setting this up."
            ),
            DetailSegment(
                id: TranscriptSegmentID("seg-3"),
                machineSpeakerId: "spk_0",
                startMs: 10000,
                endMs: 15000,
                text: "First topic is the new feature."
            )
        ]

        let expectedTracks = [
            DetailSpeakerTrack(
                machineSpeakerId: "spk_0",
                displayOrder: 1,
                personName: "Alice"
            ),
            DetailSpeakerTrack(
                machineSpeakerId: "spk_1",
                displayOrder: 2,
                personName: nil
            )
        ]

        await store.receive(\.sessionLoaded) {
            $0.isLoading = false
            $0.session = mockSession
            $0.segments = expectedSegments
            $0.speakerTracks = expectedTracks
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
}
