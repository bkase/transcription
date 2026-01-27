import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Transcript Segment Snapshot Tests

@Suite("Transcript Segment Component Snapshots")
@MainActor
struct TranscriptSegmentSnapshotTests {

    @Test func testTranscriptSegment() {
        let view = VStack(alignment: .leading, spacing: 24) {
            // Unassigned Speaker 1 segment
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Unassigned Speaker 1 (Chip)")
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:12",
                    text: "So we're looking at the Vapor direction."
                )
            }

            // Unassigned Speaker 2 segment
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Unassigned Speaker 2 (Chip)")
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:18",
                    text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                )
            }

            // Assigned speaker
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Assigned Speaker (Dot + Name)")
                TranscriptSegment(
                    speaker: .speaker(name: "Alex", color: VaporColor.deep),
                    timestamp: "01:45",
                    text: "I think we should also consider the mobile experience."
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "transcript_segment")
    }

    @Test func testTranscriptConversation() {
        // A realistic conversation flow with unassigned speakers
        let view = VStack(alignment: .leading, spacing: 16) {
            TranscriptSegment(
                speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                timestamp: "00:12",
                text: "So we're looking at the Vapor direction."
            )

            TranscriptSegment(
                speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                timestamp: "00:18",
                text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
            )

            TranscriptSegment(
                speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                timestamp: "00:35",
                text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
            )

            TranscriptSegment(
                speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                timestamp: "00:52",
                text: "Right, and when we look at the transcript, it shouldn't feel like a messaging app. It should feel like a script. A record."
            )

            TranscriptSegment(
                speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                timestamp: "01:10",
                text: "Agreed. Let's tighten up the spacing. No bubbles, just text."
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "transcript_conversation")
    }

    @Test func testTranscriptIndicators() {
        let view = VStack(alignment: .leading, spacing: 24) {
            // Live indicator
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Live Indicator")
                TranscriptLiveIndicator()
            }
            .frame(maxWidth: .infinity)
            .background(VaporColor.haze.opacity(0.5))
            .cornerRadius(VaporRadius.sm)

            // End of session indicator
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("End of Session Indicator")
                TranscriptEndIndicator()
            }
            .frame(maxWidth: .infinity)
            .background(VaporColor.haze.opacity(0.5))
            .cornerRadius(VaporRadius.sm)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "transcript_indicators")
    }

    @Test func testTranscriptInSessionDetail() {
        // Simulating the session detail screen layout
        let view = VStack(alignment: .leading, spacing: 0) {
            // Header area simulation
            VStack(alignment: .leading, spacing: 4) {
                Text("Architecture Review")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)
                Text("9:41 AM  \u{2022}  42:10")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)

            // Transcript content
            VStack(alignment: .leading, spacing: 16) {
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:12",
                    text: "So we're looking at the Vapor direction."
                )

                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:18",
                    text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                )

                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:35",
                    text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
                )

                TranscriptEndIndicator()
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "transcript_in_session_detail")
    }

    @Test func testActiveSegmentBreathing() {
        // Test active segment with breathing animation (live recording state)
        // The active segment should have scale effect applied
        let view = VStack(alignment: .leading, spacing: 16) {
            // Previous segments (not active)
            TranscriptSegment(
                speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                timestamp: "00:12",
                text: "So we're looking at the Vapor direction.",
                isActive: false
            )

            TranscriptSegment(
                speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                timestamp: "00:18",
                text: "Exactly. It needs to feel like breath on glass.",
                isActive: false
            )

            // Current active segment (most recent, has breathing animation)
            TranscriptSegment(
                speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                timestamp: "00:35",
                text: "I love that metaphor. The UI should barely be there.",
                isActive: true
            )

            // Live indicator
            TranscriptLiveIndicator()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.cloud)

        SnapshotHarness.assertSnapshot(of: view, named: "transcript_active_segment")
    }
}
