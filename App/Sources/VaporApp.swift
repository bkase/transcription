import SwiftUI
import ComposableArchitecture
import TimelineFeature
import RecordingFeature
import Dependencies
import Audio
import Processing
import Persistence

@main
struct VaporApp: App {
    static let store: StoreOf<AppFeature> = {
        let environment = AppEnvironment.current

        switch environment {
        case .live:
            return Store(initialState: AppFeature.State()) {
                AppFeature()
            }

        case .uiTesting:
            // Create in-memory database for testing
            let dbQueue = try! makeDatabase(configuration: .inMemory)
            let databaseClient = DatabaseClient.live(dbQueue: dbQueue)

            // Inject mock dependencies for deterministic E2E tests
            return withDependencies {
                // Use generated audio capture for deterministic audio (short duration for faster tests)
                $0.audioCaptureClient = .generated(config: .silent(durationSeconds: 2))
                // Use mock transcription client with scripted segments
                $0.fluidAudioClient = MockFluidAudioClient.twoSpeakerConversation
                // Use in-memory database
                $0.databaseClient = databaseClient
            } operation: {
                Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppView(store: VaporApp.store)
        }
    }
}

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    var body: some View {
        WithPerceptionTracking {
            TabView(selection: Binding(
                get: { store.currentTab },
                set: { store.send(.tabSelected($0)) }
            )) {
                TimelineView(store: store.scope(state: \.timeline, action: \.timeline))
                    .tabItem {
                        Label("Timeline", systemImage: "list.bullet")
                    }
                    .tag(AppFeature.Tab.timeline)
            }
            .onAppear {
                store.send(.onAppear)
            }
            .fullScreenCover(
                item: $store.scope(state: \.recording, action: \.recording)
            ) { recordingStore in
                RecordingView(store: recordingStore) {
                    store.send(.dismissRecording)
                }
            }
        }
    }
}
