import SwiftUI
import KSPlayer
import KSPlayerUI

@MainActor
struct KSPlayerView: View {
    let url: URL
    let headers: [String: String]
    let clearKey: ClearKeyDescriptor?
    let title: String
    let streams: [Channel]
    let currentStreamID: String
    let isFavourite: Bool
    let onSelectStream: (Channel) -> Void
    let onFavourite: () -> Void
    let onUseAVPlayer: () -> Void
    let onDismiss: () -> Void
    let onFailure: (String) -> Void
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                .onFinish { _, error in if let error { onFailure("KSPlayer failed: \(error.localizedDescription)") } }
                .onStateChanged { _, _ in showControlsTemporarily() }
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .focusable(!controlsVisible)
                .onTapGesture { showControlsTemporarily() }

            if controlsVisible {
                VStack(alignment: .leading) {
                    Text(title).font(.title3.bold()).shadow(radius: 4)
                    Spacer()
                    HStack(spacing: 18) {
                        Button { togglePlayback() } label: {
                            Label(coordinator.state.isPlaying ? "Pause" : "Play", systemImage: coordinator.state.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Menu {
                            ForEach(streams) { stream in
                                Button { onSelectStream(stream) } label: {
                                    if stream.id == currentStreamID { Label(stream.name, systemImage: "checkmark") }
                                    else { Text(stream.name) }
                                }
                            }
                        } label: { Label("Streams", systemImage: "rectangle.stack") }

                        Button(action: onFavourite) {
                            Label(isFavourite ? "Favourited" : "Favourite", systemImage: isFavourite ? "heart.fill" : "heart")
                        }
                        Button(action: onUseAVPlayer) { Label("AVPlayer", systemImage: "play.rectangle") }
                        Button(action: onDismiss) { Label("Done", systemImage: "xmark") }
                    }
                }
                .padding(.horizontal, 70)
                .padding(.vertical, 48)
                .background(LinearGradient(colors: [.black.opacity(0.72), .clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onPlayPauseCommand { togglePlayback() }
        .onMoveCommand { _ in showControlsTemporarily() }
        .onAppear { showControlsTemporarily() }
        .onDisappear { hideTask?.cancel() }
    }

    private func togglePlayback() {
        if coordinator.state.isPlaying { coordinator.playerLayer?.player.pause() }
        else { coordinator.playerLayer?.player.play() }
        showControlsTemporarily()
    }

    private func showControlsTemporarily() {
        withAnimation(.easeOut(duration: 0.18)) { controlsVisible = true }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(.easeIn(duration: 0.2)) { controlsVisible = false } }
        }
    }

    private var options: KSOptions {
        let options = KSOptions()
        options.playerTypes = [KSMEPlayer.self]
        options.isAutoPlay = true
        if !headers.isEmpty { options.appendHeader(headers) }
        // FFmpeg accepts a raw decryption key for compatible encrypted containers.
        // CENC/DASH ClearKey support still depends on the manifest and demuxer build.
        if let clearKey { options.formatContextOptions["decryption_key"] = clearKey.key }
        return options
    }
}

