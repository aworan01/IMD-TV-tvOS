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
                        NavigationLink {
                            PlaylistManagementView(provider: provider)
                        } label: {
                            VStack(alignment: .leading) { Text(provider.name); Text(provider.kind.rawValue).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Button("Add Playlist", action: addProvider)
                }
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) { ForEach(IMDTheme.names, id: \.self, content: Text.init) }
                    Toggle("Show clock", isOn: $settings.showClock)
                }
                Section("Playback") {
                    Picker("Player", selection: $settings.playerMode) { ForEach(["Automatic", "AVPlayer", "KSPlayer"], id: \.self, content: Text.init) }
                    Text("Automatic uses AVPlayer for HLS, H.264 and HEVC, then KSPlayer/FFmpeg for MKV and unsupported containers.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Local Import") { Text("Start local import from Add Playlist. The page is available only on your home network and expires after ten minutes.").font(.caption).foregroundStyle(.secondary) }
                Section("About") { LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"); Text("IMD TV is a player for playlists you are authorized to use.") }
            }.navigationTitle("Settings")
        }
    }
}

private struct PlaylistManagementView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let provider: ProviderAccount
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var testing = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(provider.name).font(.largeTitle.bold())
            Text(provider.kind.rawValue).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 24) {
                action("Edit Playlist", "pencil") { editing = true }
                action("Refresh Channels", "arrow.clockwise") { Task { await library.refresh(provider) } }
                action(testing ? "Testing…" : "Test Connection", "network") { testing = true; Task { await library.refresh(provider); testing = false } }
                action("Delete Playlist", "trash", role: .destructive) { confirmingDelete = true }
            }
            Spacer()
        }.padding(70).navigationTitle("Manage Playlist")
            .sheet(isPresented: $editing) { ProviderEditorView(provider: provider) }
            .alert("Delete playlist?", isPresented: $confirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { library.remove(provider); dismiss() }
            } message: { Text("This removes the provider and its stored credentials from this Apple TV.") }
    }

    private func action(_ title: String, _ icon: String, role: ButtonRole? = nil, perform: @escaping () -> Void) -> some View {
        Button(role: role, action: perform) { Label(title, systemImage: icon).font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 110) }.buttonStyle(.borderedProminent)
    }
}

private struct ProviderEditorView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProviderAccount
    @State private var server: String
    @State private var playlist: String
    @State private var epg: String
    @State private var username: String
    @State private var password: String

    init(provider: ProviderAccount) {
        _draft = State(initialValue: provider)
        _server = State(initialValue: provider.serverURL.absoluteString)
        _playlist = State(initialValue: provider.playlistURL?.absoluteString ?? "")
        _epg = State(initialValue: provider.epgURL?.absoluteString ?? "")
        _username = State(initialValue: provider.username ?? "")
        _password = State(initialValue: provider.password ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.name)
                Picker("Type", selection: $draft.kind) { ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) } }
                if draft.kind == .m3u { TextField("M3U playlist URL", text: $playlist); TextField("XMLTV EPG URL", text: $epg) }
                else { TextField("Server URL", text: $server); TextField("Username", text: $username); SecureField("Password", text: $password) }
            }.navigationTitle("Edit Playlist")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(!valid) }
                }
        }
    }

    private var valid: Bool { draft.kind == .m3u ? URL(string: playlist) != nil : URL(string: server) != nil && !username.isEmpty && !password.isEmpty }
    @MainActor private func save() async {
        if draft.kind == .m3u, let url = URL(string: playlist) {
            draft.serverURL = url.deletingLastPathComponent(); draft.playlistURL = url
            draft.epgURL = URL(string: epg); draft.username = nil; draft.password = nil
        } else if let url = URL(string: server) {
            draft.serverURL = url; draft.playlistURL = nil; draft.epgURL = nil
            draft.username = username; draft.password = password
        }
        await library.update(draft); dismiss()
    }
}

