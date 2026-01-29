import Testing
import ComposableArchitecture
import Dependencies
import Foundation
import Models
import SessionDetailFeature
import SpeakerPickerFeature
import ProfileFeature
import PersonTimelineFeature
import TimelineFeature
import Persistence
import Processing
@testable import Vapor

@MainActor
struct AppFeatureTests {
    @Test
    func testAppStartsOnTimelineAndLoadsProfile() async {
        let testProfile = UserProfile(name: "Test User", email: "test@example.com")

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.recoveryRoutineClient.run = { .empty }
            $0.userProfileClient.load = { testProfile }
        }

        // Verify initial state is on timeline tab with empty profile
        #expect(store.state.currentTab == .timeline)
        #expect(store.state.userProfile == .empty)

        // Send onAppear and verify profile is loaded
        await store.send(.onAppear)
        await store.receive(\.userProfileLoaded) {
            $0.userProfile = testProfile
            // Profile is synced to child features
            $0.timeline.userProfile = testProfile
            $0.people.userProfile = testProfile
        }

        // State should still be on timeline
        #expect(store.state.currentTab == .timeline)
    }

    @Test
    func testTabSelection() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // Start on timeline
        #expect(store.state.currentTab == .timeline)

        // Select people tab
        await store.send(.tabSelected(.people)) {
            $0.currentTab = .people
        }

        // Select timeline tab again
        await store.send(.tabSelected(.timeline)) {
            $0.currentTab = .timeline
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
            // Profile is synced to child features
            $0.timeline.userProfile = updatedProfile
            $0.people.userProfile = updatedProfile
            // Profile in path is also synced (bd-2j6f)
            if case var .profile(profileState) = $0.path[id: 0] {
                profileState.profile = updatedProfile
                $0.path[id: 0] = .profile(profileState)
            }
        }

        // Verify app-level profile was updated
        #expect(store.state.userProfile == updatedProfile)
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
            #expect(profileState.profile == testProfile)
        } else {
            Issue.record("Expected profile state in path")
        }
    }

    @Test
    func testNavigateToProfileFromPeopleTab() async {
        let testProfile = UserProfile(name: "Brandon Kase", email: "brandon@example.com")

        let store = TestStore(initialState: AppFeature.State(currentTab: .people, userProfile: testProfile)) {
            AppFeature()
        }

        // Initially, path should be empty
        #expect(store.state.path.isEmpty)

        // When avatar is tapped in people view, it should push profile onto path
        await store.send(.people(.avatarTapped)) {
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
    func testNavigateToPersonTimeline() async {
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

        let store = TestStore(
            initialState: AppFeature.State(currentTab: .people, userProfile: testProfile)
        ) {
            AppFeature()
        } withDependencies: {
            $0.databaseClient.fetchPerson = { _ in mockPerson }
        }

        // Initially, path should be empty
        #expect(store.state.path.isEmpty)

        // When a person is tapped in people view, it should fetch the person and navigate
        await store.send(.people(.personTapped(personId)))

        // Wait for personLoaded action to be received
        await store.skipReceivedActions()

        // Verify path contains the person timeline screen
        #expect(store.state.path.count == 1)

        // Verify the person timeline has correct data
        if case let .personTimeline(personTimelineState) = store.state.path.first {
            #expect(personTimelineState.personId == personId)
            #expect(personTimelineState.personName == "Sarah Chen")
        } else {
            Issue.record("Expected personTimeline state in path")
        }

        // When back is tapped in person timeline, path should pop
        await store.send(.path(.element(id: 0, action: .personTimeline(.backTapped)))) {
            _ = $0.path.popLast()
        }

        // Path should be empty again
        #expect(store.state.path.isEmpty)
    }

    @Test
    func testNavigateFromPersonTimelineToSessionDetail() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let testProfile = UserProfile(name: "Test User")
        let personId = PersonID("person-123")
        let sessionId = SessionID(rawValue: "session-456")

        let store = TestStore(
            initialState: AppFeature.State(
                currentTab: .people,
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
            $0.path.append(.sessionDetail(SessionDetailFeature.State(
                sessionID: sessionId,
                userProfile: testProfile
            )))
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
                currentTab: .people,
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
    func testPersonLoadFailureHandledGracefully() async {
        let personId = PersonID("person-123")

        let store = TestStore(
            initialState: AppFeature.State(currentTab: .people)
        ) {
            AppFeature()
        } withDependencies: {
            $0.databaseClient.fetchPerson = { _ in nil }
        }

        // Initially, path should be empty
        #expect(store.state.path.isEmpty)

        // When a person is tapped but doesn't exist, should handle gracefully
        await store.send(.people(.personTapped(personId)))

        // Wait for failure
        await store.receive(\.personLoadFailed)

        // Path should still be empty (no navigation happened)
        #expect(store.state.path.isEmpty)
    }

    // MARK: - Profile Sync to Navigation Path Tests (bd-2j6f)

    @Test
    func testUserProfileLoadedSyncsToSessionDetailInPath() async {
        // Start with session detail already in path with empty profile
        let sessionID = SessionID(rawValue: "test-session-123")
        let loadedProfile = UserProfile(
            name: "Jane Doe",
            email: "jane@example.com",
            avatar: .init(imageData: Data([0x89, 0x50, 0x4E, 0x47])) // PNG header bytes
        )

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([.sessionDetail(SessionDetailFeature.State(sessionID: sessionID))]),
                userProfile: .empty
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.recoveryRoutineClient.run = { .empty }
            $0.userProfileClient.load = { loadedProfile }
        }

        // Verify session detail starts with empty profile
        if case let .sessionDetail(detail) = store.state.path.first {
            #expect(detail.userProfile == .empty)
        }

        // When profile is loaded on app start
        await store.send(.onAppear)
        await store.receive(\.userProfileLoaded) {
            $0.userProfile = loadedProfile
            $0.timeline.userProfile = loadedProfile
            $0.people.userProfile = loadedProfile
            // Session detail in path should also be updated
            if case var .sessionDetail(detail) = $0.path[id: 0] {
                detail.userProfile = loadedProfile
                $0.path[id: 0] = .sessionDetail(detail)
            }
        }

        // Verify session detail now has the loaded profile
        if case let .sessionDetail(detail) = store.state.path.first {
            #expect(detail.userProfile == loadedProfile)
            #expect(detail.userProfile.avatar.imageData != nil)
        } else {
            Issue.record("Expected sessionDetail in path")
        }
    }

    @Test
    func testProfileSaveSyncsToSessionDetailInPath() async {
        // Start with session detail in path while profile is also in path
        let sessionID = SessionID(rawValue: "test-session-123")
        let initialProfile = UserProfile(name: "Initial")
        let updatedProfile = UserProfile(
            name: "Updated",
            avatar: .init(imageData: Data([0x89, 0x50, 0x4E, 0x47]))
        )

        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([
                    .sessionDetail(SessionDetailFeature.State(
                        sessionID: sessionID,
                        userProfile: initialProfile
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
            $0.people.userProfile = updatedProfile
            // Session detail in path should also be updated
            if case var .sessionDetail(detail) = $0.path[id: 0] {
                detail.userProfile = updatedProfile
                $0.path[id: 0] = .sessionDetail(detail)
            }
            // Profile state in path should also be updated
            if case var .profile(profileState) = $0.path[id: 1] {
                profileState.profile = updatedProfile
                $0.path[id: 1] = .profile(profileState)
            }
        }

        // Verify session detail has updated profile
        if case let .sessionDetail(detail) = store.state.path.first {
            #expect(detail.userProfile == updatedProfile)
            #expect(detail.userProfile.name == "Updated")
        } else {
            Issue.record("Expected sessionDetail in path")
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
            $0.people.userProfile = updatedProfile
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
}
