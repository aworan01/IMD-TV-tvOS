import SwiftUI

struct ProviderSetupView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore
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

    enum Mode: String, CaseIterable { case manual = "Enter details", pairing = "Import with code" }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Setup", selection: $mode) { ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if mode == .manual { manualFields } else { pairingView }
            }.navigationTitle("Add Playlist")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
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
            if code.isEmpty { Button("Generate Import Code") { Task { await beginPairing() } } }
            else {
                VStack(spacing: 22) {
                    Text(code).font(.system(size: 70, weight: .bold, design: .monospaced)).tracking(10)
                    Text("Open the pairing web page on your phone, enter this code, then submit your playlist.")
                    ProgressView(status)
                }.frame(maxWidth: .infinity).padding(30)
            }
        } header: { Text("Secure Web Import") }
    }

    private var valid: Bool { kind == .m3u ? URL(string: playlist) != nil : URL(string: server) != nil && !username.isEmpty && !password.isEmpty }
    private func saveManual() async {
        guard let base = URL(string: kind == .m3u ? (URL(string: playlist)?.deletingLastPathComponent().absoluteString ?? playlist) : server) else { return }
        let account = ProviderAccount(name: name, kind: kind, serverURL: base, playlistURL: URL(string: playlist), epgURL: URL(string: epg), username: username.nilIfEmpty, password: password.nilIfEmpty)
        await library.add(account); dismiss()
    }
    private func beginPairing() async {
        guard let endpoint = URL(string: settings.pairingEndpoint) else { status = "Configure the endpoint in Settings"; return }
        do {
            let service = PairingService(endpoint: endpoint); code = try await service.createCode(); status = "Waiting for web import…"
            for _ in 0..<120 {
                try await Task.sleep(for: .seconds(2))
                if let payload = try await service.poll(code: code) { await importPayload(payload); return }
            }
            status = "Code expired. Generate a new one."
        } catch { status = error.localizedDescription }
    }
    private func importPayload(_ payload: PairingPayload) async {
        let base = URL(string: payload.serverURL ?? "") ?? URL(string: payload.playlistURL ?? "")!.deletingLastPathComponent()
        guard let base else { status = "The imported URLs are invalid."; return }
        let account = ProviderAccount(name: payload.name, kind: payload.provider, serverURL: base,
            playlistURL: payload.playlistURL.flatMap(URL.init(string:)), epgURL: payload.epgURL.flatMap(URL.init(string:)), username: payload.username, password: payload.password)
        await library.add(account); dismiss()
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

