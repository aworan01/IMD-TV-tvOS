import SwiftUI

struct RootView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var selection: Destination = .live
    @State private var showingAddProvider = false

    enum Destination: String, CaseIterable, Identifiable {
        case live = "Live TV", guide = "Guide", favourites = "Favourites", search = "Search", settings = "Settings"
        var id: String { rawValue }
        var symbol: String {
            switch self { case .live: "tv"; case .guide: "calendar"; case .favourites: "heart"; case .search: "magnifyingglass"; case .settings: "gearshape" }
        }
    }

    var body: some View {
        let palette = IMDTheme.palette(named: settings.theme)
        ZStack {
            palette.gradient.ignoresSafeArea()
            if library.providers.isEmpty && !library.isLoading {
                WelcomeView { showingAddProvider = true }
            } else {
                TabView(selection: $selection) {
                    LiveView().tag(Destination.live).tabItem { Label("Live TV", systemImage: "tv") }
                    GuideView().tag(Destination.guide).tabItem { Label("Guide", systemImage: "calendar") }
                    ChannelGridView(title: "Favourites", channels: library.favourites).tag(Destination.favourites)
                        .tabItem { Label("Favourites", systemImage: "heart") }
                    SearchView().tag(Destination.search).tabItem { Label("Search", systemImage: "magnifyingglass") }
                    SettingsView(addProvider: { showingAddProvider = true }).tag(Destination.settings)
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            }
            if library.isLoading { ProgressView("Loading your channels…").controlSize(.large).glassPanel().padding(40) }
        }
        .environment(\.imdPalette, palette)
        .tint(palette.accent)
        .sheet(isPresented: $showingAddProvider) { ProviderSetupView().environment(\.imdPalette, palette).tint(palette.accent) }
        .fullScreenCover(item: $library.selectedChannel) { PlayerScreen(channel: $0) }
        .alert("Couldn’t load provider", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(library.errorMessage ?? "Unknown error") }
    }
}

private struct WelcomeView: View {
    let addProvider: () -> Void
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "tv.and.mediabox").font(.system(size: 110)).foregroundStyle(.tint, .purple)
            Text("IMD TV").font(.system(size: 72, weight: .bold, design: .rounded))
            Text("Your playlists. Your guide. Your Apple TV.").font(.title2).foregroundStyle(.secondary)
            Button(action: addProvider) { Label("Add a playlist", systemImage: "plus") }.buttonStyle(.borderedProminent)
        }
    }
}

