import Testing
import Foundation
@testable import Observability

@Suite("ErrorEnvelope Tests")
struct ErrorEnvelopeTests {

    // MARK: - ErrorCode Tests

    @Test("ErrorCode has expected raw values")
    func testErrorCodeRawValues() {
        #expect(ErrorCode.databaseRead.rawValue == "DB_READ")
        #expect(ErrorCode.audioCaptureFailed.rawValue == "AUDIO_CAPTURE")
        #expect(ErrorCode.recordingInterrupted.rawValue == "RECORDING_INTERRUPTED")
        #expect(ErrorCode.unknown.rawValue == "UNKNOWN")
    }

    // MARK: - ErrorEnvelope Creation Tests

    @Test("ErrorEnvelope preserves all fields")
    func testErrorEnvelopeFields() {
        let traceId = TraceID("trace-123")
        let timestamp = Date()
        let envelope = ErrorEnvelope(
            code: .databaseRead,
            userMessage: "Test message",
            traceId: traceId,
            sessionId: "session-456",
            recoveryActions: [.retry, .dismiss],
            underlyingError: "SQLite error",
            timestamp: timestamp
        )

        #expect(envelope.code == .databaseRead)
        #expect(envelope.userMessage == "Test message")
        #expect(envelope.traceId == traceId)
        #expect(envelope.sessionId == "session-456")
        #expect(envelope.recoveryActions == [.retry, .dismiss])
        #expect(envelope.underlyingError == "SQLite error")
        #expect(envelope.timestamp == timestamp)
    }

    @Test("ErrorEnvelope default values work")
    func testErrorEnvelopeDefaults() {
        let envelope = ErrorEnvelope(
            code: .unknown,
            userMessage: "Something went wrong"
        )

        #expect(envelope.traceId == nil)
        #expect(envelope.sessionId == nil)
        #expect(envelope.recoveryActions == [.dismiss])
        #expect(envelope.underlyingError == nil)
    }

    // MARK: - Factory Method Tests

    @Test("databaseRead factory creates correct envelope")
    func testDatabaseReadFactory() {
        let traceId = TraceID("trace-db")
        let envelope = ErrorEnvelope.databaseRead(
            message: "Custom DB error",
            traceId: traceId,
            sessionId: "sess-1"
        )

        #expect(envelope.code == .databaseRead)
        #expect(envelope.userMessage == "Custom DB error")
        #expect(envelope.traceId == traceId)
        #expect(envelope.sessionId == "sess-1")
        #expect(envelope.recoveryActions.contains(.retry))
        #expect(envelope.recoveryActions.contains(.dismiss))
    }

    @Test("databaseWrite factory creates correct envelope")
    func testDatabaseWriteFactory() {
        let envelope = ErrorEnvelope.databaseWrite()

        #expect(envelope.code == .databaseWrite)
        #expect(envelope.userMessage == "Unable to save data. Please try again.")
        #expect(envelope.recoveryActions.contains(.retry))
    }

    @Test("audioCapture factory includes openSettings action")
    func testAudioCaptureFactory() {
        let envelope = ErrorEnvelope.audioCapture()

        #expect(envelope.code == .audioCaptureFailed)
        #expect(envelope.recoveryActions.contains(.openSettings))
        #expect(envelope.recoveryActions.contains(.dismiss))
    }

    @Test("recordingInterrupted factory includes sessionId and recovery options")
    func testRecordingInterruptedFactory() {
        let envelope = ErrorEnvelope.recordingInterrupted(
            sessionId: "sess-interrupted"
        )

        #expect(envelope.code == .recordingInterrupted)
        #expect(envelope.sessionId == "sess-interrupted")
        #expect(envelope.recoveryActions.contains(.keepPartial))
        #expect(envelope.recoveryActions.contains(.deleteSession))
    }

    @Test("recordingFinalization factory includes retryFinalize action")
    func testRecordingFinalizationFactory() {
        let envelope = ErrorEnvelope.recordingFinalization(sessionId: "sess-final")

        #expect(envelope.code == .recordingFinalization)
        #expect(envelope.sessionId == "sess-final")
        #expect(envelope.recoveryActions.contains(.retryFinalize))
        #expect(envelope.recoveryActions.contains(.keepPartial))
    }

    @Test("from error factory wraps any error")
    func testFromErrorFactory() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error description" }
        }

        let envelope = ErrorEnvelope.from(
            TestError(),
            code: .mlTranscription,
            userMessage: "Custom message"
        )

        #expect(envelope.code == .mlTranscription)
        #expect(envelope.userMessage == "Custom message")
        #expect(envelope.underlyingError == "Test error description")
    }

    // MARK: - AlertInfo Mapping Tests

    @Test("testErrorMappingToAlert")
    func testErrorMappingToAlert() {
        // This is the required test from the acceptance criteria
        let envelope = ErrorEnvelope.databaseRead(
            message: "Could not load your sessions",
            traceId: TraceID("trace-alert")
        )

        let alertInfo = envelope.toAlertInfo()

        #expect(alertInfo.title == "Data Error")
        #expect(alertInfo.message == "Could not load your sessions")
        #expect(alertInfo.primaryButton.title == "Retry")
        #expect(alertInfo.primaryButton.action == .retry)
        #expect(alertInfo.secondaryButton?.title == "Cancel")
        #expect(alertInfo.secondaryButton?.action == .dismiss)
    }

    @Test("AlertInfo for audio error has correct title")
    func testAlertInfoAudioError() {
        let envelope = ErrorEnvelope.audioCapture()
        let alertInfo = envelope.toAlertInfo()

        #expect(alertInfo.title == "Audio Error")
        #expect(alertInfo.primaryButton.title == "Open Settings")
        #expect(alertInfo.primaryButton.action == .openSettings)
    }

    @Test("AlertInfo for recording error has correct title")
    func testAlertInfoRecordingError() {
        let envelope = ErrorEnvelope.recordingStart()
        let alertInfo = envelope.toAlertInfo()

        #expect(alertInfo.title == "Recording Error")
    }

    @Test("AlertInfo for interrupted recording shows delete option")
    func testAlertInfoInterruptedRecording() {
        let envelope = ErrorEnvelope.recordingInterrupted(sessionId: "sess-1")
        let alertInfo = envelope.toAlertInfo()

        #expect(alertInfo.title == "Recording Error")
        #expect(alertInfo.primaryButton.title == "Keep Partial")
        #expect(alertInfo.primaryButton.action == .keepPartial)
        #expect(alertInfo.secondaryButton?.title == "Delete")
        #expect(alertInfo.secondaryButton?.action == .deleteSession)
        #expect(alertInfo.secondaryButton?.isDestructive == true)
    }

    @Test("AlertInfo for export error has correct title")
    func testAlertInfoExportError() {
        let envelope = ErrorEnvelope.exportFailed()
        let alertInfo = envelope.toAlertInfo()

        #expect(alertInfo.title == "Export Error")
        #expect(alertInfo.primaryButton.action == .retry)
    }

    @Test("AlertInfo for unknown error has generic title")
    func testAlertInfoUnknownError() {
        let envelope = ErrorEnvelope(
            code: .unknown,
            userMessage: "Something unexpected happened"
        )
        let alertInfo = envelope.toAlertInfo()

        #expect(alertInfo.title == "Error")
        #expect(alertInfo.primaryButton.title == "OK")
        #expect(alertInfo.primaryButton.action == .dismiss)
        #expect(alertInfo.secondaryButton == nil)
    }

    @Test("AlertInfo with retryFinalize shows Retry button")
    func testAlertInfoRetryFinalize() {
        let envelope = ErrorEnvelope.recordingFinalization(sessionId: "sess-1")
        let alertInfo = envelope.toAlertInfo()

        #expect(alertInfo.primaryButton.title == "Retry")
        #expect(alertInfo.primaryButton.action == .retryFinalize)
    }

    // MARK: - Equatable Tests

    @Test("ErrorEnvelope is Equatable")
    func testErrorEnvelopeEquatable() {
        let timestamp = Date()
        let envelope1 = ErrorEnvelope(
            code: .databaseRead,
            userMessage: "Test",
            timestamp: timestamp
        )
        let envelope2 = ErrorEnvelope(
            code: .databaseRead,
            userMessage: "Test",
            timestamp: timestamp
        )

        #expect(envelope1 == envelope2)
    }

    @Test("AlertInfo is Equatable")
    func testAlertInfoEquatable() {
        let alert1 = AlertInfo(
            id: "same-id",
            title: "Error",
            message: "Test",
            primaryButton: AlertInfo.AlertButton(title: "OK", action: .dismiss)
        )
        let alert2 = AlertInfo(
            id: "same-id",
            title: "Error",
            message: "Test",
            primaryButton: AlertInfo.AlertButton(title: "OK", action: .dismiss)
        )

        #expect(alert1 == alert2)
    }

    // MARK: - RecoveryAction Tests

    @Test("RecoveryAction has expected raw values")
    func testRecoveryActionRawValues() {
        #expect(RecoveryAction.retry.rawValue == "retry")
        #expect(RecoveryAction.retryFinalize.rawValue == "retryFinalize")
        #expect(RecoveryAction.keepPartial.rawValue == "keepPartial")
        #expect(RecoveryAction.deleteSession.rawValue == "deleteSession")
        #expect(RecoveryAction.openSettings.rawValue == "openSettings")
        #expect(RecoveryAction.dismiss.rawValue == "dismiss")
    }
}
