import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct PlayerScreen: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentChannel: Channel
    @State private var useFallback = false
    @State private var fallbackError: String?

    init(channel: Channel) {
        _currentChannel = State(initialValue: channel)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if useFallback || shouldStartWithKSPlayer {
                KSPlayerView(url: currentChannel.streamURL, headers: headers, clearKey: currentChannel.clearKey) { message in
                    fallbackError = message
                }
                .id(currentChannel.id)
            } else {
                SystemPlayerView(
                    channel: currentChannel,
                    programme: library.nowPlaying(on: currentChannel),
                    variants: streamVariants,
                    headers: headers,
                    isFavourite: library.isFavourite(currentChannel),
                    onFavourite: { library.toggleFavourite(currentChannel) },
                    onSelectStream: { currentChannel = $0 },
                    onSelectKSPlayer: { useFallback = true },
                    onFailure: { message in fallbackError = message; useFallback = true }
                )
                .id(currentChannel.id)
            }

            if (useFallback || shouldStartWithKSPlayer), let fallbackError {
                VStack { Spacer(); Text(fallbackError).font(.callout).padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)).padding(40) }
            }
        }
        .onExitCommand { dismiss() }
    }

    private var shouldStartWithKSPlayer: Bool {
        if settings.playerMode == "KSPlayer" { return true }
        if settings.playerMode == "AVPlayer" { return false }
        return ["mkv", "avi", "ts", "webm"].contains(currentChannel.streamURL.pathExtension.lowercased()) || currentChannel.clearKey != nil
    }

    private var headers: [String: String] {
        var result = currentChannel.headers
        if result["User-Agent"] == nil { result["User-Agent"] = "VLC/3.0.20 LibVLC/3.0.20" }
        return result
    }

    private var streamVariants: [Channel] {
        let key = normalized(currentChannel.name)
        let matches = library.channels.filter { normalized($0.name) == key }
        return matches.count > 1 ? matches : [currentChannel]
    }

    private func normalized(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: #"\b(4k|uhd|fhd|hd|sd|hevc|h265|h264)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SystemPlayerView: UIViewControllerRepresentable {
    let channel: Channel
    let programme: Programme?
    let variants: [Channel]
    let headers: [String: String]
    let isFavourite: Bool
    let onFavourite: () -> Void
    let onSelectStream: (Channel) -> Void
    let onSelectKSPlayer: () -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = true
        controller.playbackControlsIncludeTransportBar = true
        controller.playbackControlsIncludeInfoViews = true
        controller.transportBarIncludesTitleView = true
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        context.coordinator.install(on: controller)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.channelID != channel.id { context.coordinator.install(on: controller) }
        else { context.coordinator.updateMenus(on: controller) }
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.player?.pause(); coordinator.observation = nil
    }

    final class Coordinator: NSObject {
        var parent: SystemPlayerView
        var channelID: String?
        var observation: NSKeyValueObservation?
        private var reportedFailure = false

        init(parent: SystemPlayerView) { self.parent = parent }

        func install(on controller: AVPlayerViewController) {
            reportedFailure = false
            observation = nil
            channelID = parent.channel.id
            let options: [String: Any]? = parent.headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": parent.headers]
            let item = AVPlayerItem(asset: AVURLAsset(url: parent.channel.streamURL, options: options))
            item.externalMetadata = metadataItems()
            let player = AVPlayer(playerItem: item)
            controller.player = player
            updateMenus(on: controller)
            observation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self, item.status == .failed, !self.reportedFailure else { return }
                self.reportedFailure = true
                let message = item.error?.localizedDescription ?? "AVPlayer could not open this stream"
                DispatchQueue.main.async { self.parent.onFailure(message) }
            }
            player.play()
        }

        func updateMenus(on controller: AVPlayerViewController) {
            let favourite = UIAction(
                title: parent.isFavourite ? "Remove Favourite" : "Add Favourite",
                image: UIImage(systemName: parent.isFavourite ? "heart.fill" : "heart"),
                state: parent.isFavourite ? .on : .off
            ) { [weak self] _ in DispatchQueue.main.async { self?.parent.onFavourite() } }

            let streamActions = parent.variants.map { variant in
                UIAction(title: variant.name, state: variant.id == parent.channel.id ? .on : .off) { [weak self] _ in
                    DispatchQueue.main.async { self?.parent.onSelectStream(variant) }
                }
            }
            let streams = UIMenu(title: parent.variants.count > 1 ? "Streams (\(parent.variants.count))" : "Stream", image: UIImage(systemName: "rectangle.stack"), options: .singleSelection, children: streamActions)
            let playerMenu = UIMenu(title: "Player", image: UIImage(systemName: "play.rectangle"), children: [
                UIAction(title: "Use KSPlayer", image: UIImage(systemName: "arrow.triangle.2.circlepath")) { [weak self] _ in DispatchQueue.main.async { self?.parent.onSelectKSPlayer() } }
            ])
            controller.transportBarCustomMenuItems = [streams, favourite, playerMenu]
        }

        private func metadataItems() -> [AVMetadataItem] {
            var result: [AVMetadataItem] = []
            result.append(item(identifier: .commonIdentifierTitle, value: parent.programme?.title ?? parent.channel.name))
            result.append(item(identifier: .iTunesMetadataTrackSubTitle, value: parent.channel.name))
            if let description = parent.programme?.description, !description.isEmpty {
                result.append(item(identifier: .commonIdentifierDescription, value: description))
            }
            return result
        }

        private func item(identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
            let item = AVMutableMetadataItem()
            item.identifier = identifier
            item.value = value as NSString
            item.extendedLanguageTag = "und"
            return item.copy() as! AVMetadataItem
        }
    }
}
