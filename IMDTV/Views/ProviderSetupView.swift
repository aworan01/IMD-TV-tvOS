import SwiftUI

struct ProviderSetupView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .m3uURL
    @State private var name = "My TV"
    @State private var server = ""
    @State private var playlist = ""
    @State private var epg = ""
    @State private var username = ""
    @State private var password = ""
    @State private var status = ""
    @StateObject private var localServer = LocalImportServer()

    enum Mode: String, CaseIterable, Identifiable {
        case m3uURL = "M3U URL", xtream = "Xtream Codes", localFile = "Local File", phone = "Phone / PC"
        var id: String { rawValue }
        var symbol: String { switch self { case .m3uURL: "link"; case .xtream: "person.badge.key"; case .localFile: "doc"; case .phone: "iphone.and.arrow.forward" } }
    }

    var body: some View {
        NavigationSplitView {
            List(Mode.allCases, selection: $mode) { item in
                Label(item.rawValue, systemImage: item.symbol).tag(item)
            }
            .navigationTitle("Add Playlist")
        } detail: {
            NavigationStack {
                Group { switch mode { case .m3uURL: m3uPanel; case .xtream: xtreamPanel; case .localFile, .phone: localPanel } }
                    .navigationTitle(mode.rawValue)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            }
        }
        .onDisappear { localServer.stop() }
    }

    private var m3uPanel: some View {
        panel(title: "Import M3U URL", detail: "Enter a remote M3U or M3U8 playlist and optional XMLTV guide.") {
            TextField("Playlist name", text: $name); TextField("https://provider.example/playlist.m3u", text: $playlist); TextField("XMLTV guide URL (optional)", text: $epg)
            Button("Import Playlist") { Task { await saveM3U() } }.buttonStyle(.borderedProminent).disabled(URL(string: playlist) == nil)
        }
    }

    private var xtreamPanel: some View {
        panel(title: "Xtream Codes", detail: "Use the server address and credentials supplied by your provider.") {
            TextField("Playlist name", text: $name); TextField("Server URL", text: $server); TextField("Username", text: $username); SecureField("Password", text: $password)
            Button("Sign In and Import") { Task { await saveXtream() } }.buttonStyle(.borderedProminent).disabled(URL(string: server) == nil || username.isEmpty || password.isEmpty)
        }
    }

    private var localPanel: some View {
        panel(title: mode == .localFile ? "Upload a Playlist File" : "Import from Phone or PC", detail: "Connect a phone or computer to the same network, then open the address shown below. You can upload an M3U file or enter provider details.") {
            if localServer.address == nil { Button("Start Local Import") { beginLocalImport() } }
            else {
                VStack(spacing: 22) {
                    Text(localServer.code).font(.system(size: 64, weight: .bold, design: .monospaced)).tracking(8)
                    Text(localServer.address ?? "").font(.title3.monospaced())
                    Text("Open this address on a phone or computer connected to the same home network.")
                    ProgressView(localServer.status)
                    Button("Stop Import", role: .destructive) { localServer.stop() }
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
    }

    private func panel<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        Form {
            Section { Text(detail).font(.body).foregroundStyle(.secondary) }
            Section { content() }
        }
    }
    private func saveM3U() async {
        guard let url = URL(string: playlist) else { return }
        let account = ProviderAccount(name: name, kind: .m3u, serverURL: url.deletingLastPathComponent(), playlistURL: url, epgURL: URL(string: epg))
        await library.add(account); dismiss()
    }
    private func saveXtream() async {
        guard let base = URL(string: server) else { return }
        let account = ProviderAccount(name: name, kind: .xtream, serverURL: base, username: username.nilIfEmpty, password: password.nilIfEmpty)
        await library.add(account); dismiss()
    }
    private func beginLocalImport() {
        localServer.onPayload = { payload in Task { await importPayload(payload) } }
        localServer.start()
    }
    @MainActor private func importPayload(_ payload: PairingPayload) async {
        if let content = payload.playlistContent, let url = saveLocalPlaylist(content) {
            let account = ProviderAccount(name: payload.name, kind: .m3u, serverURL: url.deletingLastPathComponent(), playlistURL: url, epgURL: payload.epgURL.flatMap(URL.init(string:)))
            await library.add(account); dismiss(); return
        }
        let base = payload.serverURL.flatMap(URL.init(string:))
            ?? payload.playlistURL.flatMap(URL.init(string:))?.deletingLastPathComponent()
        guard let base else { status = "The imported URLs are invalid."; return }
        let account = ProviderAccount(name: payload.name, kind: payload.provider, serverURL: base,
            playlistURL: payload.playlistURL.flatMap(URL.init(string:)), epgURL: payload.epgURL.flatMap(URL.init(string:)), username: payload.username, password: payload.password)
        await library.add(account); dismiss()
    }

    private func saveLocalPlaylist(_ content: String) -> URL? {
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Playlists", isDirectory: true)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            let url = base.appendingPathComponent("\(UUID().uuidString).m3u")
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch { status = "Could not save the uploaded playlist: \(error.localizedDescription)"; return nil }
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

