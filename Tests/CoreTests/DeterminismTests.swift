import Foundation
import Testing
import Dependencies
import Clocks
@testable import Processing
@testable import Models

/// Tests that verify clock and UUID dependencies can be injected for deterministic testing.
///
/// Deterministic testing requires:
/// 1. Dates to be fixed to known values
/// 2. UUIDs to return predictable values
/// 3. Clocks to be controllable for time-based logic
@Suite
struct DeterminismTests {

    // MARK: - Date Dependency Injection

    @Test func testDateDependencyInjectedAsConstant() {
        // Given a fixed date
        let fixedDate = Date(timeIntervalSince1970: 1700000000) // Nov 14, 2023

        // When we inject it as a constant
        let capturedDate = withDependencies {
            $0.date = .constant(fixedDate)
        } operation: {
            @Dependency(\.date) var date
            return date.now
        }

        // Then the dependency returns the fixed value
        #expect(capturedDate == fixedDate, "Date dependency should return the constant value")
    }

    @Test func testDateDependencyConstantReturnsConsistentValue() {
        // Given a fixed date
        let fixedDate = Date(timeIntervalSince1970: 1234567890)

        // When we access it multiple times
        let dates = withDependencies {
            $0.date = .constant(fixedDate)
        } operation: {
            @Dependency(\.date) var date
            return [date.now, date.now, date.now]
        }

        // Then all accesses return the same value
        #expect(dates.allSatisfy { $0 == fixedDate }, "All date accesses should return same constant")
    }

    // MARK: - UUID Dependency Injection

    @Test func testUUIDDependencyInjectedAsConstant() {
        // Given a fixed UUID
        let fixedUUID = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!

        // When we inject it as a constant
        let capturedUUID = withDependencies {
            $0.uuid = .constant(fixedUUID)
        } operation: {
            @Dependency(\.uuid) var uuid
            return uuid()
        }

        // Then the dependency returns the fixed value
        #expect(capturedUUID == fixedUUID, "UUID dependency should return the constant value")
    }

    @Test func testUUIDDependencyConstantReturnsConsistentValue() {
        // Given a fixed UUID
        let fixedUUID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        // When we access it multiple times
        let uuids = withDependencies {
            $0.uuid = .constant(fixedUUID)
        } operation: {
            @Dependency(\.uuid) var uuid
            return [uuid(), uuid(), uuid()]
        }

        // Then all accesses return the same value (unlike live which generates new each time)
        #expect(uuids.allSatisfy { $0 == fixedUUID }, "All UUID accesses should return same constant")
    }

    @Test func testUUIDDependencyIncrementingReturnsSequentialValues() {
        // Given an incrementing UUID generator using a thread-safe counter
        let counter = UUIDCounter()

        // When we access it multiple times
        let uuids = withDependencies {
            $0.uuid = .init {
                counter.nextSync()
            }
        } operation: {
            @Dependency(\.uuid) var uuid
            return [uuid(), uuid(), uuid()]
        }

        // Then each access returns a different sequential value
        #expect(uuids[0].uuidString == "00000000-0000-0000-0000-000000000000")
        #expect(uuids[1].uuidString == "00000000-0000-0000-0000-000000000001")
        #expect(uuids[2].uuidString == "00000000-0000-0000-0000-000000000002")
    }

    // MARK: - Clock Dependency Injection

    @Test func testClockDependencyInjectedAsTestClock() async throws {
        // Given a TestClock
        let testClock = TestClock()

        // When we use it to sleep
        let sleepCompleted = await withDependencies {
            $0.continuousClock = testClock
        } operation: { () -> Bool in
            @Dependency(\.continuousClock) var clock

            // Start a task that sleeps
            let task = Task {
                try await clock.sleep(for: .seconds(5))
                return true
            }

            // Advance time
            await testClock.advance(by: .seconds(5))

            return (try? await task.value) ?? false
        }

        // Then the sleep completes when we advance time
        #expect(sleepCompleted, "TestClock should allow controlled time advancement")
    }

    @Test func testClockDependencyInjectedAsImmediateClock() async throws {
        // Given an ImmediateClock (completes immediately)
        let immediateClock = ImmediateClock()

        // When we use it to sleep
        let startTime = Date()
        await withDependencies {
            $0.continuousClock = immediateClock
        } operation: {
            @Dependency(\.continuousClock) var clock
            try? await clock.sleep(for: .seconds(10))
        }
        let elapsed = Date().timeIntervalSince(startTime)

        // Then the sleep completes immediately (not 10 seconds)
        #expect(elapsed < 1, "ImmediateClock should complete sleep immediately")
    }

    // MARK: - Combined Dependencies Test

    @Test func testClockAndUUIDInjected() async throws {
        // This is the main acceptance criteria test
        // Given fixed values for all time-sensitive dependencies
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let fixedUUID = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000001")!
        let testClock = TestClock()

        // When we inject all dependencies together
        let result = await withDependencies {
            $0.date = .constant(fixedDate)
            $0.uuid = .constant(fixedUUID)
            $0.continuousClock = testClock
        } operation: { () -> (Date, UUID, Bool) in
            @Dependency(\.date) var date
            @Dependency(\.uuid) var uuid
            @Dependency(\.continuousClock) var clock

            let capturedDate = date.now
            let capturedUUID = uuid()

            // Verify clock is controllable
            let task = Task {
                try await clock.sleep(for: .seconds(1))
                return true
            }
            await testClock.advance(by: .seconds(1))
            let clockWorked = (try? await task.value) ?? false

            return (capturedDate, capturedUUID, clockWorked)
        }

        // Then all dependencies return deterministic values
        #expect(result.0 == fixedDate, "Date should be deterministic")
        #expect(result.1 == fixedUUID, "UUID should be deterministic")
        #expect(result.2, "Clock should be controllable")
    }

    // MARK: - Nested Dependency Context Test

    @Test func testDependenciesInheritInNestedWithDependencies() {
        // Given fixed dependencies
        let fixedDate = Date(timeIntervalSince1970: 1600000000)
        let fixedUUID = UUID(uuidString: "CAFEBABE-0000-0000-0000-000000000000")!

        // When we create nested withDependencies operations
        let (outerDate, innerDate, outerUUID, innerUUID) = withDependencies {
            $0.date = .constant(fixedDate)
            $0.uuid = .constant(fixedUUID)
        } operation: { () -> (Date, Date, UUID, UUID) in
            @Dependency(\.date) var date
            @Dependency(\.uuid) var uuid

            let outer = (date.now, uuid())

            // Inner withDependencies block should inherit from outer
            let inner = withDependencies { _ in
                // No additional overrides - should inherit
            } operation: {
                @Dependency(\.date) var innerDate
                @Dependency(\.uuid) var innerUUID
                return (innerDate.now, innerUUID())
            }

            return (outer.0, inner.0, outer.1, inner.1)
        }

        // Then both contexts have the same deterministic values
        #expect(outerDate == fixedDate, "Outer date should be deterministic")
        #expect(innerDate == fixedDate, "Inner date should inherit deterministic value")
        #expect(outerUUID == fixedUUID, "Outer UUID should be deterministic")
        #expect(innerUUID == fixedUUID, "Inner UUID should inherit deterministic value")
    }
}

// MARK: - Test Helpers

/// Thread-safe counter for generating sequential UUIDs in tests
private final class UUIDCounter: @unchecked Sendable {
    private var counter = 0
    private let lock = NSLock()

    func nextSync() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let value = counter
        counter += 1
        return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }
}
