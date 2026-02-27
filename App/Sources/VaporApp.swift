import SwiftUI
import ComposableArchitecture
import TimelineFeature
import RecordingFeature
import SessionDetailFeature
import PeopleFeature
import ProfileFeature
import PersonTimelineFeature
import Dependencies
import Audio
import Processing
import Persistence
import DesignSystem

@main
struct VaporApp: App {
    static let store: StoreOf<AppFeature> = {
        let environment = AppEnvironment.current

        switch environment {
        case .live:
            return Store(initialState: AppFeature.State()) {
                AppFeature()
            }

        case .uiTesting(let scenario):
            // Create in-memory database for testing
            let dbQueue = try! makeDatabase(configuration: .inMemory)
            let databaseClient = DatabaseClient.live(dbQueue: dbQueue)
            // Create in-memory profile storage for testing
            let profileStorage = InMemoryProfileStorage()

            // Determine FluidAudioClient based on scenario
            let fluidAudioClient: FluidAudioClient = {
                switch scenario {
                case .normal:
                    return MockFluidAudioClient.twoSpeakerConversation
                case .modelDownloadFailure:
                    return MockFluidAudioClient.failed(message: "Unable to download models. Please check your connection.")
                case .transcriptionFailure:
                    return MockFluidAudioClient.offlineFailure(
                        script: .twoSpeakerConversation,
                        errorMessage: "Transcription failed: audio processing error"
                    )
                }
            }()

            // Inject mock dependencies for deterministic E2E tests
            return withDependencies {
                // Use generated audio capture for deterministic audio (short duration for faster tests)
                $0.audioCaptureClient = .generated(config: .silent(durationSeconds: 2))
                // Use mock transcription client based on scenario
                $0.fluidAudioClient = fluidAudioClient
                // Use in-memory database
                $0.databaseClient = databaseClient
                // Use in-memory profile client for profile tests
                $0.userProfileClient = .inMemory(storage: profileStorage)
                // Use passthrough image client (no actual image processing in tests)
                $0.profileImageClient = .passthrough
                // Use no-op feedback client (AVAudioEngine crashes on headless simulator)
                $0.feedbackClient = .previewValue
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
            NavigationStack(
                path: $store.scope(state: \.path, action: \.path)
            ) {
                TimelineView(store: store.scope(state: \.timeline, action: \.timeline))
                    .navigationBarHidden(true)
            } destination: { store in
                switch store.case {
                case let .sessionDetail(sessionDetailStore):
                    SessionDetailView(store: sessionDetailStore)
                        .navigationBarHidden(true)
                case let .profile(profileStore):
                    ProfileView(store: profileStore)
                        .navigationBarHidden(true)
                case let .personTimeline(personTimelineStore):
                    PersonTimelineView(store: personTimelineStore)
                        .navigationBarHidden(true)
                case let .people(peopleStore):
                    PeopleView(store: peopleStore)
                        .navigationBarHidden(true)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onOpenURL { url in
                store.send(.deepLinkOpened(url))
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
