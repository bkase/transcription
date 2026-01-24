import Testing
@testable import Models

@Test func testTypedIdsNotInterchangeable() {
    // These IDs have the same raw value but different types
    let sessionID = SessionID(rawValue: "same-value")
    let personID = PersonID(rawValue: "same-value")
    let speakerTrackID = SpeakerTrackID(rawValue: "same-value")
    let transcriptSegmentID = TranscriptSegmentID(rawValue: "same-value")

    // All have identical raw values
    #expect(sessionID.rawValue == personID.rawValue)
    #expect(personID.rawValue == speakerTrackID.rawValue)
    #expect(speakerTrackID.rawValue == transcriptSegmentID.rawValue)

    // But they cannot be assigned to each other at compile time
    // The type system enforces that SessionID cannot be used where PersonID is expected
    // This test documents that property - actual compile-time safety is verified by the types themselves
}

@Test func testMachineSpeakerIDRejectsEmpty() {
    let emptyID = MachineSpeakerID("")
    #expect(emptyID == nil)
}

@Test func testMachineSpeakerIDAcceptsNonEmpty() {
    let validID = MachineSpeakerID("spk_0")
    #expect(validID != nil)
    #expect(validID?.rawValue == "spk_0")
}
