import Testing
import Foundation
import Persistence
import DesignSystem
@testable import TimelineFeature

struct TimelineCardViewModelTests {

    // MARK: - testPreviewAndBadge

    @Test
    func testPreviewAndBadge() {
        // Given a session with full metadata
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            endedAt: mockDate.addingTimeInterval(2530), // ~42 minutes
            title: "Architecture Review",
            previewText: "So we're looking at the Vapor direction...",
            durationMs: 2530000, // 42:10
            audioPath: "/audio/session-1.caf",
            processingState: .processed,
            speakerCount: 2,
            updatedAt: mockDate
        )

        // Create a fixed formatter for deterministic output
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "UTC")

        // When we create a view model
        let viewModel = SessionCardViewModel.from(session: session, timeFormatter: formatter)

        // Then the view model has correctly mapped values
        #expect(viewModel.title == "Architecture Review")
        #expect(viewModel.previewText == "So we're looking at the Vapor direction...")
        #expect(viewModel.speakerCount == 2)
        #expect(viewModel.duration == "42:10")
        #expect(viewModel.isTranscribed == true)
    }

    // MARK: - testUntitledSessionDefaultsToUntitled

    @Test
    func testUntitledSessionDefaultsToUntitled() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            title: nil, // No title
            previewText: nil, // No preview
            processingState: .recording,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.title == "Untitled")
        #expect(viewModel.previewText == "")
    }

    // MARK: - testZeroSpeakerCountMapsToNil

    @Test
    func testZeroSpeakerCountMapsToNil() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .recording,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.speakerCount == nil)
    }

    // MARK: - testNonZeroSpeakerCountIsPreserved

    @Test
    func testNonZeroSpeakerCountIsPreserved() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .processed,
            speakerCount: 3,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.speakerCount == 3)
    }

    // MARK: - testDurationFormattingMinutesAndSeconds

    @Test
    func testDurationFormattingMinutesAndSeconds() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            durationMs: 90000, // 1:30
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.duration == "1:30")
    }

    // MARK: - testDurationFormattingWithHours

    @Test
    func testDurationFormattingWithHours() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            durationMs: 3723000, // 1:02:03
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.duration == "1:02:03")
    }

    // MARK: - testNilDurationMapsToNil

    @Test
    func testNilDurationMapsToNil() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            durationMs: nil,
            processingState: .recording,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.duration == nil)
    }

    // MARK: - testIsTranscribedStates

    @Test
    func testIsTranscribedWhenProcessed() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.isTranscribed == true)
    }

    @Test
    func testIsNotTranscribedWhenRecording() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .recording,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.isTranscribed == false)
    }

    @Test
    func testIsNotTranscribedWhenPartial() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .partial,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.isTranscribed == false)
    }

    @Test
    func testIsNotTranscribedWhenFailed() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .failed,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.isTranscribed == false)
    }

    // MARK: - Status Pill Type Mapping

    @Test
    func testStatusPillTypeNilWhenProcessed() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .processed,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.statusPillType == nil)
    }

    @Test
    func testStatusPillTypeNilWhenRecording() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .recording,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.statusPillType == nil)
    }

    @Test
    func testStatusPillTypeTranscribingWhenTranscribing() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .transcribing,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.statusPillType == .transcribing)
    }

    @Test
    func testStatusPillTypePartialWhenPartial() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .partial,
            speakerCount: 1,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.statusPillType == .partial)
    }

    @Test
    func testStatusPillTypeFailedWhenFailed() {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let session = SessionRecord(
            id: "session-1",
            startedAt: mockDate,
            processingState: .failed,
            speakerCount: 0,
            updatedAt: mockDate
        )

        let viewModel = SessionCardViewModel.from(session: session)

        #expect(viewModel.statusPillType == .failed)
    }
}
