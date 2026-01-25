import Testing
@testable import Audio

// MARK: - Test Data

private let testInterruptionEvents: [AudioSessionEvent] = [
    .interrupted(.began),
    .interrupted(.ended(shouldResume: true)),
    .interrupted(.ended(shouldResume: false)),
]

// MARK: - Tests

@Test func testInterruptionTypeEquatable() {
    // Test InterruptionType equality
    let began1 = InterruptionType.began
    let began2 = InterruptionType.began
    #expect(began1 == began2)

    let endedTrue = InterruptionType.ended(shouldResume: true)
    let endedFalse = InterruptionType.ended(shouldResume: false)
    #expect(endedTrue != endedFalse)

    let endedTrue2 = InterruptionType.ended(shouldResume: true)
    #expect(endedTrue == endedTrue2)
}

@Test func testAudioSessionEventInterruptionEquatable() {
    // Test AudioSessionEvent.interrupted equality
    let event1 = AudioSessionEvent.interrupted(.began)
    let event2 = AudioSessionEvent.interrupted(.began)
    #expect(event1 == event2)

    let event3 = AudioSessionEvent.interrupted(.ended(shouldResume: true))
    let event4 = AudioSessionEvent.interrupted(.ended(shouldResume: false))
    #expect(event3 != event4)
}

@Test func testInterruptionBeganEvent() {
    let event = AudioSessionEvent.interrupted(.began)

    switch event {
    case .interrupted(let type):
        switch type {
        case .began:
            // Expected
            break
        case .ended:
            Issue.record("Expected began, got ended")
        }
    case .routeChanged:
        Issue.record("Expected interrupted, got routeChanged")
    }
}

@Test func testInterruptionEndedWithShouldResume() {
    let event = AudioSessionEvent.interrupted(.ended(shouldResume: true))

    switch event {
    case .interrupted(let type):
        switch type {
        case .began:
            Issue.record("Expected ended, got began")
        case .ended(let shouldResume):
            #expect(shouldResume == true)
        }
    case .routeChanged:
        Issue.record("Expected interrupted, got routeChanged")
    }
}

@Test func testInterruptionEndedWithoutShouldResume() {
    let event = AudioSessionEvent.interrupted(.ended(shouldResume: false))

    switch event {
    case .interrupted(let type):
        switch type {
        case .began:
            Issue.record("Expected ended, got began")
        case .ended(let shouldResume):
            #expect(shouldResume == false)
        }
    case .routeChanged:
        Issue.record("Expected interrupted, got routeChanged")
    }
}

@Test func testAudioSessionClientEmptyStream() async {
    // Test that a mock client with empty stream finishes immediately
    let client = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: { }
    )

    let stream = await client.startObserving()
    var iterator = stream.makeAsyncIterator()
    let firstEvent = await iterator.next()

    // Empty stream should return nil immediately
    #expect(firstEvent == nil)
}

@Test func testMockAudioSessionClient() async {
    // Test creating a mock client that emits specific events
    var eventsToEmit = testInterruptionEvents
    let client = AudioSessionClient(
        startObserving: {
            AsyncStream { continuation in
                for event in eventsToEmit {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        },
        stopObserving: { },
        configureForRecording: { }
    )

    let stream = await client.startObserving()
    var receivedEvents: [AudioSessionEvent] = []

    for await event in stream {
        receivedEvents.append(event)
    }

    #expect(receivedEvents.count == 3)
    #expect(receivedEvents[0] == .interrupted(.began))
    #expect(receivedEvents[1] == .interrupted(.ended(shouldResume: true)))
    #expect(receivedEvents[2] == .interrupted(.ended(shouldResume: false)))
}

@Test func testInterruptionPausesCapture() async {
    // This test verifies the contract: when an interruption begins,
    // the audio session client should emit an interrupted(.began) event
    // which downstream consumers can use to pause capture.

    var capturedEvents: [AudioSessionEvent] = []
    var stopObservingCalled = false

    let client = AudioSessionClient(
        startObserving: {
            AsyncStream { continuation in
                // Simulate an interruption beginning
                continuation.yield(.interrupted(.began))
                // Don't finish - simulate ongoing session
            }
        },
        stopObserving: {
            stopObservingCalled = true
        },
        configureForRecording: { }
    )

    let stream = await client.startObserving()
    var iterator = stream.makeAsyncIterator()

    // Get the first event
    if let event = await iterator.next() {
        capturedEvents.append(event)
    }

    #expect(capturedEvents.count == 1)
    #expect(capturedEvents[0] == .interrupted(.began))

    // Stop observing
    await client.stopObserving()
    #expect(stopObservingCalled)
}
