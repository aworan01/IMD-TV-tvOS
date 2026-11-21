import Foundation

struct XtreamService {
    private struct CategoryDTO: Decodable { let category_id: String; let category_name: String }
    private struct StreamDTO: Decodable {
        let stream_id: Int
        let name: String
        let stream_icon: String?
        let epg_channel_id: String?
        let category_id: String?
        let container_extension: String?
    }

    func load(account: ProviderAccount) async throws -> [Channel] {
        guard let username = account.username, let password = account.password else { throw ImportError.invalidConfiguration }
        async let categoryData = request(account.serverURL, username, password, "get_live_categories")
        async let streamData = request(account.serverURL, username, password, "get_live_streams")
        let categories = try JSONDecoder().decode([CategoryDTO].self, from: await categoryData)
        let streams = try JSONDecoder().decode([StreamDTO].self, from: await streamData)
        let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.category_id, $0.category_name) })
        return streams.compactMap { stream in
            let ext = stream.container_extension ?? "m3u8"
            let url = account.serverURL
                .appendingPathComponent("live").appendingPathComponent(username)
                .appendingPathComponent(password).appendingPathComponent("\(stream.stream_id).\(ext)")
            return Channel(id: "xtream:\(stream.stream_id)", name: stream.name,
                           category: names[stream.category_id ?? ""] ?? "Other", streamURL: url,
                           logoURL: stream.stream_icon.flatMap(URL.init(string:)), epgID: stream.epg_channel_id)
        }
    }

    private func request(_ server: URL, _ username: String, _ password: String, _ action: String) async throws -> Data {
        var components = URLComponents(url: server.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: false)
        components?.queryItems = [.init(name: "username", value: username), .init(name: "password", value: password), .init(name: "action", value: action)]
        guard let url = components?.url else { throw ImportError.invalidConfiguration }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { throw ImportError.invalidResponse }
        return data
    }
}

