import Models
import URLRouting

public enum AppRoute: Equatable {
    case timeline
    case session(SessionID)
    case people
    case record
}
