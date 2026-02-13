import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Transcript Catalog

extension CatalogBase {
    @Suite("Transcript Components")
    @MainActor
    struct TranscriptCatalog {

        @Test func testTranscriptSegmentTypes() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Unassigned Speaker 1 (Chip)")
                    TranscriptSegment(
                        speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                        timestamp: "00:12", text: "So we're looking at the Vapor direction."
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Unassigned Speaker 2 (Chip)")
                    TranscriptSegment(
                        speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                        timestamp: "00:18", text: "Exactly. It needs to feel like breath on glass."
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Assigned Speaker (Dot + Name)")
                    TranscriptSegment(
                        speaker: .speaker(name: "Alex", color: VaporColor.deep),
                        timestamp: "01:45", text: "I think we should also consider the mobile experience."
                    )
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "transcript_segment_types",
                                   section: "Components", description: "Transcript segments: unassigned chips and assigned speaker with dot+name.")
        }

        @Test func testTranscriptConversation() {
            let view = VStack(alignment: .leading, spacing: 16) {
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:12", text: "So we're looking at the Vapor direction."
                )
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:18", text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                )
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:35", text: "I love that metaphor. The UI should barely be there."
                )
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:52", text: "Right, and the transcript should feel like a script. A record."
                )
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "01:10", text: "Agreed. Let's tighten up the spacing. No bubbles, just text."
                )
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "transcript_conversation",
                                   section: "Components", description: "Multi-turn conversation flow with alternating speakers.")
        }

        @Test func testTranscriptIndicators() {
            let view = VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Live Indicator")
                    TranscriptLiveIndicator()
                }
                .frame(maxWidth: .infinity).background(VaporColor.haze.opacity(0.5)).cornerRadius(VaporRadius.sm)
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("End of Session Indicator")
                    TranscriptEndIndicator()
                }
                .frame(maxWidth: .infinity).background(VaporColor.haze.opacity(0.5)).cornerRadius(VaporRadius.sm)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "transcript_indicators",
                                   section: "Components", description: "Live and end-of-session transcript indicators.")
        }

        @Test func testTranscriptActiveSegment() {
            let view = VStack(alignment: .leading, spacing: 16) {
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:12", text: "So we're looking at the Vapor direction.", isActive: false
                )
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                    timestamp: "00:18", text: "Exactly. It needs to feel like breath on glass.", isActive: false
                )
                TranscriptSegment(
                    speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                    timestamp: "00:35", text: "I love that metaphor. The UI should barely be there.", isActive: true
                )
                TranscriptLiveIndicator()
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "transcript_active_segment",
                                   section: "Components", description: "Active segment with breathing animation and live indicator.")
        }

        @Test func testTranscriptTimestampAlignment() {
            let view = VStack(alignment: .leading, spacing: 16) {
                TranscriptSegment(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                                  timestamp: "00:01", text: "First segment with short timestamp.")
                TranscriptSegment(speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                                  timestamp: "05:30", text: "Second segment with medium timestamp.")
                TranscriptSegment(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                                  timestamp: "59:59", text: "Third segment with maximum two-digit timestamp.")
                TranscriptSegment(speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                                  timestamp: "88:88", text: "Fourth segment using widest digit (8) for alignment.")
                TranscriptSegment(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                                  timestamp: "11:11", text: "Fifth segment using narrowest digit (1) for alignment.")
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(VaporColor.cloud)

            CatalogHarness.capture(of: view, named: "transcript_timestamp_alignment",
                                   section: "Components", description: "Timestamp alignment with monospaced digits at various widths.")
        }
    }
}
