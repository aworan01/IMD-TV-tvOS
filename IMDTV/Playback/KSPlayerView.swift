import SwiftUI
import KSPlayer
import KSPlayerUI

@MainActor
struct KSPlayerView: View {
    let url: URL
    let headers: [String: String]
    let clearKey: ClearKeyDescriptor?
    let onFailure: (String) -> Void
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    var body: some View {
        KSVideoPlayer(coordinator: coordinator, url: url, options: options)
            .ignoresSafeArea()
            .onFinish { _, error in if let error { onFailure("KSPlayer failed: \(error.localizedDescription)") } }
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

