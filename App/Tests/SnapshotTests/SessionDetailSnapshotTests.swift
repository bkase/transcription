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
}
