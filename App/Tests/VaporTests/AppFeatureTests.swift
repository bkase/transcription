import Testing
import ComposableArchitecture
import Dependencies
import Models
import SessionDetailFeature
import ProfileFeature
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
}
