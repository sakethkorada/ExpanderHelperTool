import SwiftUI

@main
struct ExpanderTrackerApp: App {
    @StateObject private var store = ExpanderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.settings.appearanceMode.preferredColorScheme)
        }
    }
}

private extension AppAppearanceMode {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
