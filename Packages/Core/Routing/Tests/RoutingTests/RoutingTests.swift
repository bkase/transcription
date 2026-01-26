import Testing
import Models
import URLRouting
@testable import Routing

// MARK: - Equatable Tests

@Test func appRouteTimelineIsEquatable() {
    #expect(AppRoute.timeline == AppRoute.timeline)
}

@Test func appRouteSessionIsEquatable() {
    let id = SessionID(rawValue: "test-123")
    #expect(AppRoute.session(id) == AppRoute.session(id))
}

// MARK: - URL Parsing Tests

@Test func testParseTimelineRoot() throws {
    let router = AppRouter()
    let route = try router.parse(URLRequestData(path: "/"))
    #expect(route == .timeline)
}

@Test func testParseTimelineExplicit() throws {
    let router = AppRouter()
    let route = try router.parse(URLRequestData(path: "/timeline"))
    #expect(route == .timeline)
}

@Test func testParseSessionRoute() throws {
    let router = AppRouter()
    let route = try router.parse(URLRequestData(path: "/session/abc-123"))
    #expect(route == .session(SessionID(rawValue: "abc-123")))
}

@Test func testParsePeopleRoute() throws {
    let router = AppRouter()
    let route = try router.parse(URLRequestData(path: "/people"))
    #expect(route == .people)
}

@Test func testParseRecordRoute() throws {
    let router = AppRouter()
    let route = try router.parse(URLRequestData(path: "/record"))
    #expect(route == .record)
}

// MARK: - URL Printing Tests

@Test func testPrintTimeline() throws {
    let router = AppRouter()
    let request = try router.print(.timeline)
    let pathString = "/" + request.path.joined(separator: "/")
    // Timeline prints as root "/" since that's the canonical form (last matching route in OneOf)
    #expect(pathString == "/")
}

@Test func testPrintSession() throws {
    let router = AppRouter()
    let request = try router.print(.session(SessionID(rawValue: "xyz-789")))
    let pathString = "/" + request.path.joined(separator: "/")
    #expect(pathString == "/session/xyz-789")
}

@Test func testPrintPeople() throws {
    let router = AppRouter()
    let request = try router.print(.people)
    let pathString = "/" + request.path.joined(separator: "/")
    #expect(pathString == "/people")
}

@Test func testPrintRecord() throws {
    let router = AppRouter()
    let request = try router.print(.record)
    let pathString = "/" + request.path.joined(separator: "/")
    #expect(pathString == "/record")
}

// MARK: - Roundtrip Tests

@Test func testRoundtripTimeline() throws {
    let router = AppRouter()
    let original = AppRoute.timeline
    let printed = try router.print(original)
    let parsed = try router.parse(printed)
    #expect(parsed == original)
}

@Test func testRoundtripSession() throws {
    let router = AppRouter()
    let original = AppRoute.session(SessionID(rawValue: "session-uuid-test"))
    let printed = try router.print(original)
    let parsed = try router.parse(printed)
    #expect(parsed == original)
}

@Test func testRoundtripPeople() throws {
    let router = AppRouter()
    let original = AppRoute.people
    let printed = try router.print(original)
    let parsed = try router.parse(printed)
    #expect(parsed == original)
}

@Test func testRoundtripRecord() throws {
    let router = AppRouter()
    let original = AppRoute.record
    let printed = try router.print(original)
    let parsed = try router.parse(printed)
    #expect(parsed == original)
}

// MARK: - Invalid Path Tests

@Test func testInvalidPathThrows() {
    let router = AppRouter()
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/invalid"))
    }
}

@Test func testSessionWithoutIdThrows() {
    let router = AppRouter()
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/session"))
    }
}

// MARK: - Deep Link Regression Tests

@Test func testDeepLinkTrailingSlashPeople() throws {
    let router = AppRouter()
    // Trailing slash should parse the same as without
    let route = try router.parse(URLRequestData(path: "/people/"))
    #expect(route == .people)
}

@Test func testDeepLinkTrailingSlashTimeline() throws {
    let router = AppRouter()
    let route = try router.parse(URLRequestData(path: "/timeline/"))
    #expect(route == .timeline)
}

@Test func testDeepLinkTrailingSlashRecord() throws {
    let router = AppRouter()
    let route = try router.parse(URLRequestData(path: "/record/"))
    #expect(route == .record)
}

@Test func testDeepLinkSessionWithUUIDStyle() throws {
    let router = AppRouter()
    let uuid = "550E8400-E29B-41D4-A716-446655440000"
    let route = try router.parse(URLRequestData(path: "/session/\(uuid)"))
    #expect(route == .session(SessionID(rawValue: uuid)))
}

@Test func testDeepLinkSessionWithHyphensAndNumbers() throws {
    let router = AppRouter()
    let id = "session-2026-01-15-001"
    let route = try router.parse(URLRequestData(path: "/session/\(id)"))
    #expect(route == .session(SessionID(rawValue: id)))
}

@Test func testDeepLinkQueryParamsIgnoredForPeople() throws {
    let router = AppRouter()
    var request = URLRequestData(path: "/people")
    request.query = ["sort": ["name"], "filter": ["recent"]]
    let route = try router.parse(request)
    #expect(route == .people)
}

@Test func testDeepLinkQueryParamsIgnoredForSession() throws {
    let router = AppRouter()
    var request = URLRequestData(path: "/session/abc-123")
    request.query = ["highlight": ["segment-5"]]
    let route = try router.parse(request)
    #expect(route == .session(SessionID(rawValue: "abc-123")))
}

@Test func testDeepLinkCaseSensitivityPeople() {
    let router = AppRouter()
    // URL paths are case-sensitive - "/PEOPLE" should not match "/people"
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/PEOPLE"))
    }
}

@Test func testDeepLinkCaseSensitivitySession() {
    let router = AppRouter()
    // "/SESSION/abc" should not match "/session/abc"
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/SESSION/abc-123"))
    }
}

@Test func testDeepLinkCaseSensitivityTimeline() {
    let router = AppRouter()
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/TIMELINE"))
    }
}

@Test func testDeepLinkCaseSensitivityRecord() {
    let router = AppRouter()
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/RECORD"))
    }
}

@Test func testDeepLinkNestedInvalidPath() {
    let router = AppRouter()
    // "/people/settings" is not a valid route
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/people/settings"))
    }
}

@Test func testDeepLinkNestedSessionInvalidPath() {
    let router = AppRouter()
    // "/session/abc/edit" has extra path component
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/session/abc/edit"))
    }
}

@Test func testDeepLinkEmptySessionIdThrows() {
    let router = AppRouter()
    // Empty session ID should fail (trailing slash after session)
    #expect(throws: Error.self) {
        _ = try router.parse(URLRequestData(path: "/session/"))
    }
}

@Test func testDeepLinkSessionIdWithSpecialChars() throws {
    let router = AppRouter()
    // Session ID with underscores should work
    let id = "session_2026_01_15"
    let route = try router.parse(URLRequestData(path: "/session/\(id)"))
    #expect(route == .session(SessionID(rawValue: id)))
}

@Test func testDeepLinkRootIsTimeline() throws {
    let router = AppRouter()
    // Root "/" should always route to timeline
    let route = try router.parse(URLRequestData(path: "/"))
    #expect(route == .timeline)
}

@Test func testDeepLinkPrintPreservesSessionId() throws {
    let router = AppRouter()
    let complexId = "abc-123-def-456"
    let original = AppRoute.session(SessionID(rawValue: complexId))
    let printed = try router.print(original)
    let pathString = "/" + printed.path.joined(separator: "/")
    #expect(pathString == "/session/\(complexId)")
}
