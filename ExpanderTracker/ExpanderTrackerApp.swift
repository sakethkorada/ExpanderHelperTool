import SwiftUI

@main
struct ExpanderTrackerApp: App {
    @StateObject private var store = ExpanderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
