import AVKit
import SwiftUI

struct PlayerScreen: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    let channel: Channel
    @State private var engine: Engine = .native
    @State private var playbackError: String?

    private enum Engine { case native, ksPlayer }

    private var useKSPlayer: Bool {
        if settings.playerMode == "KSPlayer" { return true }
        if settings.playerMode == "AVPlayer" { return false }
        let ext = channel.streamURL.pathExtension.lowercased()
        return ["mkv", "avi", "ts", "webm"].contains(ext) || channel.clearKey != nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if engine == .ksPlayer || useKSPlayer {
                KSPlayerView(url: channel.streamURL, headers: effectiveHeaders, clearKey: channel.clearKey) { message in
                    playbackError = message
                }
            } else {
                NativePlayerView(url: channel.streamURL, headers: effectiveHeaders) { message in
                    playbackError = "AVPlayer failed: \(message). Retrying with KSPlayer…"
                    engine = .ksPlayer
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(channel.name).font(.title.bold())
                if let programme = library.nowPlaying(on: channel) { Text(programme.title).foregroundStyle(.secondary) }
            }.padding(50).background(.linearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
            if let playbackError {
                VStack { Spacer(); Text(playbackError).font(.headline).padding(22).glassPanel().padding(50) }
            }
        }
        .onAppear { engine = useKSPlayer ? .ksPlayer : .native }
        .onExitCommand { dismiss() }
    }

    private var effectiveHeaders: [String: String] {
        var values = channel.headers
        if values["User-Agent"] == nil { values["User-Agent"] = "VLC/3.0.20 LibVLC/3.0.20" }
        return values
    }
}

private struct NativePlayerView: View {
    @StateObject private var model: NativePlayerModel
    let onFailure: (String) -> Void

    init(url: URL, headers: [String: String], onFailure: @escaping (String) -> Void) {
        _model = StateObject(wrappedValue: NativePlayerModel(url: url, headers: headers))
        self.onFailure = onFailure
    }
    var body: some View {
        VideoPlayer(player: model.player).ignoresSafeArea()
            .onAppear { model.player.play() }.onDisappear { model.player.pause() }
            .onReceive(model.$failure.compactMap { $0 }) { onFailure($0) }
    }
}

private final class NativePlayerModel: ObservableObject {
    let player: AVPlayer
    @Published var failure: String?
    private var observation: NSKeyValueObservation?

    init(url: URL, headers: [String: String]) {
        let options = headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let item = AVPlayerItem(asset: AVURLAsset(url: url, options: options))
        player = AVPlayer(playerItem: item)
        observation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async { self?.failure = item.error?.localizedDescription ?? "The stream could not be opened" }
        }
    }
}

