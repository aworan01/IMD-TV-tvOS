import Foundation

enum ImportValidation {
    static func webURL(_ value: String?) -> URL? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func playlistText(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
        guard normalized.hasPrefix("#EXTM3U") || normalized.hasPrefix("#EXTINF:") else { return nil }
        return normalized
    }
}
