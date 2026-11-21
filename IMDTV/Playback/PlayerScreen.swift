import AVKit
import SwiftUI

struct PlayerScreen: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    let channel: Channel
    @State private var currentChannel: Channel
    @State private var engine: Engine = .native
    @State private var playbackError: String?
    @State private var controlsVisible = true

    private enum Engine: String, CaseIterable, Identifiable { case native = "AVPlayer", ksPlayer = "KSPlayer"; var id: String { rawValue } }

    init(channel: Channel) { self.channel = channel; _currentChannel = State(initialValue: channel) }

    private var useKSPlayer: Bool {
        if settings.playerMode == "KSPlayer" { return true }
        if settings.playerMode == "AVPlayer" { return false }
        let ext = currentChannel.streamURL.pathExtension.lowercased()
        return ["mkv", "avi", "ts", "webm"].contains(ext) || currentChannel.clearKey != nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if engine == .ksPlayer || useKSPlayer {
                KSPlayerView(url: currentChannel.streamURL, headers: effectiveHeaders, clearKey: currentChannel.clearKey) { message in
                    playbackError = message
                }.id("ks-\(currentChannel.id)")
            } else {
                NativePlayerView(url: currentChannel.streamURL, headers: effectiveHeaders) { message in
                    playbackError = "AVPlayer failed: \(message). Retrying with KSPlayer…"
                    engine = .ksPlayer
                }.id("av-\(currentChannel.id)")
            }
            if controlsVisible { controlsOverlay.transition(.opacity.combined(with: .move(edge: .bottom))) }
            if let playbackError {
                VStack { Spacer(); Text(playbackError).font(.headline).padding(22).glassPanel().padding(50) }
            }
        }
        .onAppear { engine = useKSPlayer ? .ksPlayer : .native }
        .onPlayPauseCommand { withAnimation { controlsVisible.toggle() } }
        .onMoveCommand { _ in if !controlsVisible { withAnimation { controlsVisible = true } } }
        .onExitCommand { dismiss() }
    }

    private var effectiveHeaders: [String: String] {
        var values = currentChannel.headers
        if values["User-Agent"] == nil { values["User-Agent"] = "VLC/3.0.20 LibVLC/3.0.20" }
        return values
    }

    private var programme: Programme? { library.nowPlaying(on: currentChannel) }
    private var variants: [Channel] {
        let key = normalized(currentChannel.name)
        let matches = library.channels.filter { normalized($0.name) == key }
        return matches.count > 1 ? matches : [currentChannel]
    }
    private func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: #"\b(4k|uhd|fhd|hd|sd|hevc|h265|h264)\b"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var progress: Double {
        guard let programme else { return 0 }
        return min(1, max(0, Date().timeIntervalSince(programme.start) / programme.end.timeIntervalSince(programme.start)))
    }
    private var streamLabel: String {
        let ext = currentChannel.streamURL.pathExtension.uppercased()
        return ext.isEmpty ? "LIVE" : ext
    }

    private var controlsOverlay: some View {
        VStack { Spacer();
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { AsyncImage(url: currentChannel.logoURL) { $0.resizable().scaledToFit() } placeholder: { Image(systemName: "tv") }.frame(width: 90, height: 60); Text(currentChannel.name).font(.title2.bold()) }
                        Text(programme?.title ?? "Live TV").font(.system(size: 42, weight: .bold)).lineLimit(1)
                        if let programme { Text("\(programme.start.formatted(date: .omitted, time: .shortened)) – \(programme.end.formatted(date: .omitted, time: .shortened))").foregroundStyle(.secondary); Text(programme.description ?? programme.subtitle ?? "").font(.headline).lineLimit(3).frame(maxWidth: 850, alignment: .leading) }
                        HStack { badge(streamLabel); badge(engine.rawValue); if currentChannel.clearKey != nil { badge("ClearKey") } }
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        Menu { ForEach(variants) { variant in Button(variant.name) { currentChannel = variant; playbackError = nil; engine = useKSPlayer ? .ksPlayer : .native } } } label: { Label(variants.count > 1 ? "Streams \(variants.count)" : "Stream", systemImage: "rectangle.stack") }
                        Button { library.toggleFavourite(currentChannel) } label: { Image(systemName: library.isFavourite(currentChannel) ? "heart.fill" : "heart") }
                        Menu { ForEach(Engine.allCases) { value in Button(value.rawValue) { engine = value; playbackError = nil } } } label: { Image(systemName: "play.rectangle") }
                        Button { dismiss() } label: { Label("TV Guide", systemImage: "list.bullet.rectangle") }
                        Menu { Text("URL: \(currentChannel.streamURL.host ?? "Unknown")"); Text("Container: \(streamLabel)"); Text("Engine: \(engine.rawValue)"); if let playbackError { Text(playbackError) } } label: { Image(systemName: "ellipsis") }
                    }.buttonStyle(.borderedProminent)
                }
                ProgressView(value: progress).tint(.white)
                HStack {
                    if let programme { Text(programme.start, style: .time) }
                    Spacer(); Text("LIVE").foregroundStyle(.red)
                    if let programme { Text(programme.end, style: .time) }
                }.font(.caption.monospacedDigit())
            }.padding(44).background(.linearGradient(colors: [.clear, .black.opacity(0.94)], startPoint: .top, endPoint: .bottom))
        }
    }

    private func badge(_ text: String) -> some View { Text(text).font(.caption.bold()).padding(.horizontal, 9).padding(.vertical, 4).background(.white.opacity(0.18), in: Capsule()) }
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

