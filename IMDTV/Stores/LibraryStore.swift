import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var providers: [ProviderAccount] = []
    @Published private(set) var channels: [Channel] = []
    @Published private(set) var programmes: [Programme] = []
    @Published var selectedChannel: Channel?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let providerKey = "providers"
    private let favouritesKey = "favouriteChannelIDs"
    private var favouriteIDs: Set<String> = []

    var categories: [String] { Array(Set(channels.map(\.category))).sorted() }
    var favourites: [Channel] { channels.filter { favouriteIDs.contains($0.id) } }

    func restore() async {
        providers = (try? KeychainStore.load([ProviderAccount].self, account: providerKey)) ?? []
        favouriteIDs = Set(UserDefaults.standard.stringArray(forKey: favouritesKey) ?? [])
        guard let provider = providers.first else { return }
        await refresh(provider)
    }

    @discardableResult
    func add(_ provider: ProviderAccount) async -> Bool {
        var updated = providers.filter { $0.id != provider.id }
        updated.append(provider)
        do { try KeychainStore.save(updated, account: providerKey) }
        catch {
            errorMessage = "Could not securely save provider: \(error.localizedDescription)"
            return false
        }
        providers = updated
        await refresh(provider)
        return errorMessage == nil
    }

    func update(_ provider: ProviderAccount) async {
        guard let index = providers.firstIndex(where: { $0.id == provider.id }) else {
            await add(provider); return
        }
        providers[index] = provider
        do { try KeychainStore.save(providers, account: providerKey) }
        catch { errorMessage = "Could not securely update provider: \(error.localizedDescription)" }
        await refresh(provider)
    }

    func remove(_ provider: ProviderAccount) {
        providers.removeAll { $0.id == provider.id }
        do { try KeychainStore.save(providers, account: providerKey) }
        catch { errorMessage = "Could not update secure provider storage: \(error.localizedDescription)" }
        if providers.isEmpty {
            channels = []; programmes = []
        } else if let next = providers.first {
            Task { await refresh(next) }
        }
    }

    func deleteProviders(at offsets: IndexSet) {
        let removed = offsets.compactMap { providers.indices.contains($0) ? providers[$0] : nil }
        removed.forEach(remove)
    }

    func refresh(_ provider: ProviderAccount) async {
        isLoading = true; errorMessage = nil
        programmes = []
        defer { isLoading = false }
        do {
            switch provider.kind {
            case .m3u:
                guard let url = provider.playlistURL else { throw ImportError.invalidConfiguration }
                channels = try await M3UService().load(url: url)
            case .xtream:
                channels = try await XtreamService().load(account: provider)
            }
            if let epgURL = ImportValidation.webURL(provider.epgURL?.absoluteString) {
                programmes = try await XMLTVService().load(url: epgURL)
            } else if provider.kind == .xtream,
                      let user = provider.username, let pass = provider.password {
                let url = provider.serverURL.appendingPathComponent("xmltv.php")
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = [.init(name: "username", value: user), .init(name: "password", value: pass)]
                if let epg = components?.url { programmes = (try? await XMLTVService().load(url: epg)) ?? [] }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleFavourite(_ channel: Channel) {
        if favouriteIDs.contains(channel.id) { favouriteIDs.remove(channel.id) }
        else { favouriteIDs.insert(channel.id) }
        UserDefaults.standard.set(Array(favouriteIDs), forKey: favouritesKey)
        objectWillChange.send()
    }

    func isFavourite(_ channel: Channel) -> Bool { favouriteIDs.contains(channel.id) }
    func nowPlaying(on channel: Channel) -> Programme? {
        programmes.first { $0.channelID == channel.epgID && $0.start <= Date() && $0.end > Date() }
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "imdtv", url.host == "play",
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value
        else { return }
        selectedChannel = channels.first { $0.id == id }
    }
}

enum ImportError: LocalizedError {
    case invalidConfiguration, invalidResponse, emptyPlaylist
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "The provider configuration is incomplete."
        case .invalidResponse: "The provider returned an invalid response."
        case .emptyPlaylist: "No playable channels were found."
        }
    }
}

