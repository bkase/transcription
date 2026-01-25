import Testing
import Foundation
import Dependencies
@testable import Observability

@Suite("LoggingClient Tests")
struct LoggingTests {

    @Test("TraceID generates unique values")
    func testTraceIdGeneratesUniqueValues() {
        let id1 = TraceID.generate()
        let id2 = TraceID.generate()
        #expect(id1 != id2)
    }

    @Test("TraceID description matches rawValue")
    func testTraceIdDescription() {
        let id = TraceID("test-trace-123")
        #expect(id.description == "test-trace-123")
    }

    @Test("LogLevel comparison works correctly")
    func testLogLevelComparison() {
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
        #expect(!(LogLevel.error < LogLevel.debug))
    }

    @Test("LogEntry preserves all fields")
    func testLogEntryFields() {
        let timestamp = Date()
        let traceId = TraceID("trace-abc")
        let entry = LogEntry(
            timestamp: timestamp,
            level: .info,
            message: "Test message",
            traceId: traceId,
            sessionId: "session-123",
            event: "test_event",
            latencyMs: 42,
            metadata: ["key": "value"]
        )

        #expect(entry.timestamp == timestamp)
        #expect(entry.level == .info)
        #expect(entry.message == "Test message")
        #expect(entry.traceId == traceId)
        #expect(entry.sessionId == "session-123")
        #expect(entry.event == "test_event")
        #expect(entry.latencyMs == 42)
        #expect(entry.metadata == ["key": "value"])
    }

    @Test("Trace ID propagates through logging operations")
    func testTraceIdPropagates() async {
        // Use actors for thread-safe state management
        actor LogCapture {
            var entries: [LogEntry] = []
            func append(_ entry: LogEntry) {
                entries.append(entry)
            }
            func getEntries() -> [LogEntry] {
                entries
            }
        }

        actor TraceState {
            var currentTraceId: TraceID?
            func get() -> TraceID? { currentTraceId }
            func set(_ id: TraceID?) { currentTraceId = id }
            func start() -> TraceID {
                let newId = TraceID.generate()
                currentTraceId = newId
                return newId
            }
            func end() { currentTraceId = nil }
        }

        let capture = LogCapture()
        let traceState = TraceState()

        // Create a test logging client that captures entries
        let testClient = LoggingClient(
            log: { entry in
                await capture.append(entry)
            },
            currentTraceId: {
                await traceState.get()
            },
            setTraceId: { traceId in
                await traceState.set(traceId)
            },
            startTrace: {
                await traceState.start()
            },
            endTrace: {
                await traceState.end()
            }
        )

        // Start a trace
        let traceId = await testClient.startTrace()

        // Log some messages using convenience methods
        await testClient.info("First message", sessionId: "sess-1")
        await testClient.debug("Debug message")
        await testClient.warning("Warning message", event: "test_warning")
        await testClient.error("Error message", latencyMs: 100, metadata: ["code": "ERR001"])

        // End the trace
        await testClient.endTrace()

        // Log one more after trace ended
        await testClient.info("After trace ended")

        // Verify the captured entries
        let entries = await capture.getEntries()
        #expect(entries.count == 5)

        // First 4 entries should have the trace ID
        #expect(entries[0].traceId == traceId)
        #expect(entries[0].level == .info)
        #expect(entries[0].message == "First message")
        #expect(entries[0].sessionId == "sess-1")

        #expect(entries[1].traceId == traceId)
        #expect(entries[1].level == .debug)

        #expect(entries[2].traceId == traceId)
        #expect(entries[2].level == .warning)
        #expect(entries[2].event == "test_warning")

        #expect(entries[3].traceId == traceId)
        #expect(entries[3].level == .error)
        #expect(entries[3].latencyMs == 100)
        #expect(entries[3].metadata["code"] == "ERR001")

        // Last entry should have no trace ID
        #expect(entries[4].traceId == nil)
    }

    @Test("Live client trace context is isolated")
    func testLiveClientTraceContextIsolated() async {
        let client = LoggingClient.live()

        // Initially no trace
        let initial = await client.currentTraceId()
        #expect(initial == nil)

        // Start a trace
        let traceId = await client.startTrace()
        let current = await client.currentTraceId()
        #expect(current == traceId)

        // Set a different trace
        let newTrace = TraceID("custom-trace")
        await client.setTraceId(newTrace)
        let updated = await client.currentTraceId()
        #expect(updated == newTrace)

        // End trace
        await client.endTrace()
        let final = await client.currentTraceId()
        #expect(final == nil)
    }

    @Test("withDependencies injects logging client")
    func testWithDependenciesInjection() async {
        actor EntryCapture {
            var entry: LogEntry?
            func set(_ e: LogEntry) { entry = e }
            func get() -> LogEntry? { entry }
        }

        let capture = EntryCapture()

        await withDependencies {
            $0.loggingClient = LoggingClient(
                log: { entry in
                    await capture.set(entry)
                },
                currentTraceId: { nil },
                setTraceId: { _ in },
                startTrace: { TraceID.generate() },
                endTrace: { }
            )
        } operation: {
            @Dependency(\.loggingClient) var logger
            await logger.log(LogEntry(level: .info, message: "Injected log"))
        }

        let loggedEntry = await capture.get()
        #expect(loggedEntry?.message == "Injected log")
        #expect(loggedEntry?.level == .info)
    }
}
