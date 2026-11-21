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
    @State private var isImporting = false
    @StateObject private var localServer = LocalImportServer()

    enum Mode: String, CaseIterable, Identifiable {
        case m3uURL = "M3U URL", xtream = "Xtream Codes", localFile = "Local File", phone = "Phone / PC"
        var id: String { rawValue }
        var symbol: String { switch self { case .m3uURL: "link"; case .xtream: "person.badge.key"; case .localFile: "doc"; case .phone: "iphone.and.arrow.forward" } }
    }

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(Mode.allCases) { item in
                    Button { mode = item } label: {
                        HStack {
                            Label(item.rawValue, systemImage: item.symbol)
                            Spacer()
                            if mode == item { Image(systemName: "checkmark") }
                        }
                    }
                }
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
            Button("Import Playlist") { Task { await saveM3U() } }.buttonStyle(.borderedProminent).disabled(ImportValidation.webURL(playlist) == nil || isImporting)
        }
    }

    private var xtreamPanel: some View {
        panel(title: "Xtream Codes", detail: "Use the server address and credentials supplied by your provider.") {
            TextField("Playlist name", text: $name); TextField("Server URL", text: $server); TextField("Username", text: $username); SecureField("Password", text: $password)
            Button("Sign In and Import") { Task { await saveXtream() } }.buttonStyle(.borderedProminent).disabled(ImportValidation.webURL(server) == nil || username.isEmpty || password.isEmpty || isImporting)
        }
    }

    private var localPanel: some View {
        panel(title: mode == .localFile ? "Upload a Playlist File" : "Import from Phone or PC", detail: "Connect a phone or computer to the same network, then open the address shown below. You can upload an M3U file or enter provider details.") {
            VStack(alignment: .leading, spacing: 18) {
                if !localServer.code.isEmpty {
                    Text(localServer.code).font(.system(size: 44, weight: .semibold, design: .monospaced)).tracking(6)
                }
                if let address = localServer.address {
                    Text(address).font(.body.monospaced())
                    Text("Open this exact address on a phone or computer connected to the same home network.")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    if localServer.address == nil {
                        Button(localServer.code.isEmpty ? "Start Local Import" : "Retry") { beginLocalImport() }
                            .buttonStyle(.borderedProminent)
                            .disabled(isImporting)
                    }
                    if !localServer.code.isEmpty {
                        Button("Stop", role: .destructive) { localServer.stop() }
                    }
                }
                Label(localServer.status, systemImage: localServer.address == nil ? "network.slash" : "network")
                    .font(.callout)
                    .foregroundStyle(localServer.address == nil ? .orange : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
    }

    private func panel<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        Form {
            Section { Text(detail).font(.body).foregroundStyle(.secondary) }
            Section { content() }
            if isImporting { Section { ProgressView("Importing playlist…") } }
            if !status.isEmpty { Section { Text(status).foregroundStyle(.orange) } }
        }
    }
    private func saveM3U() async {
        guard let url = ImportValidation.webURL(playlist) else { return }
        guard epg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ImportValidation.webURL(epg) != nil else {
            status = "Enter a complete http:// or https:// guide URL, or leave it blank."; return
        }
        let account = ProviderAccount(name: name, kind: .m3u, serverURL: url.deletingLastPathComponent(), playlistURL: url, epgURL: ImportValidation.webURL(epg))
        await save(account)
    }
    private func saveXtream() async {
        guard let base = ImportValidation.webURL(server) else { return }
        let account = ProviderAccount(name: name, kind: .xtream, serverURL: base, username: username.nilIfEmpty, password: password.nilIfEmpty)
        await save(account)
    }
    private func beginLocalImport() {
        status = ""
        localServer.onPayload = { payload in Task { await importPayload(payload) } }
        localServer.start()
    }
    @MainActor private func importPayload(_ payload: PairingPayload) async {
        if let content = payload.playlistContent {
            guard let url = saveLocalPlaylist(content) else { return }
            let account = ProviderAccount(name: payload.name, kind: .m3u, serverURL: url.deletingLastPathComponent(), playlistURL: url, epgURL: ImportValidation.webURL(payload.epgURL))
            await save(account); return
        }
        let base = payload.provider == .xtream ? ImportValidation.webURL(payload.serverURL)
            : ImportValidation.webURL(payload.playlistURL)?.deletingLastPathComponent()
        guard let base else { status = "The imported URLs are invalid."; return }
        let account = ProviderAccount(name: payload.name, kind: payload.provider, serverURL: base,
            playlistURL: ImportValidation.webURL(payload.playlistURL), epgURL: ImportValidation.webURL(payload.epgURL), username: payload.username, password: payload.password)
        await save(account)
    }

    @MainActor private func save(_ account: ProviderAccount) async {
        guard !isImporting else { return }
        isImporting = true; status = ""
        defer { isImporting = false }
        if await library.add(account) { dismiss() }
        else {
            status = library.errorMessage ?? "The playlist could not be imported. Please retry."
            library.errorMessage = nil
        }
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

