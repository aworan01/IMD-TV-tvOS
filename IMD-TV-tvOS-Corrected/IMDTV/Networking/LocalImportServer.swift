import Foundation
import Network
import Darwin

final class LocalImportServer: ObservableObject, @unchecked Sendable {
    @Published private(set) var address: String?
    @Published private(set) var code = ""
    @Published private(set) var status = "Not running"

    private var listener: NWListener?
    private var addressTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "org.imdtv.local-import")
    private var expirationTask: Task<Void, Never>?
    var onPayload: (@MainActor (PairingPayload) -> Void)?

    func start() {
        stop()
        code = Self.makeCode()
        status = "Starting local import…"
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self else { return }
                Task { @MainActor in
                    guard let listener, self.listener === listener else { return }
                    switch state {
                    case .ready:
                        guard let port = listener.port else {
                            self.status = "The import server started without a usable port."; return
                        }
                        self.resolveAddress(port: port.rawValue)
                    case .failed(let error):
                        self.stop()
                        self.status = "Local import failed: \(error.localizedDescription)"
                    case .cancelled: if self.address != nil { self.status = "Import server stopped" }
                    default: break
                    }
                }
            }
            listener.start(queue: queue)
            expirationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(600))
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.stop(); self?.status = "Import code expired. Select Retry to generate a new code." }
            }
        } catch { status = "Could not start local import: \(error.localizedDescription)" }
    }

    func stop() {
        expirationTask?.cancel(); expirationTask = nil
        addressTask?.cancel(); addressTask = nil
        stopListenerOnly(); address = nil
        status = "Import server stopped"
    }

    private func stopListenerOnly() { listener?.cancel(); listener = nil }

    @MainActor private func resolveAddress(port: UInt16) {
        addressTask?.cancel()
        status = "Server started. Looking for the Apple TV network address…"
        addressTask = Task { [weak self] in
            for _ in 0..<12 {
                guard !Task.isCancelled, let self else { return }
                if let ip = Self.localIPv4Address() {
                    self.address = "http://\(ip):\(port)/\(self.code)"
                    self.status = "Waiting for playlist details…"
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard let self, !Task.isCancelled else { return }
            self.status = "No local IP was found. Check Local Network permission and confirm this Apple TV is connected by Wi-Fi or Ethernet, then retry."
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }

    private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var buffer = accumulated
            if let data { buffer.append(data) }
            // URL-encoded form data can occupy three bytes per uploaded byte.
            if buffer.count > 16_000_000 { self.send(connection, status: "413 Content Too Large", body: "Playlist files are limited to 5 MB.", contentType: "text/plain"); return }
            if self.requestIsComplete(buffer) || complete || error != nil { self.respond(to: connection, request: buffer) }
            else { self.receive(on: connection, accumulated: buffer) }
        }
    }

    private func requestIsComplete(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8), let headerEnd = text.range(of: "\r\n\r\n") else { return false }
        let headers = text[..<headerEnd.lowerBound]
        let length = headers.split(separator: "\n").first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") } ?? 0
        return text[headerEnd.upperBound...].utf8.count >= length
    }

    private func respond(to connection: NWConnection, request data: Data) {
        guard let request = String(data: data, encoding: .utf8), let first = request.components(separatedBy: "\r\n").first else {
            send(connection, status: "400 Bad Request", body: "Invalid request", contentType: "text/plain"); return
        }
        let parts = first.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.count > 1 ? String(parts[1]) : "/"
        guard path == "/\(code)" || path == "/\(code)/submit" else {
            send(connection, status: "404 Not Found", body: "This import code is invalid or expired.", contentType: "text/plain"); return
        }
        if method == "GET" {
            send(connection, status: "200 OK", body: Self.formHTML(code: code), contentType: "text/html; charset=utf-8")
        } else if method == "POST", let body = request.components(separatedBy: "\r\n\r\n").dropFirst().joined(separator: "\r\n\r\n").data(using: .utf8),
                  let payload = Self.payload(from: body) {
            Task { @MainActor [weak self] in
                guard let self, self.listener != nil,
                      path == "/\(self.code)" || path == "/\(self.code)/submit" else { connection.cancel(); return }
                self.send(connection, status: "200 OK", body: Self.successHTML, contentType: "text/html; charset=utf-8")
                self.stop()
                self.status = "Details received. Checking the playlist…"
                self.onPayload?(payload)
            }
        } else {
            send(connection, status: "422 Unprocessable Entity", body: "Enter a full http:// or https:// playlist URL, or upload an M3U file. Xtream requires a server URL, username and password. If supplied, the guide URL must also be a full web address. Go back to correct the details.", contentType: "text/plain")
        }
    }

    private func send(_ connection: NWConnection, status: String, body: String, contentType: String) {
        let data = Data(body.utf8)
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(data.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
        connection.send(content: Data(header.utf8) + data, completion: .contentProcessed { _ in connection.cancel() })
    }

    static func payload(from body: Data) -> PairingPayload? {
        guard let raw = String(data: body, encoding: .utf8) else { return nil }
        var values: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            values[parts[0].removingPercentEncoding ?? parts[0]] = parts[1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? parts[1]
        }
        let kind: ProviderKind = values["provider"] == "xtream" ? .xtream : .m3u
        guard let name = values["name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        let content = kind == .m3u ? ImportValidation.playlistText(values["playlistContent"]) : nil
        if let content, content.utf8.count > 5_000_000 { return nil }
        let playlist = ImportValidation.webURL(values["playlistURL"])
        let server = ImportValidation.webURL(values["serverURL"])
        let epg = ImportValidation.webURL(values["epgURL"])
        if let raw = values["epgURL"], !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, epg == nil { return nil }
        if kind == .m3u, playlist == nil, content == nil { return nil }
        if kind == .xtream, server == nil || values["username", default: ""].isEmpty || values["password", default: ""].isEmpty { return nil }
        return PairingPayload(provider: kind, name: name, serverURL: server?.absoluteString, playlistURL: playlist?.absoluteString, epgURL: epg?.absoluteString, username: values["username"], password: values["password"], playlistContent: content)
    }

    private static func makeCode() -> String { String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! }) }

    private static func localIPv4Address() -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }
        var candidate: String?
        for item in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let address = item.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: item.pointee.ifa_name)
            let flags = Int32(item.pointee.ifa_flags)
            guard name.hasPrefix("en"), (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(address.pointee.sa_len)
            if getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let value = String(cString: host)
                if value.hasPrefix("192.168.") || value.hasPrefix("10.") || value.hasPrefix("172.") { return value }
                candidate = candidate ?? value
            }
        }
        return candidate
    }

    private static func formHTML(code: String) -> String { """
    <!doctype html><meta name=viewport content="width=device-width,initial-scale=1"><title>IMD TV Import</title>
    <style>body{font:18px system-ui;color:#fff;background:#050918;display:grid;place-items:center;min-height:100vh;margin:0}main{width:min(560px,90%);background:#111a36;padding:32px;border-radius:24px}label{display:grid;gap:6px;margin:14px 0}input,select,button{font:inherit;padding:14px;border-radius:12px;border:1px solid #ffffff33;background:#ffffff0d;color:#fff}button{width:100%;background:#1677ff;font-weight:700}.note{color:#aab6d2}</style>
    <main><h1>IMD TV</h1><p>Local import code: <strong>\(code)</strong></p><p class=note>Details go directly to this Apple TV and are not uploaded to the internet.</p>
    <form method=post action="/\(code)/submit"><label>Playlist name<input name=name value="My TV" required></label><label>Type<select name=provider id=p><option value=m3u>M3U Playlist</option><option value=xtream>Xtream Codes</option></select></label>
    <div id=m><label>M3U URL (optional when uploading a file)<input name=playlistURL type=url></label><label>Or select an M3U file<input id=file type=file accept=".m3u,.m3u8,text/plain"></label><input id=content name=playlistContent type=hidden><label>XMLTV URL (optional)<input name=epgURL type=url></label></div>
    <div id=x hidden><label>Server URL<input name=serverURL type=url></label><label>Username<input name=username></label><label>Password<input name=password type=password></label></div><p id=message role=alert></p><button>Send to Apple TV</button></form></main>
    <script>
    const form = document.querySelector('form');
    const provider = document.getElementById('p');
    const m3uPanel = document.getElementById('m');
    const xtreamPanel = document.getElementById('x');
    const fileInput = document.getElementById('file');
    const contentInput = document.getElementById('content');
    const message = document.getElementById('message');
    const button = form.querySelector('button');
    const field = name => form.elements.namedItem(name);
    function updateType() {
        const m3u = provider.value === 'm3u';
        m3uPanel.hidden = !m3u; xtreamPanel.hidden = m3u;
        m3uPanel.querySelectorAll('input').forEach(input => input.disabled = !m3u);
        xtreamPanel.querySelectorAll('input').forEach(input => input.disabled = m3u);
        message.textContent = ''; contentInput.value = '';
    }
    provider.addEventListener('change', updateType); updateType();
    fileInput.addEventListener('change', () => { contentInput.value = ''; });
    form.addEventListener('submit', async event => {
        event.preventDefault(); message.textContent = ''; button.disabled = true;
        try {
            contentInput.value = '';
            if (provider.value === 'm3u') {
                const file = fileInput.files[0];
                if (file) {
                    if (file.size > 5000000) throw new Error('Files must be 5 MB or smaller. Use a playlist URL for larger playlists.');
                    const text = (await file.text()).trim();
                    if (!text.startsWith('#EXTM3U') && !text.startsWith('#EXTINF:')) throw new Error('Choose a valid M3U or M3U8 playlist file.');
                    contentInput.value = text;
                } else if (!field('playlistURL').value.trim()) throw new Error('Enter a playlist URL or select a file.');
            } else if (!field('serverURL').value.trim() || !field('username').value || !field('password').value) {
                throw new Error('Enter the server URL, username and password.');
            }
            HTMLFormElement.prototype.submit.call(form);
        } catch (error) { message.textContent = error.message || 'Could not read this file. Please select it again.'; button.disabled = false; }
    });
    </script>
    """ }
    private static let successHTML = "<!doctype html><meta name=viewport content='width=device-width'><body style='font:24px system-ui;background:#050918;color:white;display:grid;place-items:center;height:100vh'><main><h1>Details received.</h1><p>Return to your Apple TV to check whether the playlist loaded. This page confirms delivery only.</p></main>"
}

