# Gravity Torrent

<p align="center">
  <img src="./app/assets/icon.png" alt="Gravity Torrent logo" width="96"/>
</p>

<p align="center">
  <strong>Stream and download torrents on all your devices</strong>
</p>

<p align="center">
  <a href="https://github.com/teamantigravity/gravity-torrent/actions/workflows/build-apps.yml">
    <img src="https://github.com/teamantigravity/gravity-torrent/actions/workflows/build-apps.yml/badge.svg" alt="Build apps" />
  </a>
  <a href="https://github.com/teamantigravity/gravity-torrent/actions/workflows/ci.yml">
    <img src="https://github.com/teamantigravity/gravity-torrent/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
</p>

**Gravity Torrent 2.0** is a state-of-the-art, cross-platform BitTorrent client built with Flutter. It is designed to be simple enough for everyday users while providing rich power-user capabilities. Powered by the Transmission backend via [`flutter_libtransmission`](https://github.com/G-Ray/flutter_libtransmission), it can stream media files instantly while downloading.

---

## Table of contents

- [What's new in 2.0](#whats-new-in-version-20-)
- [Changelog](CHANGELOG.md)
- [Privacy & data safety](#privacy--data-safety)
- [Features](#features)
- [Security & hardening](#security--hardening)
- [Supported platforms](#supported-platforms)
- [Download](#download)
- [Development setup](#development-setup)
- [Testing](#testing)
- [CI/CD](#cicd)
- [Project structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## What's New in Version 2.0 🚀

- **📺 DLNA / UPnP / Smart TV Media Casting** — Discover local Smart TVs and DLNA renderers over SSDP, then drive them with real `AVTransport:1` actions: play, pause, seek, and volume. Available on mobile *and* desktop.
- **⚡ Moov Atom & Sequential Priority Booster** — Automatically calculates and boosts Transmission piece priorities for the first 1% (header) and last 1% (MP4 `moov` atom) of video files for instant playback.
- **🛡️ Auto-Updating Peer Blocklist Manager** — Dynamically fetches, updates, and applies P2P IP blocklists to block known malicous IP ranges, complete with live rule count monitoring in Settings.
- **🌐 Local Network LAN Streaming** — Opt-in HTTP server binding (`0.0.0.0`) with LAN IP resolution for external TV streaming, protected by a per-session capability token.
- **🎬 Episode-Aware Playback Queue** — Auto-builds a queue from the torrent's media files in natural order (`E2` before `E10`), skips release-group `sample` clips, auto-plays the next file, and remembers a resume position per file.
- **🖥️ Desktop System Tray Quick Actions** — Quick "Pause All" and "Resume All" actions directly from the system tray menu.
- **📶 Wi-Fi Only Mode & VPN Kill Switch** — Restrict transfers to Wi-Fi networks and automatically pause downloads if your VPN disconnects or IP address changes.
- **🔋 Battery Saver Mode** — Automatically pause downloads when battery drops below your customizable threshold.
- **🔒 App Lock & Privacy Vault** — Biometric (Face ID / Fingerprint) and PIN authentication with on-device privacy scoring.
- **📊 Data Usage Analytics** — Interactive 7-day bandwidth chart with per-torrent download/upload metrics.
- **📡 RSS Auto-Download Feeds** — Automate torrent downloads from RSS feeds with regex rules.
- **🤖 Smart File Pipeline (Auto-Extract)** — Automatically extract downloaded `.zip`, `.tar`, and `.gz` archives, and intelligently route files based on extensions.
- **🗓️ Visual Bandwidth Schedule Heatmap** — Set granular, time-based bandwidth throttling rules across a beautiful 7x24 interactive grid.

---

A detailed changelog is available in [CHANGELOG.md](CHANGELOG.md).

## Privacy & data safety

Gravity Torrent does **not** collect or transmit any user data. The only third-party services used are Google Mobile Ads (AdMob) for serving ads and the optional in-app update check for non-store builds. All torrent state, search history, favorites, and settings remain on the device.

---

## Features

### Core Torrenting

- Add torrents from **magnet links**, `.torrent` files, **app/deep links** (`magnet:`, `gravitytorrent:`, `file:`, content URIs), or the clipboard.
- Create `.torrent` files and seed them directly from the app.
- Browse active and inactive torrents with live progress, speed, ETA, status, and health badges.
- Start, pause, remove, copy magnet links, copy info hashes, and share torrents.
- **Bulk remove** and multi-select torrents to copy or share multiple links at once.
- **Filter and search** by text; sort by added date, progress, name, or size.
- **Status filter** with per-status counts, toggleable from Settings.
- **File-level control** — select files, set per-file priority, and view pieces.
- **Per-torrent speed limits** and **sequential download** for media streaming.
- **Favorites** and **private notes** per torrent, with pinned-first sorting and a one-tap "favorites only" list filter.
- **Labels/tags** — add, remove, filter, and show/hide label chips.
- **Recent search queries** and **recent download directories** for quick reuse.
- **Visible/total torrent count** header, live session speed, and lifetime transfer totals.
- Selection mode with select-all, pause/resume, remove, copy, and share.

### Media Player & Streaming

- Stream **video and audio** directly from an incomplete torrent with the built-in `media_kit` player.
- **DLNA / Smart TV / UPnP casting** to local renderers from the player on every platform, with pause/resume, seek, and renderer volume control.
- **Moov atom & sequential priority booster** for instant playback startup.
- Local HTTP streaming server with byte-range seek support, optionally reachable on the LAN behind a capability token.
- Subtitle support for `.srt`, `.vtt`, `.ass`, `.ssa`, `.sub`, `.idx` files, with automatic language detection.
- Subtitle and audio track selection during playback.
- **Player controls**: playback speed, loop mode, A-B repeat, sleep timer, and a reorderable playlist queue.
- **Episode-aware auto-queue** with natural ordering and sample-clip filtering; finishing a file automatically streams the next one.
- Resume position saving with debounced persistence, keyed by a stable digest so saved positions survive SDK upgrades.
- **Background audio & media session** with notification and lock-screen controls.
- **Picture-in-picture** on Android and a compact always-on-top fallback on desktop.

### Settings & Customization

- **Theme** selection: light, dark, AMOLED true black, or system.
- **Dynamic color** (Material You) on supported Android devices.
- **Locale / language selector** with full internationalization.
- **Compact list** and toggles for torrent labels, status filter, recent searches, live speed header, visible count, and health badges.
- **Download directory** picker and **maximum active downloads** limit.
- **Global speed limits** and **Turtle mode** with scheduled hours.
- **Privacy & security**: app lock / privacy vault with biometric or PIN, opt-in LAN streaming, peer blocklist manager with live rule count, peer encryption, DHT, PEX, LPD, and µTP toggles.
- **Seeding limits**: seed ratio and idle seeding timeout.
- **Advanced settings**: listening port, data-usage analytics, local remote control, download scheduler, monthly bandwidth quota, bandwidth schedule heatmap, RSS auto-download, Wi-Fi-only mode, VPN kill switch, battery saver, blocklist URL, auto-extract, and auto-start.
- **Reset** Transmission session settings.
- **Backup & restore** app settings and state.
- Optional **in-app update checks** for non-store desktop builds.

### Accessibility

- High contrast mode.
- Bold text that preserves relative font-weight hierarchy.
- Large text and display-size scaling support.
- Reduced motion respected for onboarding and animations.
- AMOLED true-black theme.

### Automation

- **RSS auto-download feeds** with regex rules and per-feed polling.
- **Smart download scheduler** to start or pause torrents on a calendar.
- **Monthly bandwidth quota** with caps and usage monitoring.
- **Bandwidth schedule heatmap** for granular, time-based speed limits.
- **Auto-extract** downloaded `.zip`, `.tar`, and `.gz` archives on completion.
- **Battery saver mode** that pauses transfers when battery is low.
- **Wi-Fi only mode** and **VPN kill switch**.
- **Theme scheduler** for automatic light/dark switching.
- **Auto-start** on login for desktop platforms.

### Notifications

- Foreground/background download progress notification with live speed and pause/resume actions.
- Per-torrent completion notifications.
- Rich Android notification channels created at startup.

### Desktop & Platform Integration

- **System tray** with show/hide and "Pause All" / "Resume All" quick actions.
- Custom close behavior that keeps the app running in the background.
- Windows registry registration for `magnet:` links and `.torrent` files.
- macOS native app bundle, system tray, and media session support.
- Linux GTK windowing, system tray / AppIndicator, and `.desktop` auto-start.
- Custom window title bar on desktop.
- **Keyboard shortcuts**: add torrent, refresh, select all, focus/clear search, sort, open Settings, exit selection, and delete.
- Mobile launcher **app shortcuts**.

### UX

- Onboarding walkthrough with accessibility-aware animations.
- Local "What's New" dialog shown once per version.
- In-app review prompt after repeated successful use.
- Adaptive **Material 3** UI with responsive navigation rail / bottom bar.
- Haptic feedback on supported controls.
- Feature flags with remote kill-switch support via remote config.

### Monetization & Distribution

- Google Mobile Ads (banner and interstitial).
- Remove Ads in-app purchase.
- Remote config for dynamic ad and feature toggling.

---


## Security & hardening

- **PINs are never stored in plain text.** The privacy vault hashes the PIN with a per-PIN random salt using SHA-256, verifies with a constant-time comparison, and enforces a 5-attempt / 5-minute rate limit stored in secure keychain/keystore via `flutter_secure_storage`.
- **Peer blocklist URLs are validated** before being saved or applied. Only `http`/`https` URLs with a public host are accepted, mitigating SSRF and accidental local-network probing.
- **In-app update checks are hardened** with a 15-second HTTP timeout, explicit status-code checks, safe JSON parsing, and defensive semver tag handling so a malformed GitHub release can never crash the app.
- **LAN streaming is opt-in and capability-gated.** Binding the media stream server beyond loopback requires the `enableLanStreaming` setting (off by default). Every request must present an unguessable per-session path token; unauthorised paths return `404` rather than `403` so a stream cannot be located by scanning the network.
- **The remote-control API authenticates every method.** Tokens are accepted only from the `Authorization` header (never the query string, so they cannot leak via history or logs) and are compared in constant time. No CORS headers are emitted, so a web page a user visits cannot reach the local API.
- **DLNA/SOAP payloads are XML-escaped**, including the DIDL-Lite metadata that is nested as escaped XML inside the SOAP body, so torrent file names cannot corrupt or inject into a cast request.
- **Static analysis is enforced** through `analysis_options.yaml` (`unawaited_futures`, `use_build_context_synchronously`, `close_sinks`, `cancel_subscriptions`, `avoid_dynamic_calls`, etc.) and runs in CI.

## Supported platforms

| Platform | Status | Packaging |
|----------|--------|-----------|
| Android  | ✅ Supported | APK, AAB |
| iOS      | ✅ Supported | IPA |
| macOS    | ✅ Supported | `.app` |
| Windows  | ✅ Supported | `.exe` (Inno Setup), `.msix` |
| Linux    | ✅ Supported | `.zip` tarball |
| Linux ARM64 | ✅ Supported | `.zip` tarball |

---

## Download

Pre-built release artifacts are available on the [Releases](https://github.com/teamantigravity/gravity-torrent/releases) page. Every push and tag also builds artifacts automatically through GitHub Actions.

---

## Development setup

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **>=3.44.0** (SDK constraint `>=3.5.3 <4.0.0`)
- A working C++ toolchain for native builds
- Platform SDKs for your target (Android Studio, Xcode, Visual Studio, or Linux desktop dependencies)

### Clone and install

```bash
git clone https://github.com/teamantigravity/gravity-torrent.git
cd gravity-torrent/app
flutter pub get
flutter gen-l10n
```

### Linux desktop dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
  ninja-build \
  libgtk-3-dev \
  libcurl4-openssl-dev \
  libmpv-dev \
  mpv \
  libayatana-appindicator3-dev
```

### Build

| Target | Command |
|--------|---------|
| Android APK | `flutter build apk` |
| Android AAB | `flutter build appbundle` |
| iOS | `flutter build ios` |
| macOS | `flutter build macos` |
| Windows | `flutter build windows` |
| Linux | `flutter build linux` |

CI builds additionally use `--dart-define-from-file=preview.env` (or `production.env` on release tags) and `--obfuscate --split-debug-info=build/symbols`.

---

## Testing

```bash
cd app
flutter gen-l10n
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

---

## CI/CD

- **CI** (`.github/workflows/ci.yml`) runs on `main` and pull requests: `flutter pub get`, `flutter gen-l10n`, `dart format`, `flutter analyze`, `flutter test`.
- **Build apps** (`.github/workflows/build-apps.yml`) builds release artifacts for Android, iOS, macOS, Windows, Linux x64, and Linux ARM64 on every push and tag. Artifacts are uploaded automatically.

---

## Project structure

```
gravity-torrent/
├── app/                 # Flutter application
│   ├── lib/             # Dart source code
│   ├── test/            # Unit tests
│   ├── assets/          # Icons, images, and platform resources
│   └── pubspec.yaml     # Flutter package definition
├── .github/workflows/   # GitHub Actions
└── README.md
```

### Tech stack

- **Flutter** + **Dart** for the cross-platform UI.
- **Transmission** via [`flutter_libtransmission`](https://github.com/G-Ray/flutter_libtransmission) for the BitTorrent engine.
- **Provider** + **get_it** for state management and service location.
- **go_router** for declarative routing.
- **media_kit** for audio/video playback.
- **audio_service** for background media sessions.
- **shelf** for the local HTTP server.
- **fl_chart** for data usage charts.
- **local_auth** + **flutter_secure_storage** for biometric app lock and secure storage.

---

## Contributing

Contributions are welcome. Please open an issue or pull request on [GitHub](https://github.com/teamantigravity/gravity-torrent).

When contributing, make sure the quality checks pass:

```bash
cd app
dart format lib test
flutter analyze
flutter test
```

---

## License

See the repository's license file for details.

---

<p align="center">
  Built by <a href="https://teamantigravity.vercel.app/">Team Antigravity</a>
</p>
