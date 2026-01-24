import Testing
@testable import Models

@Test func testTimeRangeRejectsInvalid() {
    // start == end should be rejected
    let equalRange = TimeRangeMs(start: Milliseconds(100), end: Milliseconds(100))
    #expect(equalRange == nil)

    // start > end should be rejected
    let invertedRange = TimeRangeMs(start: Milliseconds(200), end: Milliseconds(100))
    #expect(invertedRange == nil)
}

@Test func testTimeRangeAcceptsValid() {
    let validRange = TimeRangeMs(start: Milliseconds(100), end: Milliseconds(200))
    #expect(validRange != nil)
    #expect(validRange?.start == Milliseconds(100))
    #expect(validRange?.end == Milliseconds(200))
    #expect(validRange?.durationMs == Milliseconds(100))
}

@Test func testMillisecondsComparable() {
    let smaller = Milliseconds(100)
    let larger = Milliseconds(200)
    #expect(smaller < larger)
    #expect(larger > smaller)
    #expect(smaller == Milliseconds(100))
}
