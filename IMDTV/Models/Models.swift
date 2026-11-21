import Foundation

enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case m3u = "M3U Playlist"
    case xtream = "Xtream Codes"
    var id: String { rawValue }
}

struct ProviderAccount: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var kind: ProviderKind
    var serverURL: URL
    var playlistURL: URL?
    var epgURL: URL?
    var username: String?
    var password: String?
}

struct Channel: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var streamURL: URL
    var logoURL: URL?
    var epgID: String?
    var headers: [String: String] = [:]
    var clearKey: ClearKeyDescriptor?

    static func == (lhs: Channel, rhs: Channel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ClearKeyDescriptor: Codable, Hashable {
    let keyID: String
    let key: String
}

struct Programme: Codable, Identifiable, Hashable {
    var id: String
    var channelID: String
    var title: String
    var subtitle: String?
    var description: String?
    var start: Date
    var end: Date
}

struct PairingPayload: Codable {
    let provider: ProviderKind
    let name: String
    let serverURL: String?
    let playlistURL: String?
    let epgURL: String?
    let username: String?
    let password: String?
    let playlistContent: String?
}

