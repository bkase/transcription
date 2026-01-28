import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
@testable import RecordingFeature
@testable import SpeakerPickerFeature

@MainActor
struct RecordingSpeakerPickerTests {

    // MARK: - speakerLabelTapped Tests

    @Test
    func testSpeakerLabelTappedWithNoMachineSpeakerIdDoesNothing() async {
        let store = TestStore(
            initialState: RecordingFeature.State(
                isRecording: true,
                sessionID: SessionID("test-session")
            )
        ) {
            RecordingFeature()
        }

        // Tap on a segment with no machineSpeakerId
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: nil
        ))

        // speakerPicker should remain nil
        #expect(store.state.speakerPicker == nil)
    }

    @Test
    func testSpeakerLabelTappedWithNoSessionIdDoesNothing() async {
        let store = TestStore(
            initialState: RecordingFeature.State(
                isRecording: true,
                sessionID: nil,
                speakerTracks: [
                    LiveSpeakerTrack(
                        id: "track-1",
                        machineSpeakerId: "spk_0",
                        displayOrder: 1,
                        personId: nil,
                        personName: nil
                    )
                ]
            )
        ) {
            RecordingFeature()
        }

        // Tap on a segment when there's no session ID
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0"
        ))

        // speakerPicker should remain nil
        #expect(store.state.speakerPicker == nil)
    }

    @Test
    func testSpeakerLabelTappedWithNoMatchingTrackDoesNothing() async {
        let store = TestStore(
            initialState: RecordingFeature.State(
                isRecording: true,
                sessionID: SessionID("test-session"),
                speakerTracks: [
                    LiveSpeakerTrack(
                        id: "track-1",
                        machineSpeakerId: "spk_0",
                        displayOrder: 1,
                        personId: nil,
                        personName: nil
                    )
                ]
            )
        ) {
            RecordingFeature()
        }

        // Tap on a segment with a different machineSpeakerId
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_unknown"
        ))

        // speakerPicker should remain nil
        #expect(store.state.speakerPicker == nil)
    }

    @Test
    func testSpeakerLabelTappedOpensSpeakerPicker() async {
        let sessionID = SessionID("test-session")
        let store = TestStore(
            initialState: RecordingFeature.State(
                isRecording: true,
                sessionID: sessionID,
                speakerTracks: [
                    LiveSpeakerTrack(
                        id: "track-1",
                        machineSpeakerId: "spk_0",
                        displayOrder: 1,
                        personId: nil,
                        personName: nil
                    )
                ]
            )
        ) {
            RecordingFeature()
        }

        // Tap on a segment with a valid machineSpeakerId
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0"
        )) {
            $0.speakerPicker = SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: sessionID,
                displayOrder: 1,
                currentPersonId: nil
            )
        }

        // Verify speaker picker is now presented
        #expect(store.state.speakerPicker != nil)
    }

    @Test
    func testSpeakerLabelTappedWithExistingPersonIdOpensSpeakerPicker() async {
        let sessionID = SessionID("test-session")
        let personId = "person-alice"
        let store = TestStore(
            initialState: RecordingFeature.State(
                isRecording: true,
                sessionID: sessionID,
                speakerTracks: [
                    LiveSpeakerTrack(
                        id: "track-1",
                        machineSpeakerId: "spk_0",
                        displayOrder: 1,
                        personId: personId,
                        personName: "Alice"
                    )
                ]
            )
        ) {
            RecordingFeature()
        }

        // Tap on a segment with a valid machineSpeakerId that has a person assigned
        await store.send(.speakerLabelTapped(
            segmentId: TranscriptSegmentID("seg-1"),
            machineSpeakerId: "spk_0"
        )) {
            $0.speakerPicker = SpeakerPickerFeature.State(
                speakerTrackId: "track-1",
                sessionId: sessionID,
                displayOrder: 1,
                currentPersonId: PersonID(personId)
            )
        }
    }

    @Test
    func testSpeakerPickerCloseModalDismissesPicker() async {
        let sessionID = SessionID("test-session")
        let store = TestStore(
            initialState: RecordingFeature.State(
                isRecording: true,
                sessionID: sessionID,
                speakerTracks: [
                    LiveSpeakerTrack(
                        id: "track-1",
                        machineSpeakerId: "spk_0",
                        displayOrder: 1,
                        personId: nil,
                        personName: nil
                    )
                ],
                speakerPicker: SpeakerPickerFeature.State(
                    speakerTrackId: "track-1",
                    sessionId: sessionID,
                    displayOrder: 1,
                    currentPersonId: nil
                )
            )
        ) {
            RecordingFeature()
        }

        // Close the speaker picker
        await store.send(.speakerPicker(.presented(.closeModal))) {
            $0.speakerPicker = nil
        }

        #expect(store.state.speakerPicker == nil)
    }

    @Test
    func testSpeakerPickerSelectionConfirmedReloadsTracks() async {
        let sessionID = SessionID("test-session")

        let store = TestStore(
            initialState: RecordingFeature.State(
                isRecording: true,
                sessionID: sessionID,
                liveSegments: [
                    LiveSegment(
                        id: TranscriptSegmentID("seg-1"),
                        machineSpeakerId: "spk_0",
                        startMs: 0,
                        endMs: 1000,
                        text: "Hello",
                        isFinal: true
                    )
                ],
                speakerTracks: [
                    LiveSpeakerTrack(
                        id: "track-1",
                        machineSpeakerId: "spk_0",
                        displayOrder: 1,
                        personId: nil,
                        personName: nil
                    )
                ],
                speakerPicker: SpeakerPickerFeature.State(
                    speakerTrackId: "track-1",
                    sessionId: sessionID,
                    displayOrder: 1,
                    currentPersonId: nil
                )
            )
        ) {
            RecordingFeature()
        } withDependencies: {
            $0.databaseClient.fetchSpeakerTracks = { _ in
                [
                    SpeakerTrackRecord(
                        id: "track-1",
                        sessionId: sessionID.rawValue,
                        machineSpeakerId: "spk_0",
                        displayOrder: 1,
                        personId: "person-alice"
                    )
                ]
            }
            $0.databaseClient.fetchPeople = {
                [
                    PersonRecord(
                        id: "person-alice",
                        name: "Alice",
                        colorToken: "sky",
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ]
            }
            $0.databaseClient.fetchTranscriptSegments = { _ in
                [
                    TranscriptSegmentRecord(
                        id: "seg-1",
                        sessionId: sessionID.rawValue,
                        startMs: 0,
                        endMs: 1000,
                        machineSpeakerId: "spk_0",
                        text: "Hello",
                        confidence: 0.95,
                        isFinal: true,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ]
            }
        }

        // Confirm selection - this should dismiss and reload
        let aliceId = PersonID("person-alice")
        await store.send(RecordingFeature.Action.speakerPicker(.presented(.selectionConfirmed(aliceId)))) {
            $0.speakerPicker = nil
        }

        // Should receive segmentsLoaded with updated speaker tracks
        await store.receive {
            guard case .segmentsLoaded = $0 else { return false }
            return true
        } assert: {
            $0.liveSegments = [
                LiveSegment(
                    id: TranscriptSegmentID("seg-1"),
                    machineSpeakerId: "spk_0",
                    startMs: 0,
                    endMs: 1000,
                    text: "Hello",
                    isFinal: true
                )
            ]
            $0.speakerTracks = [
                LiveSpeakerTrack(
                    id: "track-1",
                    machineSpeakerId: "spk_0",
                    displayOrder: 1,
                    personId: "person-alice",
                    personName: "Alice"
                )
            ]
        }
    }
}
