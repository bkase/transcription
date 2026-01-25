import Testing
import Models
@testable import Routing

// Note: The AppFeature navigation stack integration tests are located in App/Tests/VaporTests/AppFeatureTests.swift
// because they require access to the AppFeature which imports all feature modules.
// This file contains routing-level tests that can run without the full app dependencies.

// MARK: - Navigation Route Tests

@Test func sessionRouteContainsSessionID() {
    let sessionID = SessionID(rawValue: "test-session-123")
    let route = AppRoute.session(sessionID)

    if case let .session(id) = route {
        #expect(id == sessionID)
    } else {
        Issue.record("Expected session route with ID")
    }
}

@Test func timelineRouteIsDefault() {
    let route = AppRoute.timeline
    #expect(route == .timeline)
}
