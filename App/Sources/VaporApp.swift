import SwiftUI
import ComposableArchitecture
import TimelineFeature

@main
struct VaporApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Vapor")
    }
}
