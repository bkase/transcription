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
