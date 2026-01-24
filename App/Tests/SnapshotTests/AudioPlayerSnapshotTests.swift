import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Audio Player Snapshot Tests

@Suite("Audio Player Component Snapshots")
@MainActor
struct AudioPlayerSnapshotTests {

    @Test func testAudioPlayerDefault() {
        let view = VStack(alignment: .leading, spacing: 32) {
            // Paused state (default)
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Paused State")
                AudioPlayerPreview(
                    title: "Playing Audio",
                    currentTime: "12:40",
                    progress: 0.3,
                    isPlaying: false
                )
            }

            // Playing state
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Playing State")
                AudioPlayerPreview(
                    title: "Playing Audio",
                    currentTime: "12:40",
                    progress: 0.3,
                    isPlaying: true
                )
            }

            // Different progress
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Mid-progress")
                AudioPlayerPreview(
                    title: "Architecture Review",
                    currentTime: "21:05",
                    progress: 0.5,
                    isPlaying: true
                )
            }

            // Near end
            VStack(alignment: .leading, spacing: 8) {
                CaptionText("Near End")
                AudioPlayerPreview(
                    title: "Morning Reflection",
                    currentTime: "42:08",
                    progress: 0.95,
                    isPlaying: true
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "audio_player_default")
    }

    @Test func testAudioPlayerInContext() {
        // Audio player at bottom of a mock screen
        let view = VStack(spacing: 0) {
            // Mock content area
            VStack(alignment: .leading, spacing: 16) {
                BodyText("So we're looking at the Vapor direction.")
                BodyText("Exactly. It needs to feel like breath on glass.")
                BodyText("I love that metaphor.")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Audio player at bottom
            AudioPlayerPreview(
                title: "Playing Audio",
                currentTime: "12:40",
                progress: 0.3,
                isPlaying: true
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(height: 400)
        .background(VaporColor.mist)

        SnapshotHarness.assertSnapshot(of: view, named: "audio_player_in_context")
    }
}
