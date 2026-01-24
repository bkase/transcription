import Testing
import Foundation
@testable import Persistence

// MARK: - Preview Text Tests

@Test func testPreviewTextFromSegments() async throws {
    let now = Date()

    // Create segments with varying content
    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-1",
            text: "Hello, this is the first segment.",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 2500,
            endMs: 5000,
            machineSpeakerId: "speaker-2",
            text: "And this is the second segment with more content.",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-3",
            sessionId: "session-1",
            startMs: 5000,
            endMs: 7500,
            machineSpeakerId: "speaker-1",
            text: "Third segment here.",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let preview = DerivedMetadata.previewText(from: segments)
    #expect(preview != nil)
    #expect(preview!.hasPrefix("Hello, this is the first segment."))
}

@Test func testPreviewTextTruncatesLongContent() async throws {
    let now = Date()

    let longText = String(repeating: "word ", count: 50) // ~250 characters
    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-1",
            text: longText,
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let preview = DerivedMetadata.previewText(from: segments, maxLength: 50)
    #expect(preview != nil)
    #expect(preview!.count <= 53) // 50 + "..."
    #expect(preview!.hasSuffix("..."))
}

@Test func testPreviewTextReturnsNilForEmptySegments() async throws {
    let preview = DerivedMetadata.previewText(from: [])
    #expect(preview == nil)
}

@Test func testPreviewTextIgnoresNonFinalSegments() async throws {
    let now = Date()

    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-1",
            text: "This is a partial segment.",
            isFinal: false, // Not final!
            createdAt: now,
            updatedAt: now
        ),
    ]

    let preview = DerivedMetadata.previewText(from: segments)
    #expect(preview == nil)
}

@Test func testPreviewTextOrdersByStartMs() async throws {
    let now = Date()

    // Segments inserted out of order
    let segments = [
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 5000,
            endMs: 7500,
            machineSpeakerId: "speaker-1",
            text: "Second text.",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-1",
            text: "First text.",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let preview = DerivedMetadata.previewText(from: segments)
    #expect(preview != nil)
    #expect(preview!.hasPrefix("First text.")) // Should start with earliest segment
}

// MARK: - Speaker Count Tests

@Test func testSpeakerCount() async throws {
    let now = Date()

    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-A",
            text: "Hello",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 2500,
            endMs: 5000,
            machineSpeakerId: "speaker-B",
            text: "World",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-3",
            sessionId: "session-1",
            startMs: 5000,
            endMs: 7500,
            machineSpeakerId: "speaker-A", // Same as seg-1
            text: "Again",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let count = DerivedMetadata.speakerCount(from: segments)
    #expect(count == 2) // speaker-A and speaker-B
}

@Test func testSpeakerCountIgnoresNonFinalSegments() async throws {
    let now = Date()

    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-A",
            text: "Hello",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 2500,
            endMs: 5000,
            machineSpeakerId: "speaker-B",
            text: "World",
            isFinal: false, // Not final - should be ignored
            createdAt: now,
            updatedAt: now
        ),
    ]

    let count = DerivedMetadata.speakerCount(from: segments)
    #expect(count == 1) // Only speaker-A from final segments
}

@Test func testSpeakerCountWithNilSpeakerId() async throws {
    let now = Date()

    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: nil, // No speaker ID
            text: "Hello",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 2500,
            endMs: 5000,
            machineSpeakerId: "speaker-A",
            text: "World",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let count = DerivedMetadata.speakerCount(from: segments)
    #expect(count == 1) // nil speaker IDs are not counted
}

@Test func testSpeakerCountReturnsZeroForEmptySegments() async throws {
    let count = DerivedMetadata.speakerCount(from: [])
    #expect(count == 0)
}

// MARK: - Duration Tests

@Test func testDurationMsFromSegments() async throws {
    let now = Date()

    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-1",
            text: "Hello",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 2500,
            endMs: 7500, // Latest end time
            machineSpeakerId: "speaker-2",
            text: "World",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-3",
            sessionId: "session-1",
            startMs: 3000,
            endMs: 5000, // Overlapping but earlier end
            machineSpeakerId: "speaker-1",
            text: "Again",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let duration = DerivedMetadata.durationMs(from: segments)
    #expect(duration == 7500) // Max endMs
}

@Test func testDurationMsReturnsNilForEmptySegments() async throws {
    let duration = DerivedMetadata.durationMs(from: [])
    #expect(duration == nil)
}

@Test func testDurationMsIgnoresNonFinalSegments() async throws {
    let now = Date()

    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-1",
            text: "Hello",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 2500,
            endMs: 10000, // Later but not final
            machineSpeakerId: "speaker-2",
            text: "World",
            isFinal: false,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let duration = DerivedMetadata.durationMs(from: segments)
    #expect(duration == 2500) // Only considers final segment
}

// MARK: - Compute All Tests

@Test func testComputeAllReturnsAllMetadata() async throws {
    let now = Date()

    let segments = [
        TranscriptSegmentRecord(
            id: "seg-1",
            sessionId: "session-1",
            startMs: 0,
            endMs: 2500,
            machineSpeakerId: "speaker-A",
            text: "Hello there.",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
        TranscriptSegmentRecord(
            id: "seg-2",
            sessionId: "session-1",
            startMs: 2500,
            endMs: 5000,
            machineSpeakerId: "speaker-B",
            text: "How are you?",
            isFinal: true,
            createdAt: now,
            updatedAt: now
        ),
    ]

    let (previewText, durationMs, speakerCount) = DerivedMetadata.computeAll(from: segments)

    #expect(previewText != nil)
    #expect(previewText!.contains("Hello there."))
    #expect(durationMs == 5000)
    #expect(speakerCount == 2)
}
