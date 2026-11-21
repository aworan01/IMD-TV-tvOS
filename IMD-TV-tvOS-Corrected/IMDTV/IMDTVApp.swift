import SwiftUI

@main
struct IMDTVApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .task { await library.restore() }
                .onOpenURL { library.handleDeepLink($0) }
        }
    }
}

