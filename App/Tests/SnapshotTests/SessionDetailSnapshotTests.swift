import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem
@testable import SessionDetailFeature

// MARK: - Session Detail View Snapshot Tests

@Suite("Session Detail Snapshots")
@MainActor
struct SessionDetailSnapshotTests {

    @Test func testSessionDetailDefault() {
        // Default state: session with transcript and audio player
        let view = SessionDetailViewPreview(
            title: "Architecture Review",
            time: "9:41 AM",
            duration: "42:10",
            segments: [
                .init(
                    speaker: .user,
                    timestamp: "00:12",
                    text: "So we're looking at the Vapor direction."
                ),
                .init(
                    speaker: .guest,
                    timestamp: "00:18",
                    text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved."
                ),
                .init(
                    speaker: .user,
                    timestamp: "00:35",
                    text: "I love that metaphor. The UI should barely be there. Just the words floating in space."
                ),
                .init(
                    speaker: .guest,
                    timestamp: "00:52",
                    text: "Right, and when we look at the transcript, it shouldn't feel like a messaging app. It should feel like a script. A record."
                ),
                .init(
                    speaker: .user,
                    timestamp: "01:15",
                    text: "Agreed. Let's tighten up the spacing. No bubbles, just text."
                )
            ],
            audioProgress: 0.3,
            audioTime: "12:40",
            isPlaying: true
        )

        SnapshotHarness.assertSnapshot(of: view, named: "session_detail_default")
    }

    @Test func testSessionDetailWithCustomSpeakers() {
        // Session with named speakers (not just YOU/GUEST)
        let view = SessionDetailViewPreview(
            title: "Team Standup",
            time: "10:00 AM",
            duration: "15:32",
            segments: [
                .init(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "00:05",
                    text: "Good morning everyone. Let's start with updates."
                ),
                .init(
                    speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                    timestamp: "00:12",
                    text: "I finished the API integration yesterday."
                ),
                .init(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "00:25",
                    text: "Great work! Any blockers?"
                ),
                .init(
                    speaker: .speaker(name: "Alex", color: VaporColor.deep),
                    timestamp: "00:32",
                    text: "I'm waiting on the design specs for the new dashboard."
                )
            ],
            audioProgress: 0.5,
            audioTime: "7:46",
            isPlaying: false
        )

        SnapshotHarness.assertSnapshot(of: view, named: "session_detail_custom_speakers")
    }

    @Test func testSessionDetailNoAudioPlayer() {
        // Session without audio (no audio player shown)
        let view = SessionDetailViewPreview(
            title: "Quick Note",
            time: "3:45 PM",
            duration: nil,
            segments: [
                .init(
                    speaker: .user,
                    timestamp: "00:00",
                    text: "Just a quick thought about the project timeline..."
                )
            ],
            showAudioPlayer: false
        )

        SnapshotHarness.assertSnapshot(of: view, named: "session_detail_no_audio")
    }

    @Test func testSessionDetailLongTranscript() {
        // Session with long transcript (many segments) and audio player visible
        let view = SessionDetailViewPreview(
            title: "Product Planning Session",
            time: "2:00 PM",
            duration: "1:23:45",
            segments: [
                .init(
                    speaker: .user,
                    timestamp: "00:00",
                    text: "Welcome everyone to the product planning session. Today we'll be discussing our roadmap for the next quarter."
                ),
                .init(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "00:15",
                    text: "Thanks for organizing this. I've been working on some feature proposals that I think will really move the needle."
                ),
                .init(
                    speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                    timestamp: "00:32",
                    text: "Before we dive in, can we align on our key metrics? I want to make sure we're all optimizing for the same outcomes."
                ),
                .init(
                    speaker: .user,
                    timestamp: "00:48",
                    text: "Great point. Our primary metrics are user retention, daily active users, and time spent in app."
                ),
                .init(
                    speaker: .speaker(name: "Alex", color: VaporColor.deep),
                    timestamp: "01:05",
                    text: "I've been analyzing our user data. We're seeing a drop-off at the onboarding stage. About 30% of new users don't complete setup."
                ),
                .init(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "01:28",
                    text: "That's concerning. What's the main friction point? Is it the account creation or the tutorial?"
                ),
                .init(
                    speaker: .speaker(name: "Alex", color: VaporColor.deep),
                    timestamp: "01:45",
                    text: "It's actually the permission request screen. Users are hesitant to grant microphone access upfront."
                ),
                .init(
                    speaker: .user,
                    timestamp: "02:02",
                    text: "We should consider progressive disclosure. Only ask for permissions when the user actually needs them."
                ),
                .init(
                    speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                    timestamp: "02:18",
                    text: "That aligns with our competitor analysis. The top apps in our category all use contextual permission requests."
                ),
                .init(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "02:35",
                    text: "I can mock up some flows for this. We should also A/B test the copy on the permission dialog."
                ),
                .init(
                    speaker: .user,
                    timestamp: "02:52",
                    text: "Perfect. Let's add this to the sprint. Alex, can you set up the analytics events for tracking?"
                ),
                .init(
                    speaker: .speaker(name: "Alex", color: VaporColor.deep),
                    timestamp: "03:10",
                    text: "Already on it. I'll have the tracking plan ready by end of day tomorrow."
                ),
                .init(
                    speaker: .speaker(name: "Marcus", color: VaporColor.lavender),
                    timestamp: "03:25",
                    text: "Moving on to the next item - we need to discuss the export feature. Users have been requesting more format options."
                ),
                .init(
                    speaker: .user,
                    timestamp: "03:42",
                    text: "Yes, markdown export has been our most requested feature for three months now."
                ),
                .init(
                    speaker: .speaker(name: "Sarah", color: VaporColor.sky),
                    timestamp: "04:00",
                    text: "The technical implementation is straightforward. We can ship this in two weeks if we prioritize it."
                )
            ],
            audioProgress: 0.65,
            audioTime: "54:22",
            isPlaying: true
        )

        SnapshotHarness.assertSnapshot(of: view, named: "session_detail_long_transcript")
    }
}
