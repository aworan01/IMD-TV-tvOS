import AVKit
import SwiftUI

struct PlayerScreen: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    let channel: Channel

    private var useKSPlayer: Bool {
        if settings.playerMode == "KSPlayer" { return true }
        if settings.playerMode == "AVPlayer" { return false }
        let ext = channel.streamURL.pathExtension.lowercased()
        return ["mkv", "avi", "ts", "webm"].contains(ext) || channel.clearKey != nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if useKSPlayer {
                KSPlayerView(url: channel.streamURL, headers: channel.headers, clearKey: channel.clearKey)
            } else {
                NativePlayerView(url: channel.streamURL, headers: channel.headers)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(channel.name).font(.title.bold())
                if let programme = library.nowPlaying(on: channel) { Text(programme.title).foregroundStyle(.secondary) }
            }.padding(50).background(.linearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
        }
        .onExitCommand { dismiss() }
    }
}

private struct NativePlayerView: View {
    @State private var player: AVPlayer
    init(url: URL, headers: [String: String]) {
        let options = headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: url, options: options)
        _player = State(initialValue: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
    }
    var body: some View { VideoPlayer(player: player).ignoresSafeArea().onAppear { player.play() }.onDisappear { player.pause() } }
}

