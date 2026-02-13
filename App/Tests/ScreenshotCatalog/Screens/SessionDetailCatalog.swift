import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import SessionDetailFeature

// MARK: - Session Detail Catalog

extension CatalogBase {
    @Suite("Session Detail")
    @MainActor
    struct SessionDetailCatalog {

        @Test func testSessionDetailDefault() {
            let view = SessionDetailViewPreview(
                title: "Architecture Review", time: "9:41 AM", duration: "42:10",
                segments: [
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "00:12", text: "So we're looking at the Vapor direction."),
                    .init(speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                          timestamp: "00:18", text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."),
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "00:35", text: "I love that metaphor. The UI should barely be there. Just the words floating in space."),
                    .init(speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                          timestamp: "00:52", text: "Right, and when we look at the transcript, it shouldn't feel like a messaging app."),
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "01:15", text: "Agreed. Let's tighten up the spacing. No bubbles, just text.")
                ],
                audioProgress: 0.3, audioTime: "12:40", isPlaying: true
            )
            CatalogHarness.capture(of: view, named: "session_detail_default",
                                   section: "Session Detail", description: "Default session with unassigned speakers, audio playing.")
        }

        @Test func testSessionDetailNamedSpeakers() {
            let view = SessionDetailViewPreview(
                title: "Team Standup", time: "10:00 AM", duration: "15:32",
                segments: [
                    .init(speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                          timestamp: "00:05", text: "Good morning everyone. Let's start with updates."),
                    .init(speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                          timestamp: "00:12", text: "I finished the API integration yesterday."),
                    .init(speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                          timestamp: "00:25", text: "Great work! Any blockers?"),
                    .init(speaker: .speaker(name: "Alex", color: VaporColor.deep),
                          timestamp: "00:32", text: "I'm waiting on the design specs for the new dashboard.")
                ],
                audioProgress: 0.5, audioTime: "7:46", isPlaying: false
            )
            CatalogHarness.capture(of: view, named: "session_detail_named_speakers",
                                   section: "Session Detail", description: "Session with named/assigned speakers.")
        }

        @Test func testSessionDetailNoAudio() {
            let view = SessionDetailViewPreview(
                title: "Quick Note", time: "3:45 PM", duration: nil,
                segments: [
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "00:00", text: "Just a quick thought about the project timeline...")
                ],
                showAudioPlayer: false
            )
            CatalogHarness.capture(of: view, named: "session_detail_no_audio",
                                   section: "Session Detail", description: "Session without audio player.")
        }

        @Test func testSessionDetailMultiLineTitle() {
            let view = SessionDetailViewPreview(
                title: "Architecture Review: Q1 Planning and Infrastructure Updates for the Mobile Team",
                time: "9:41 AM", duration: "42:10",
                segments: [
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "00:12", text: "So we're looking at the Vapor direction."),
                    .init(speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                          timestamp: "00:18", text: "Exactly. It needs to feel like breath on glass.")
                ],
                audioProgress: 0.3, audioTime: "12:40", isPlaying: true
            )
            CatalogHarness.capture(of: view, named: "session_detail_multi_line_title",
                                   section: "Session Detail", description: "Long title that wraps to multiple lines.")
        }

        @Test func testSessionDetailLongTranscript() {
            let view = SessionDetailViewPreview(
                title: "Product Planning Session", time: "2:00 PM", duration: "1:23:45",
                segments: [
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "00:00", text: "Welcome everyone to the product planning session."),
                    .init(speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                          timestamp: "00:15", text: "Thanks for organizing this. I've been working on feature proposals."),
                    .init(speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                          timestamp: "00:32", text: "Before we dive in, can we align on our key metrics?"),
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "00:48", text: "Our primary metrics are user retention, DAU, and time spent in app."),
                    .init(speaker: .speaker(name: "Alex", color: VaporColor.deep),
                          timestamp: "01:05", text: "I've been analyzing our user data. 30% drop-off at onboarding."),
                    .init(speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                          timestamp: "01:28", text: "That's concerning. What's the main friction point?"),
                    .init(speaker: .speaker(name: "Alex", color: VaporColor.deep),
                          timestamp: "01:45", text: "It's the permission request screen. Users hesitate on mic access."),
                    .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                          timestamp: "02:02", text: "We should consider progressive disclosure for permissions."),
                    .init(speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                          timestamp: "02:18", text: "That aligns with our competitor analysis."),
                    .init(speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                          timestamp: "02:35", text: "I can mock up some flows. We should A/B test the copy.")
                ],
                audioProgress: 0.65, audioTime: "54:22", isPlaying: true
            )
            CatalogHarness.capture(of: view, named: "session_detail_long_transcript",
                                   section: "Session Detail", description: "Long transcript with many segments and mixed speakers.")
        }

        @Test func testSessionDetailTranscribing() {
            let view = SessionDetailViewPreview(
                title: "Recording Session", time: "11:30 AM", duration: "5:42",
                segments: [], displayMode: .transcribing,
                showAudioPlayer: true, audioProgress: 0.0, audioTime: "0:00", isPlaying: false
            )
            CatalogHarness.capture(of: view, named: "session_detail_transcribing",
                                   section: "Session Detail", description: "Transcription in progress.")
        }

        @Test func testSessionDetailRetrying() {
            let view = SessionDetailViewPreview(
                title: "Failed Recording", time: "2:15 PM", duration: "12:30",
                segments: [], displayMode: .retrying,
                showAudioPlayer: true, audioProgress: 0.0, audioTime: "0:00", isPlaying: false
            )
            CatalogHarness.capture(of: view, named: "session_detail_retrying",
                                   section: "Session Detail", description: "Retrying transcription.")
        }

        @Test func testSessionDetailFailed() {
            let view = SessionDetailViewPreview(
                title: "Architecture Review", time: "9:41 AM", duration: "42:10",
                segments: [], displayMode: .failed,
                showAudioPlayer: true, audioProgress: 0.0, audioTime: "0:00", isPlaying: false
            )
            CatalogHarness.capture(of: view, named: "session_detail_failed",
                                   section: "Session Detail", description: "Failed transcription, no segments.")
        }

        @Test func testSessionDetailPartial() {
            let partialSegments: [SessionDetailViewPreview.SegmentData] = [
                .init(speaker: .unassigned(displayOrder: 1, color: SpeakerColor.forIndex(0).color),
                      timestamp: "00:12", text: "So we're looking at the Vapor direction."),
                .init(speaker: .unassigned(displayOrder: 2, color: SpeakerColor.forIndex(1).color),
                      timestamp: "00:18", text: "Exactly. It needs to feel like breath on glass.")
            ]
            let view = SessionDetailViewPreview(
                title: "Partial Recording", time: "3:00 PM", duration: "25:15",
                segments: [], displayMode: .partial(segments: partialSegments),
                showAudioPlayer: true, audioProgress: 0.0, audioTime: "0:00", isPlaying: false
            )
            CatalogHarness.capture(of: view, named: "session_detail_partial",
                                   section: "Session Detail", description: "Partial transcription with some segments available.")
        }

        @Test func testSessionActionsModal() {
            let view = ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack {
                    HStack {
                        Spacer()
                        SessionActionsModalPreview()
                            .frame(width: 260)
                            .padding(.trailing, 24)
                    }
                    Spacer()
                }
                .padding(.top, 100)
            }
            .frame(width: 390, height: 844)

            CatalogHarness.capture(of: view, named: "session_actions_modal",
                                   section: "Session Detail", description: "Actions menu (Share, Export, Delete).")
        }

        @Test func testDeleteConfirmationOverlay() {
            let view = ZStack {
                Color(VaporColor.mist).ignoresSafeArea()
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack(spacing: 0) {
                    Text("Delete Recording")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(VaporColor.textPrimary)
                        .padding(.top, 20).padding(.bottom, 8)
                    Text("This will permanently delete this recording and its transcript. This action cannot be undone.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(VaporColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.bottom, 20)
                    Divider().background(VaporColor.fog)
                    Text("Delete")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(VaporColor.recording)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    Divider().background(VaporColor.fog)
                    Text("Cancel")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(VaporColor.sky)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .frame(width: 270)
                .background(RoundedRectangle(cornerRadius: 14).fill(VaporColor.cloud))
            }
            .frame(width: 390, height: 844)

            CatalogHarness.capture(of: view, named: "delete_confirmation_overlay",
                                   section: "Session Detail", description: "Delete confirmation dialog overlay.")
        }
    }
}
