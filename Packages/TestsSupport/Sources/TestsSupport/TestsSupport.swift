import Foundation
import Models
import SnapshotTesting
import Gen

// Generators for property testing
public let sessionIDGen: Gen<SessionID> = Gen.string.map { SessionID(rawValue: "session-\($0)") }
public let personIDGen: Gen<PersonID> = Gen.string.map { PersonID(rawValue: "person-\($0)") }

// Snapshot testing helpers
public func assertSnapshot<Value>(
    matching value: Value,
    as snapshotting: Snapshotting<Value, some Any>,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    SnapshotTesting.assertSnapshot(
        of: value,
        as: snapshotting,
        file: file,
        testName: testName,
        line: line
    )
}
