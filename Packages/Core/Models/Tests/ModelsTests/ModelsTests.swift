import Testing
@testable import Models

@Test func typedIDsAreDifferentiatedByTag() {
    let sessionID = SessionID(rawValue: "abc")
    let personID = PersonID(rawValue: "abc")

    // They have the same raw value but are different types
    #expect(sessionID.rawValue == personID.rawValue)
    // Type system ensures they can't be mixed up
}
