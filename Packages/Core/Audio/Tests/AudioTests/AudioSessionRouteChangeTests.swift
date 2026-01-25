import Testing
@testable import Audio

// MARK: - Test Data

private let allRouteChangeReasons: [RouteChangeReason] = [
    .newDeviceAvailable,
    .oldDeviceUnavailable,
    .categoryChange,
    .override,
    .wakeFromSleep,
    .noSuitableRouteForCategory,
    .routeConfigurationChange,
    .unknown,
]

// MARK: - Tests

@Test func testRouteChangeReasonEquatable() {
    // Test RouteChangeReason equality
    let reason1 = RouteChangeReason.newDeviceAvailable
    let reason2 = RouteChangeReason.newDeviceAvailable
    #expect(reason1 == reason2)

    let reason3 = RouteChangeReason.oldDeviceUnavailable
    #expect(reason1 != reason3)
}

@Test func testAllRouteChangeReasons() {
    // Verify all route change reasons are distinct
    var uniqueReasons = Set<Int>()
    for (index, reason) in allRouteChangeReasons.enumerated() {
        // Each reason should be unique
        let hashValue = String(describing: reason).hashValue
        #expect(!uniqueReasons.contains(hashValue), "Duplicate reason at index \(index)")
        uniqueReasons.insert(hashValue)
    }

    #expect(allRouteChangeReasons.count == 8)
}

@Test func testAudioSessionEventRouteChangedEquatable() {
    // Test AudioSessionEvent.routeChanged equality
    let event1 = AudioSessionEvent.routeChanged(.newDeviceAvailable)
    let event2 = AudioSessionEvent.routeChanged(.newDeviceAvailable)
    #expect(event1 == event2)

    let event3 = AudioSessionEvent.routeChanged(.oldDeviceUnavailable)
    #expect(event1 != event3)
}

@Test func testRouteChangedNewDeviceEvent() {
    let event = AudioSessionEvent.routeChanged(.newDeviceAvailable)

    switch event {
    case .interrupted:
        Issue.record("Expected routeChanged, got interrupted")
    case .routeChanged(let reason):
        #expect(reason == .newDeviceAvailable)
    }
}

@Test func testRouteChangedOldDeviceUnavailableEvent() {
    let event = AudioSessionEvent.routeChanged(.oldDeviceUnavailable)

    switch event {
    case .interrupted:
        Issue.record("Expected routeChanged, got interrupted")
    case .routeChanged(let reason):
        #expect(reason == .oldDeviceUnavailable)
    }
}

@Test func testRouteChangeRestartsCapture() async {
    // This test verifies the contract: when an old device becomes unavailable,
    // the audio session client emits a routeChanged event.
    // The downstream consumer (RecordingProcessor) should restart capture.

    var capturedEvents: [AudioSessionEvent] = []

    let client = AudioSessionClient(
        startObserving: {
            AsyncStream { continuation in
                // Simulate headphones being unplugged
                continuation.yield(.routeChanged(.oldDeviceUnavailable))
                continuation.finish()
            }
        },
        stopObserving: { },
        configureForRecording: { }
    )

    let stream = await client.startObserving()

    for await event in stream {
        capturedEvents.append(event)
    }

    #expect(capturedEvents.count == 1)
    #expect(capturedEvents[0] == .routeChanged(.oldDeviceUnavailable))
}

@Test func testMockAudioSessionClientWithMixedEvents() async {
    // Test a client that emits both interruption and route change events
    let client = AudioSessionClient(
        startObserving: {
            AsyncStream { continuation in
                continuation.yield(.routeChanged(.newDeviceAvailable))
                continuation.yield(.interrupted(.began))
                continuation.yield(.interrupted(.ended(shouldResume: true)))
                continuation.yield(.routeChanged(.oldDeviceUnavailable))
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

    #expect(receivedEvents.count == 4)
    #expect(receivedEvents[0] == .routeChanged(.newDeviceAvailable))
    #expect(receivedEvents[1] == .interrupted(.began))
    #expect(receivedEvents[2] == .interrupted(.ended(shouldResume: true)))
    #expect(receivedEvents[3] == .routeChanged(.oldDeviceUnavailable))
}

@Test func testConfigureForRecording() async throws {
    // Test that configureForRecording can be called
    var configureWasCalled = false

    let client = AudioSessionClient(
        startObserving: { AsyncStream { $0.finish() } },
        stopObserving: { },
        configureForRecording: {
            configureWasCalled = true
        }
    )

    try await client.configureForRecording()
    #expect(configureWasCalled)
}

@Test func testRouteChangeReasonsComplete() {
    // Ensure we cover all documented route change reasons
    let reasons: [RouteChangeReason] = [
        .newDeviceAvailable,
        .oldDeviceUnavailable,
        .categoryChange,
        .override,
        .wakeFromSleep,
        .noSuitableRouteForCategory,
        .routeConfigurationChange,
        .unknown,
    ]

    // Test each reason can be pattern matched
    for reason in reasons {
        let event = AudioSessionEvent.routeChanged(reason)
        switch event {
        case .routeChanged(let r):
            #expect(r == reason)
        case .interrupted:
            Issue.record("Unexpected interrupted event")
        }
    }
}
