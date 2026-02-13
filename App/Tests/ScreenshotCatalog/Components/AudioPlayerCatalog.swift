import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Audio Player Catalog

extension CatalogBase {
    @Suite("Audio Player Components")
    @MainActor
    struct AudioPlayerCatalog {

        @Test func testAudioPlayerStates() {
            let view = VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Paused State")
                    AudioPlayerPreview(title: "Playing Audio", currentTime: "12:40", progress: 0.3, isPlaying: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Playing State")
                    AudioPlayerPreview(title: "Playing Audio", currentTime: "12:40", progress: 0.3, isPlaying: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Mid-progress")
                    AudioPlayerPreview(title: "Architecture Review", currentTime: "21:05", progress: 0.5, isPlaying: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CaptionText("Near End")
                    AudioPlayerPreview(title: "Morning Reflection", currentTime: "42:08", progress: 0.95, isPlaying: true)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "audio_player_states",
                                   section: "Components", description: "Audio player in paused, playing, mid-progress, and near-end states.")
        }

        @Test func testAudioPlayerInContext() {
            let view = VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    BodyText("So we're looking at the Vapor direction.")
                    BodyText("Exactly. It needs to feel like breath on glass.")
                    BodyText("I love that metaphor.")
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                AudioPlayerPreview(title: "Playing Audio", currentTime: "12:40", progress: 0.3, isPlaying: true)
                    .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .frame(height: 400)
            .background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "audio_player_in_context",
                                   section: "Components", description: "Audio player at bottom of mock screen.")
        }
    }
}
