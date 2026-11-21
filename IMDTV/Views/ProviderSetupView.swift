import SwiftUI

struct ProviderSetupView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .manual
    @State private var kind: ProviderKind = .m3u
    @State private var name = "My TV"
    @State private var server = ""
    @State private var playlist = ""
    @State private var epg = ""
    @State private var username = ""
    @State private var password = ""
    @State private var code = ""
    @State private var status = ""
    @StateObject private var localServer = LocalImportServer()

    enum Mode: String, CaseIterable { case manual = "Enter details", pairing = "Import from phone" }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Setup", selection: $mode) { ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if mode == .manual { manualFields } else { pairingView }
            }.navigationTitle("Add Playlist")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .onDisappear { localServer.stop() }
    }

    @ViewBuilder private var manualFields: some View {
        Picker("Type", selection: $kind) { ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) } }
        TextField("Name", text: $name)
        if kind == .m3u { TextField("M3U playlist URL", text: $playlist); TextField("XMLTV EPG URL (optional)", text: $epg) }
        else { TextField("Server URL", text: $server); TextField("Username", text: $username); SecureField("Password", text: $password) }
        Button("Import Playlist") { Task { await saveManual() } }.disabled(!valid)
    }

    private var pairingView: some View {
        Section {
            if localServer.address == nil { Button("Start Local Import") { beginLocalImport() } }
            else {
                VStack(spacing: 22) {
                    Text(localServer.code).font(.system(size: 64, weight: .bold, design: .monospaced)).tracking(8)
                    Text(localServer.address ?? "").font(.title3.monospaced()).textSelection(.enabled)
                    Text("Open this address on a phone or computer connected to the same home network.")
                    ProgressView(localServer.status)
                    Button("Stop Import", role: .destructive) { localServer.stop() }
                }.frame(maxWidth: .infinity).padding(30)
            }
        } header: { Text("Local Network Import") }
    }

    private var valid: Bool { kind == .m3u ? URL(string: playlist) != nil : URL(string: server) != nil && !username.isEmpty && !password.isEmpty }
    private func saveManual() async {
        guard let base = URL(string: kind == .m3u ? (URL(string: playlist)?.deletingLastPathComponent().absoluteString ?? playlist) : server) else { return }
        let account = ProviderAccount(name: name, kind: kind, serverURL: base, playlistURL: URL(string: playlist), epgURL: URL(string: epg), username: username.nilIfEmpty, password: password.nilIfEmpty)
        await library.add(account); dismiss()
    }
    private func beginLocalImport() {
        localServer.onPayload = { payload in Task { await importPayload(payload) } }
        localServer.start()
    }
    @MainActor private func importPayload(_ payload: PairingPayload) async {
        let base = payload.serverURL.flatMap(URL.init(string:))
            ?? payload.playlistURL.flatMap(URL.init(string:))?.deletingLastPathComponent()
        guard let base else { status = "The imported URLs are invalid."; return }
        let account = ProviderAccount(name: payload.name, kind: payload.provider, serverURL: base,
            playlistURL: payload.playlistURL.flatMap(URL.init(string:)), epgURL: payload.epgURL.flatMap(URL.init(string:)), username: payload.username, password: payload.password)
        await library.add(account); dismiss()
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

