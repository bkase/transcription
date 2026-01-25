import Models
import URLRouting

public enum AppRoute: Equatable, Sendable {
    case timeline
    case session(SessionID)
    case people
    case record
}

// MARK: - URL Router

/// Router for parsing and printing AppRoute to/from URL paths.
///
/// URL scheme:
/// - `/` or `/timeline` → `.timeline`
/// - `/session/:id` → `.session(SessionID)`
/// - `/people` → `.people`
/// - `/record` → `.record`
public struct AppRouter: ParserPrinter {
    public init() {}

    public var body: some URLRouting.Router<AppRoute> {
        OneOf {
            // Session: "/session/:id" - must be before timeline to not conflict
            Route(.case(AppRoute.session)) {
                Path { "session"; Parse(.string.map(.sessionID)) }
            }

            // People: "/people"
            Route(.case(AppRoute.people)) {
                Path { "people" }
            }

            // Record: "/record"
            Route(.case(AppRoute.record)) {
                Path { "record" }
            }

            // Timeline: "/timeline" explicit path
            Route(.case(AppRoute.timeline)) {
                Path { "timeline" }
            }

            // Timeline: "/" root path (must be last to avoid matching other routes)
            Route(.case(AppRoute.timeline))
        }
    }
}

// MARK: - SessionID Conversion

extension Conversion where Self == SessionIDConversion {
    static var sessionID: SessionIDConversion { SessionIDConversion() }
}

public struct SessionIDConversion: Conversion {
    public init() {}

    public func apply(_ input: String) -> SessionID {
        SessionID(rawValue: input)
    }

    public func unapply(_ output: SessionID) -> String {
        output.rawValue
    }
}
