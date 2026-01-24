import SwiftUI
import ComposableArchitecture
import TimelineFeature

@main
struct VaporApp: App {
    static let store: StoreOf<AppFeature> = {
        let environment = AppEnvironment.current
        return Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppView(store: VaporApp.store)
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

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
        }
    }
}

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>

    var body: some View {
        NavigationStack {
            VStack {
                Text("Timeline")
            }
            .navigationTitle("Timeline")
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
