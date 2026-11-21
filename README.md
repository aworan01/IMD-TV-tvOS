# IMD TV for Apple TV

Native SwiftUI tvOS port of IMD TV. It is an IPTV player only and contains no channels or media.

## Implemented

- Focus-driven Apple TV interface modeled on the Android application's Celestial layout
- M3U/M3U8 and Xtream Codes providers
- Live categories and channels
- XMLTV guide, search, and favourites
- AVPlayer playback for native HLS, H.264/AVC and HEVC streams
- KSPlayer/FFmpeg fallback for MKV, transport streams, and unsupported containers
- Keychain storage for provider credentials
- Layered app icon, Top Shelf assets, and Top Shelf extension
- Short-code playlist import using GitHub Pages plus a Cloudflare Worker
- GitHub Actions macOS build and unsigned IPA artifact

## ClearKey boundary

Apple's AVPlayer does not expose general MPEG-CENC ClearKey playback. The M3U parser reads Kodi-style ClearKey metadata and passes the decryption key to KSPlayer/FFmpeg as a demuxer option. Compatibility depends on the container, manifest and FFmpeg build. Standard HLS AES-128 encryption remains handled by AVPlayer when the playlist exposes a reachable key URL. FairPlay streams require a provider-specific FairPlay integration.

## Local build

Requirements: macOS, Xcode 26+, XcodeGen, and an Apple TV running tvOS 17 or later.

```sh
brew install xcodegen
xcodegen generate
open IMDTV.xcodeproj
```

Select your Apple Developer team and a unique bundle identifier before running on a physical device.

## IPA

Every push to `main` runs **Build tvOS IPA**. The workflow publishes `IMD-TV-tvOS-unsigned.ipa` as both a workflow artifact and the `development` prerelease asset. It must be signed or re-signed with a valid Apple Developer certificate and tvOS provisioning profile before installation.

## Web pairing setup

1. Create a Cloudflare KV namespace.
2. Replace `REPLACE_WITH_KV_NAMESPACE_ID` in `PairingWorker/wrangler.toml`.
3. Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as repository secrets.
4. Set repository variable `CLOUDFLARE_KV_CONFIGURED=true` and run **Deploy Pairing Worker**.
5. Replace `https://YOUR-WORKER.workers.dev` in `PairingWeb/app.js` and in the app's default Settings endpoint.
6. Enable GitHub Pages with **GitHub Actions** as its source.

Pairing records expire after ten minutes and are deleted when the Apple TV retrieves them. Credentials are never stored in this repository.

## Licence

GPL-3.0. This port is derived from the GPL-3.0 Android IMD TV project and uses GPL-licensed KSPlayer.

