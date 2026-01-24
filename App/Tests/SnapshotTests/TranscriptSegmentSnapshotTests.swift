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
            // User segment
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("User Segment")
                TranscriptSegment(
                    speaker: .user,
                    timestamp: "00:12",
                    text: "So we're looking at the Vapor direction."
                )
            }

            // Guest segment
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Guest Segment")
                TranscriptSegment(
                    speaker: .guest,
                    timestamp: "00:18",
                    text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                )
            }

            // Custom speaker
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Custom Speaker")
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
        // A realistic conversation flow
        let view = VStack(alignment: .leading, spacing: 16) {
            TranscriptSegment(
                speaker: .user,
                timestamp: "00:12",
                text: "So we're looking at the Vapor direction."
            )

            TranscriptSegment(
                speaker: .guest,
                timestamp: "00:18",
                text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
            )

            TranscriptSegment(
                speaker: .user,
                timestamp: "00:35",
                text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
            )

            TranscriptSegment(
                speaker: .guest,
                timestamp: "00:52",
                text: "Right, and when we look at the transcript, it shouldn't feel like a messaging app. It should feel like a script. A record."
            )

            TranscriptSegment(
                speaker: .user,
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
                    speaker: .user,
                    timestamp: "00:12",
                    text: "So we're looking at the Vapor direction."
                )

                TranscriptSegment(
                    speaker: .guest,
                    timestamp: "00:18",
                    text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                )

                TranscriptSegment(
                    speaker: .user,
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
}
