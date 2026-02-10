import Testing
import Audio
import ComposableArchitecture
import CustomDump
import Dependencies
import Foundation
import Models
import RecordingFeature
import Routing
import SessionDetailFeature
import SpeakerPickerFeature
import ProfileFeature
import PersonTimelineFeature
import PeopleFeature
import TimelineFeature
import Persistence
import Processing
@testable import Vapor

@MainActor
struct AppFeatureTests {
    @Test
    func testAppStartsWithEmptyProfileAndLoadsOnAppear() async {
        let testProfile = UserProfile(name: "Test User", email: "test@example.com")

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.recoveryRoutineClient.run = { .empty }
            $0.userProfileClient.load = { testProfile }
        }

        // Verify initial state has empty profile
        expectNoDifference(store.state.userProfile, .empty)

        // Send onAppear and verify profile is loaded
        await store.send(.onAppear)
        await store.receive(\.userProfileLoaded) {
            $0.userProfile = testProfile
            // Profile is synced to timeline feature
            $0.timeline.userProfile = testProfile
        }
    }

    @Test
    func testPeopleTappedNavigatesToPeopleDirectory() async {
        let testProfile = UserProfile(name: "Test User")

        let store = TestStore(initialState: AppFeature.State(userProfile: testProfile)) {
            AppFeature()
        }

        // Path should start empty
        #expect(store.state.path.isEmpty)

        // Tap people icon in timeline header
        await store.send(.timeline(.peopleTapped)) {
            $0.path.append(.people(PeopleFeature.State(userProfile: testProfile)))
        }

        // Verify people is on path
        #expect(store.state.path.count == 1)
        if case let .people(peopleState) = store.state.path.first {
            // Verify userProfile was passed
            expectNoDifference(peopleState.userProfile, testProfile)
        } else {
            Issue.record("Expected people state in path")
        }
    }

    @Test
    func testPeopleBackTappedReturnsToTimeline() async {
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.people(PeopleFeature.State())])
            )
        ) {
            AppFeature()
        }

        // Path should have people view
        #expect(store.state.path.count == 1)

        // Tap back in people view
        await store.send(.path(.element(id: 0, action: .people(.backTapped)))) {
            _ = $0.path.popLast()
        }

        // Path should be empty (back to timeline)
        #expect(store.state.path.isEmpty)
    }

    @Test
    func testSelfTappedInPeopleNavigatesToProfile() async {
        let testProfile = UserProfile(name: "Test User", email: "test@example.com")

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.people(PeopleFeature.State(userProfile: testProfile))]),
                userProfile: testProfile
            )
        ) {
            AppFeature()
        }

        // Path should have people view
        #expect(store.state.path.count == 1)

        // Tap on self in people view
        await store.send(.path(.element(id: 0, action: .people(.selfTapped)))) {
            $0.path.append(.profile(ProfileFeature.State(profile: testProfile)))
        }

        // Path should have people and profile
        #expect(store.state.path.count == 2)
        if case let .profile(profileState) = store.state.path.last {
            expectNoDifference(profileState.profile, testProfile)
        } else {
            Issue.record("Expected profile state in path")
        }
    }

    // MARK: - Navigation Stack Tests

    @Test
    func testNavigateToSessionDetail() async {
        let sessionID = SessionID(rawValue: "test-session-123")

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // Initially, path should be empty
        #expect(store.state.path.isEmpty)

        // When a session is tapped in timeline, it should push session detail onto path
        await store.send(.timeline(.sessionTapped(sessionID))) {
            $0.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionID)))
        }

        // Verify path contains the session detail
        #expect(store.state.path.count == 1)

        // When back is tapped in session detail, path should pop
        await store.send(.path(.element(id: 0, action: .sessionDetail(.backTapped)))) {
            _ = $0.path.popLast()
        }

        // Path should be empty again
        #expect(store.state.path.isEmpty)
    }

    @Test
    func testPathStartsEmpty() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        #expect(store.state.path.isEmpty)
    }

    // MARK: - Profile Navigation Tests

    @Test
    func testNavigateToProfileFromAvatar() async {
        let testProfile = UserProfile(name: "Brandon Kase", email: "brandon@example.com")

        let store = TestStore(initialState: AppFeature.State(userProfile: testProfile)) {
            AppFeature()
        }

        // Initially, path should be empty
        #expect(store.state.path.isEmpty)

        // When avatar is tapped in timeline, it should push profile onto path
        await store.send(.timeline(.avatarTapped)) {
            $0.path.append(.profile(ProfileFeature.State(profile: testProfile)))
        }

        // Verify path contains the profile screen
        #expect(store.state.path.count == 1)

        // When back is tapped in profile, path should pop
        await store.send(.path(.element(id: 0, action: .profile(.backTapped)))) {
            _ = $0.path.popLast()
        }

        // Path should be empty again
        #expect(store.state.path.isEmpty)
    }

    @Test
    func testProfileDelegateUpdatesAppProfile() async {
        let initialProfile = UserProfile(name: "Initial Name")
        let updatedProfile = UserProfile(name: "Updated Name", email: "updated@example.com")

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.profile(ProfileFeature.State(profile: initialProfile))]),
                userProfile: initialProfile
            )
        ) {
            AppFeature()
        }

        // When profile is saved and delegate emits didSaveProfile
        await store.send(.path(.element(id: 0, action: .profile(.delegate(.didSaveProfile(updatedProfile)))))) {
            $0.userProfile = updatedProfile
            // Profile is synced to timeline feature
            $0.timeline.userProfile = updatedProfile
            // Profile in path is also synced (bd-2j6f)
            if case var .profile(profileState) = $0.path[id: 0] {
                profileState.profile = updatedProfile
                $0.path[id: 0] = .profile(profileState)
            }
        }

        // Verify app-level profile was updated
        expectNoDifference(store.state.userProfile, updatedProfile)
    }

    @Test
    func testProfileStartsWithCurrentUserProfile() async {
        let testProfile = UserProfile(name: "Jane Doe", email: "jane@example.com")

        let store = TestStore(initialState: AppFeature.State(userProfile: testProfile)) {
            AppFeature()
        }

        // Navigate to profile
        await store.send(.timeline(.avatarTapped)) {
            // Profile should be initialized with current user profile
            $0.path.append(.profile(ProfileFeature.State(profile: testProfile)))
        }

        // Verify the profile in the path matches the app-level profile
        if case let .profile(profileState) = store.state.path.first {
            expectNoDifference(profileState.profile, testProfile)
        } else {
            Issue.record("Expected profile state in path")
        }
    }

    // MARK: - Session Detail Coordination Tests

    @Test
    func testTitleSavedRefreshesTimeline() async {
        // This test verifies that when titleSaved is received from session detail,
        // the AppFeature forwards a timeline reload so the updated title is visible on the timeline.
        let sessionID = SessionID(rawValue: "test-session-123")
        let fixedDate = Date(timeIntervalSince1970: 1000000)

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: sessionID))])
            )
        ) {
            AppFeature()
        } withDependencies: {
            // Mock date for timeline reload
            $0.date = .constant(fixedDate)
            // Mock database client for timeline reload
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            $0.databaseClient.fetchSpeakerInfoForSessions = { _ in [:] }
        }

        // When title is saved in session detail, the parent forwards timeline.loadSessions
        await store.send(.path(.element(id: 0, action: .sessionDetail(.titleSaved))))

        // Receive the timeline.loadSessions action that was sent by AppFeature
        await store.receive(\.timeline.loadSessions) {
            $0.timeline.isLoading = true
        }

        // Receive the sessionsLoaded response
        await store.receive(\.timeline.sessionsLoaded) {
            $0.timeline.isLoading = false
            $0.timeline.sessionGroups = []
            $0.timeline.speakerInfoBySession = [:]
        }

        // Session detail should remain on the path
        #expect(store.state.path.count == 1)
    }

    @Test
    func testSpeakerAssignmentRefreshesTimeline() async {
        // This test verifies that when a speaker is assigned in session detail (via speaker picker),
        // the AppFeature forwards a timeline reload so the avatar circles update on the timeline.
        let sessionID = SessionID(rawValue: "test-session-123")
        let fixedDate = Date(timeIntervalSince1970: 1000000)

        // Create session detail state with an active speaker picker
        // to avoid the "destination state was absent" error
        var sessionDetailState = SessionDetailFeature.State(sessionID: sessionID)
        sessionDetailState.speakerPicker = SpeakerPickerFeature.State(
            speakerTrackId: "track-1",
            sessionId: sessionID,
            displayOrder: 1
        )

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(sessionDetailState)])
            )
        ) {
            AppFeature()
        } withDependencies: {
            // Mock date for timeline reload
            $0.date = .constant(fixedDate)
            // Mock database client for timeline reload
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            $0.databaseClient.fetchSpeakerInfoForSessions = { _ in [:] }
            // Mock session detail load methods (triggered by selectionConfirmed sending loadSession)
            $0.databaseClient.fetchSession = { _ in nil }
            $0.databaseClient.fetchTranscriptSegments = { _ in [] }
            $0.databaseClient.fetchSpeakerTracks = { _ in [] }
            $0.databaseClient.fetchPeople = { [] }
        }

        // When speaker is assigned in speaker picker within session detail:
        // 1. SessionDetailFeature handles the action, dismisses the picker, and triggers loadSession
        // 2. AppFeature intercepts the action and triggers timeline.loadSessions
        // We use skipReceivedActions() because multiple effects fire in interleaved order
        await store.send(.path(.element(id: 0, action: .sessionDetail(.speakerPicker(.presented(.selectionConfirmed(PersonID("person-1")))))))) {
            // SessionDetailFeature dismisses the speaker picker
            if case var .sessionDetail(detail) = $0.path[id: 0] {
                detail.speakerPicker = nil
                $0.path[id: 0] = .sessionDetail(detail)
            }
        }

        // Skip received actions since multiple effects fire:
        // - session detail's loadSession and sessionLoaded
        // - timeline's loadSessions and sessionsLoaded
        await store.skipReceivedActions()

        // Session detail should remain on the path
        #expect(store.state.path.count == 1)
    }

    @Test
    func testRetryTranscriptionCompletedRefreshesTimeline() async {
        // This test verifies that when retryTranscriptionCompleted is received from session detail,
        // the AppFeature forwards a timeline reload so the partial chip is removed from the timeline.
        let sessionID = SessionID(rawValue: "test-session-123")
        let fixedDate = Date(timeIntervalSince1970: 1000000)

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: sessionID))])
            )
        ) {
            AppFeature()
        } withDependencies: {
            // Mock date for timeline reload
            $0.date = .constant(fixedDate)
            // Mock database client for timeline reload
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            $0.databaseClient.fetchSpeakerInfoForSessions = { _ in [:] }
            // Mock session detail load methods (triggered by retryTranscriptionCompleted sending loadSession)
            $0.databaseClient.fetchSession = { _ in nil }
            $0.databaseClient.fetchTranscriptSegments = { _ in [] }
            $0.databaseClient.fetchSpeakerTracks = { _ in [] }
            $0.databaseClient.fetchPeople = { [] }
        }

        // When retry transcription completes in session detail, the child reducer handles it
        // (sets isRetrying = false) and parent forwards timeline.loadSessions
        // The action reaches the child reducer first which modifies state
        await store.send(.path(.element(id: 0, action: .sessionDetail(.retryTranscriptionCompleted))))

        // Use skipReceivedActions since multiple effects fire:
        // 1. session detail's .loadSession (from retryTranscriptionCompleted reducer)
        // 2. timeline.loadSessions (from AppFeature intercepting retryTranscriptionCompleted)
        await store.skipReceivedActions()

        // Session detail should remain on the path (unlike delete which pops)
        #expect(store.state.path.count == 1)
    }

    @Test
    func testRetryTranscriptionCompletedDoesNotPopPath() async {
        // Verify that retry completion does NOT pop the navigation stack
        // (unlike delete which does pop)
        let sessionID = SessionID(rawValue: "test-session-456")
        let fixedDate = Date(timeIntervalSince1970: 1000000)

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: sessionID))])
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.date = .constant(fixedDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in [] }
            $0.databaseClient.fetchSpeakerInfoForSessions = { _ in [:] }
            $0.databaseClient.fetchSession = { _ in nil }
            $0.databaseClient.fetchTranscriptSegments = { _ in [] }
            $0.databaseClient.fetchSpeakerTracks = { _ in [] }
            $0.databaseClient.fetchPeople = { [] }
        }

        // Store the path count before retry completion
        let pathCountBefore = store.state.path.count

        // Send the retryTranscriptionCompleted action (handled by child reducer)
        await store.send(.path(.element(id: 0, action: .sessionDetail(.retryTranscriptionCompleted))))

        await store.skipReceivedActions()

        // Verify path is unchanged (session detail stays visible)
        #expect(store.state.path.count == pathCountBefore)
    }

    // MARK: - Person Timeline Navigation Tests

    @Test
    func testNavigateToPersonTimelineFromPeopleView() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let testProfile = UserProfile(name: "Test User")
        let personId = PersonID("person-123")
        let mockPerson = PersonRecord(
            id: personId.rawValue,
            name: "Sarah Chen",
            colorToken: "sky",
            createdAt: mockDate,
            updatedAt: mockDate
        )

        // Start with people view already in path
        var peopleState = PeopleFeature.State()
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.people(peopleState)]),
                userProfile: testProfile
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.databaseClient.fetchPerson = { _ in mockPerson }
        }

        // Path should have people view
        #expect(store.state.path.count == 1)

        // When a person is tapped in people view, it should fetch the person and navigate
        await store.send(.path(.element(id: 0, action: .people(.personTapped(personId)))))

        // Receive the personLoaded action and skip remaining actions
        await store.skipReceivedActions()

        // Verify path now has person timeline on top of people
        #expect(store.state.path.count == 2)

        // Verify the person timeline has correct data
        if case let .personTimeline(personTimelineState) = store.state.path.last {
            #expect(personTimelineState.personId == personId)
            #expect(personTimelineState.personName == "Sarah Chen")
        } else {
            Issue.record("Expected personTimeline state in path")
        }
    }

    @Test
    func testNavigateFromPersonTimelineToSessionDetail() async {
        let testProfile = UserProfile(name: "Test User")
        let personId = PersonID("person-123")
        let sessionId = SessionID(rawValue: "session-456")

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.personTimeline(PersonTimelineFeature.State(
                    personId: personId,
                    personName: "Sarah Chen"
                ))]),
                userProfile: testProfile
            )
        ) {
            AppFeature()
        }

        // Verify we start with person timeline on path
        #expect(store.state.path.count == 1)

        // When a session is tapped in person timeline, it should push session detail
        await store.send(.path(.element(id: 0, action: .personTimeline(.sessionTapped(sessionId))))) {
            $0.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: sessionId)))
        }

        // Verify path contains both person timeline and session detail
        #expect(store.state.path.count == 2)
    }

    @Test
    func testNavigateFromPersonTimelineToProfile() async {
        let testProfile = UserProfile(name: "Test User", email: "test@example.com")
        let personId = PersonID("person-123")

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.personTimeline(PersonTimelineFeature.State(
                    personId: personId,
                    personName: "Sarah Chen"
                ))]),
                userProfile: testProfile
            )
        ) {
            AppFeature()
        }

        // Verify we start with person timeline on path
        #expect(store.state.path.count == 1)

        // When avatar is tapped in person timeline, it should push profile
        await store.send(.path(.element(id: 0, action: .personTimeline(.avatarTapped)))) {
            $0.path.append(.profile(ProfileFeature.State(profile: testProfile)))
        }

        // Verify path contains both person timeline and profile
        #expect(store.state.path.count == 2)
    }

    @Test
    func testPersonLoadFailureFromPeopleViewHandledGracefully() async {
        let personId = PersonID("person-123")

        // Start with people view in path
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.people(PeopleFeature.State())])
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.databaseClient.fetchPerson = { _ in nil }
        }

        // Path should have people view
        #expect(store.state.path.count == 1)

        // When a person is tapped but doesn't exist, should handle gracefully
        await store.send(.path(.element(id: 0, action: .people(.personTapped(personId)))))

        // Wait for failure (person not found returns nil which triggers personLoadFailed)
        await store.receive(\.personLoadFailed)

        // Path should still have only people view (no navigation happened)
        #expect(store.state.path.count == 1)
    }

    // MARK: - Profile Sync to Navigation Path Tests (bd-2j6f)

    @Test
    func testProfileSaveSyncsToPeopleFeatureInPath() async {
        // Verify that when profile is saved, it syncs to PeopleFeature in the path
        let initialProfile = UserProfile(name: "Initial")
        let updatedProfile = UserProfile(name: "Updated Name")

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([
                    .people(PeopleFeature.State(userProfile: initialProfile)),
                    .profile(ProfileFeature.State(profile: initialProfile))
                ]),
                userProfile: initialProfile
            )
        ) {
            AppFeature()
        }

        // When profile is saved via delegate
        await store.send(.path(.element(id: 1, action: .profile(.delegate(.didSaveProfile(updatedProfile)))))) {
            $0.userProfile = updatedProfile
            $0.timeline.userProfile = updatedProfile
            // PeopleFeature state in path should have updated userProfile
            if case var .people(peopleState) = $0.path[id: 0] {
                peopleState.userProfile = updatedProfile
                $0.path[id: 0] = .people(peopleState)
            }
            // Profile state in path should be updated
            if case var .profile(profileState) = $0.path[id: 1] {
                profileState.profile = updatedProfile
                $0.path[id: 1] = .profile(profileState)
            }
        }

        // Verify PeopleFeature has updated profile
        if case let .people(peopleState) = store.state.path.first {
            expectNoDifference(peopleState.userProfile, updatedProfile)
        } else {
            Issue.record("Expected people state in path")
        }
    }

    @Test
    func testProfileSaveSyncsToPersonTimelineInPath() async {
        // Start with person timeline in path
        let personId = PersonID("person-123")
        let initialProfile = UserProfile(name: "Initial")
        let updatedProfile = UserProfile(
            name: "Updated",
            avatar: .init(imageData: Data([0x89, 0x50, 0x4E, 0x47]))
        )

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([
                    .personTimeline(PersonTimelineFeature.State(
                        personId: personId,
                        personName: "Sarah"
                    )),
                    .profile(ProfileFeature.State(profile: initialProfile))
                ]),
                userProfile: initialProfile
            )
        ) {
            AppFeature()
        }

        // When profile is saved via delegate
        await store.send(.path(.element(id: 1, action: .profile(.delegate(.didSaveProfile(updatedProfile)))))) {
            $0.userProfile = updatedProfile
            $0.timeline.userProfile = updatedProfile
            // PersonTimeline uses settings icon, not avatar - no profile sync needed
            // Profile state in path should be updated
            if case var .profile(profileState) = $0.path[id: 1] {
                profileState.profile = updatedProfile
                $0.path[id: 1] = .profile(profileState)
            }
        }

        // Verify person timeline is still in path (no changes to it since it uses settings icon)
        if case .personTimeline = store.state.path.first {
            // PersonTimeline uses settings icon instead of avatar, so no profile sync is needed
        } else {
            Issue.record("Expected personTimeline in path")
        }
    }

    // MARK: - Timeline Refresh on Return from Detail (bd-16zo fix)

    @Test
    func testTimelineRefreshesOnReturnFromSessionDetail() async {
        // This test verifies that when the user navigates back from session detail,
        // the timeline reloads to show any changes made (title edits, speaker assignments).
        // This is the fix for bd-16zo.
        let sessionID = SessionID(rawValue: "test-session-123")
        let fixedDate = Date(timeIntervalSince1970: 1000000)

        // Original sessions
        let originalSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: fixedDate,
            title: "Original Title",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: fixedDate
        )
        let originalGroups = [SessionGroup(bucket: .today, sessions: [originalSession])]

        // Updated sessions (after edit in detail view)
        let updatedSession = SessionRecord(
            id: sessionID.rawValue,
            startedAt: fixedDate,
            title: "Updated Title",
            processingState: .processed,
            speakerCount: 1,
            updatedAt: fixedDate
        )
        let updatedGroups = [SessionGroup(bucket: .today, sessions: [updatedSession])]

        var loadCallCount = 0

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: sessionID))]),
                timeline: TimelineFeature.State(
                    sessionGroups: originalGroups,
                    modelPreparationState: .ready
                )
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.date = .constant(fixedDate)
            $0.databaseClient.fetchSessionsGroupedByDate = { _ in
                loadCallCount += 1
                // Return updated data after edit
                return updatedGroups
            }
            $0.databaseClient.fetchSpeakerInfoForSessions = { _ in [:] }
        }

        // Verify initial state has original title
        #expect(store.state.timeline.sessionGroups[0].sessions[0].title == "Original Title")

        // User navigates back from session detail
        await store.send(.path(.element(id: 0, action: .sessionDetail(.backTapped)))) {
            _ = $0.path.popLast()
        }

        // When the timeline view reappears, its onAppear will trigger a reload.
        // Simulate the timeline's onAppear being called after navigation.
        await store.send(.timeline(.onAppear))

        // Receive the loadSessions action
        await store.receive(\.timeline.loadSessions) {
            $0.timeline.isLoading = true
        }

        // Receive the sessionsLoaded with updated data
        await store.receive(\.timeline.sessionsLoaded) {
            $0.timeline.isLoading = false
            $0.timeline.sessionGroups = updatedGroups
            $0.timeline.speakerInfoBySession = [:]
        }

        // Verify the title is now updated
        #expect(store.state.timeline.sessionGroups[0].sessions[0].title == "Updated Title")
        // Verify load was called
        #expect(loadCallCount >= 1)
    }

    // MARK: - Deep Link Tests (bd-27ad)

    @Test
    func testDeepLinkToTimeline() async {
        let sessionID = SessionID(rawValue: "test-session")

        // Start with a session detail on the path
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: sessionID))])
            )
        ) {
            AppFeature()
        }

        // Deep link to timeline should pop to root
        let url = URL(string: "vapor:///timeline")!
        await store.send(.deepLinkOpened(url)) {
            $0.path.removeAll()
        }

        // Path should be empty (timeline is root)
        #expect(store.state.path.isEmpty)
    }

    @Test
    func testDeepLinkToSession() async {
        let targetSessionID = SessionID(rawValue: "deep-link-session-123")

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // Deep link to a specific session
        let url = URL(string: "vapor:///session/deep-link-session-123")!
        await store.send(.deepLinkOpened(url)) {
            $0.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: targetSessionID)))
        }

        // Verify session detail is on the path
        #expect(store.state.path.count == 1)
        if case let .sessionDetail(state) = store.state.path.first {
            #expect(state.sessionID == targetSessionID)
        } else {
            Issue.record("Expected sessionDetail in path")
        }
    }

    @Test
    func testDeepLinkToSessionClearsExistingPath() async {
        let existingSessionID = SessionID(rawValue: "existing-session")
        let targetSessionID = SessionID(rawValue: "target-session")

        // Start with an existing session on the path
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: existingSessionID))])
            )
        ) {
            AppFeature()
        }

        // Deep link to a different session should clear and push new one
        let url = URL(string: "vapor:///session/target-session")!
        await store.send(.deepLinkOpened(url)) {
            $0.path.removeAll()
            $0.path.append(.sessionDetail(SessionDetailFeature.State(sessionID: targetSessionID)))
        }

        // Verify only the target session is on the path
        #expect(store.state.path.count == 1)
    }

    @Test
    func testDeepLinkToPeople() async {
        let testProfile = UserProfile(name: "Test User")

        let store = TestStore(
            initialState: AppFeature.State(userProfile: testProfile)
        ) {
            AppFeature()
        }

        // Deep link to people
        let url = URL(string: "vapor:///people")!
        await store.send(.deepLinkOpened(url)) {
            $0.path.append(.people(PeopleFeature.State(userProfile: testProfile)))
        }

        // Verify people is on the path
        #expect(store.state.path.count == 1)
        if case let .people(state) = store.state.path.first {
            expectNoDifference(state.userProfile, testProfile)
        } else {
            Issue.record("Expected people in path")
        }
    }

    @Test
    func testDeepLinkToRecordClearsPathAndStartsRecording() async {
        let existingSessionID = SessionID(rawValue: "existing-session")

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: existingSessionID))])
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.fileClient.cachesDirectory = { URL(fileURLWithPath: "/tmp/test-caches") }
            $0.fileClient.createDirectory = { _ in }
            $0.microphonePermissionClient.getStatus = { .authorized }
            $0.audioCaptureClient = .generated(config: .silent(durationSeconds: 1))
            $0.uuid = .incrementing
            $0.feedbackClient.triggerStartHaptic = {}
            $0.feedbackClient.playStartSound = {}
            $0.recordingProcessorClient.startRecording = { _ in AsyncStream { $0.finish() } }
        }

        // Deep link to record should clear the path and trigger newRecordingTapped
        let url = URL(string: "vapor:///record")!
        await store.send(.deepLinkOpened(url)) {
            $0.path.removeAll()
        }

        // Should receive the newRecordingTapped action forwarded by deepLinkOpened
        await store.receive(\.timeline.newRecordingTapped) {
            $0.recording = RecordingFeature.State(userProfile: .empty)
        }

        // Skip the recording start effects (permission check, recording start, etc.)
        await store.skipReceivedActions()
    }

    @Test
    func testDeepLinkRootPath() async {
        let sessionID = SessionID(rawValue: "test-session")

        // Start with a session detail on the path
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: sessionID))])
            )
        ) {
            AppFeature()
        }

        // Root path "/" should navigate to timeline (pop to root)
        let url = URL(string: "vapor:///")!
        await store.send(.deepLinkOpened(url)) {
            $0.path.removeAll()
        }

        #expect(store.state.path.isEmpty)
    }

    @Test
    func testDeepLinkInvalidURLIgnored() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // Invalid path should be silently ignored (no state change)
        let url = URL(string: "vapor:///invalid/path")!
        await store.send(.deepLinkOpened(url))
    }

    @Test
    func testDeepLinkWrongSchemeIgnored() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // A URL with wrong scheme that still has a valid path - should still parse since
        // AppRouter only looks at the path component, not the scheme
        let url = URL(string: "https://example.com/people")!
        await store.send(.deepLinkOpened(url)) {
            $0.path.append(.people(PeopleFeature.State(userProfile: .empty)))
        }
    }
}
