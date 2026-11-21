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
- Short-code playlist import hosted temporarily by the Apple TV on the local network
- Edit, refresh, and delete saved playlists
- Automatic AVPlayer-to-KSPlayer fallback with visible playback errors
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

KSPlayer's current XCFramework contains a physical-tvOS slice but no tvOS Simulator slice. CI therefore builds the generic physical Apple TV destination. Simulator builds must temporarily disable the KSPlayer targets or wait for an upstream simulator slice.

## Local playlist import

Choose **Add Playlist → Import from phone → Start Local Import**. The Apple TV displays an address such as `http://192.168.1.40:49152/AB7K9Q`. Open the complete address on a phone or computer connected to the same LAN, enter M3U or Xtream details, and submit. The listener accepts one valid submission and expires after ten minutes.

The local page requires no external account or cloud service. It uses unencrypted HTTP inside the LAN, so use it only on a trusted home network. Router client isolation or guest Wi-Fi can prevent the phone from reaching the Apple TV.

## Licence

GPL-3.0. This port is derived from the GPL-3.0 Android IMD TV project and uses GPL-licensed KSPlayer.

