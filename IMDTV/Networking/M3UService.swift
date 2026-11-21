import Foundation

struct M3UService {
    func load(url: URL) async throws -> [Channel] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { throw ImportError.invalidResponse }
        let channels = parse(text)
        guard !channels.isEmpty else { throw ImportError.emptyPlaylist }
        return channels
    }

    func parse(_ text: String) -> [Channel] {
        let lines = text.components(separatedBy: .newlines)
        var result: [Channel] = []
        var metadata: [String: String] = [:]
        var title = "Channel"
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXTINF:") {
                metadata = attributes(in: line)
                title = line.split(separator: ",", maxSplits: 1).last.map(String.init) ?? metadata["tvg-name"] ?? "Channel"
            } else if line.hasPrefix("#KODIPROP:inputstream.adaptive.license_key=") {
                let value = line.components(separatedBy: "=").dropFirst().joined(separator: "=")
                let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 { metadata["clear-key-id"] = parts[0]; metadata["clear-key"] = parts[1] }
            } else if !line.isEmpty, !line.hasPrefix("#"), let url = URL(string: line) {
                let identifier = metadata["tvg-id"] ?? line
                let clearKey = metadata["clear-key-id"].flatMap { id in metadata["clear-key"].map { ClearKeyDescriptor(keyID: id, key: $0) } }
                result.append(Channel(
                    id: identifier, name: title,
                    category: metadata["group-title"] ?? "Other", streamURL: url,
                    logoURL: metadata["tvg-logo"].flatMap(URL.init(string:)), epgID: metadata["tvg-id"],
                    clearKey: clearKey
                ))
                metadata = [:]; title = "Channel"
            }
        }
        return result
    }

    private func attributes(in line: String) -> [String: String] {
        let pattern = #"([A-Za-z0-9_-]+)=\"([^\"]*)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).reduce(into: [:]) { values, match in
            guard let keyRange = Range(match.range(at: 1), in: line), let valueRange = Range(match.range(at: 2), in: line) else { return }
            values[String(line[keyRange])] = String(line[valueRange])
        }
    }
}

