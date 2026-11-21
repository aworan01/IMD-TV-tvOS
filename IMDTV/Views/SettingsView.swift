import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore
    let addProvider: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Playlists") {
                    ForEach(library.providers) { provider in
                        HStack { VStack(alignment: .leading) { Text(provider.name); Text(provider.kind.rawValue).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Refresh") { Task { await library.refresh(provider) } } }
                    }.onDelete(perform: library.deleteProviders)
                    Button("Add Playlist", action: addProvider)
                }
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) { ForEach(["Celestial Glass", "Celestial +", "Celestial Retro", "Liquid Glass", "Xcube 360", "Gamestation"], id: \.self, content: Text.init) }
                    Toggle("Show clock", isOn: $settings.showClock)
                }
                Section("Playback") {
                    Picker("Player", selection: $settings.playerMode) { ForEach(["Automatic", "AVPlayer", "KSPlayer"], id: \.self, content: Text.init) }
                    Text("Automatic uses AVPlayer for HLS, H.264 and HEVC, then KSPlayer/FFmpeg for MKV and unsupported containers.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Web Import") { TextField("Pairing service URL", text: $settings.pairingEndpoint) }
                Section("About") { LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"); Text("IMD TV is a player for playlists you are authorized to use.") }
            }.navigationTitle("Settings")
        }
    }
}

