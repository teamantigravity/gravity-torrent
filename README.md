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

**Gravity Torrent** is a modern, cross-platform BitTorrent client built with Flutter. It is designed to be simple enough for everyday users while still providing the control advanced users expect. It is powered by the Transmission backend via [`flutter_libtransmission`](https://github.com/G-Ray/flutter_libtransmission) and can stream media files while they download.

---

## Features

### Core torrenting

- Add torrents from **magnet links**, `.torrent` files, or **app/deep links**.
- Browse all active and inactive torrents with live progress, speed, and status.
- **Start, pause, remove** and **share** magnet links for any torrent.
- **Bulk remove** multiple torrents at once.
- **Filter and search** by label or text; sort by added date, progress, or size.
- **File-level control** — select which files to download and set priority per file.
- **Per-torrent speed limits** and **sequential download** for media streaming.

### Media streaming

- **Stream video and audio** directly from an incomplete torrent using the built-in player.
- **Local streaming server** serves file ranges with seek support.
- **Subtitles server** for external subtitle files (`.srt`, `.vtt`, `.ass`, `.ssa`, `.sub`, `.idx`), with automatic language detection.
- **Subtitle and audio track selection** during playback.

### Settings & customization

- **Theme** selection (light / dark / system).
- **Locale** / language selector.
- **Download directory** picker and **maximum active downloads** limit.
- **Global speed limits** and **Turtle mode** (scheduled alternative speed limits).
- **Privacy & security** — peer encryption, peer blocklist, DHT, PEX, LPD, and µTP toggles.
- **Seeding limits** — seed ratio and idle seeding timeout.
- **Reset** all Transmission session settings.

### SOTA cross-platform UX

- **Adaptive Material 3 UI** — dynamic color theming from the system wallpaper / accent color (Android 12+), with responsive breakpoints and an adaptive navigation rail / bottom bar.
- **Feature flags** — all new SOTA features are gated by persistent, runtime-toggleable flags. Flags are also backed by a remote kill-switch so any feature can be disabled in an emergency without an app update.
- **Smart notifications** — progress notification with live speed and pause/resume actions for all downloads, plus per-torrent completion notifications.
- **Background audio & media session** — playback continues in the background on Android, iOS and macOS, with media controls in the notification / control center / lock screen (via `audio_service`).
- **Picture-in-Picture / compact floating window** — PiP-ready on Android, with a compact always-on-top floating window fallback on desktop.
- **Haptic feedback** — subtle tactile feedback on supported mobile controls.
- **App shortcuts** — quick actions to add a torrent or open the torrent list on mobile launchers.
- **Privacy vault** — optional biometric / PIN app lock and a privacy-score dashboard.
- **Data-usage analytics** — on-device dashboard with a 7-day download/upload chart and per-torrent totals (via `fl_chart`).
- **Local remote control** — token-authenticated HTTP server on the local network, with a QR code for pairing and pause/resume/listing actions.

### Platform integration

- **Android** — foreground service for background operation, storage permission handling, content-URI import, and media session notification.
- **iOS** — default download directory handling and `audio` background mode.
- **Windows** — registry registration for `magnet:` links and `.torrent` files, plus MSIX and Inno Setup packaging.
- **macOS** — native app bundle, system tray, and media session support.
- **Linux** — GTK windowing, system tray, and AppIndicator support.
- **Desktop** — system tray with show/hide window, custom close behavior, and persistent background operation.

### Monetization & distribution

- **Google Mobile Ads** support with banner and interstitial ads.
- **Remove Ads** in-app purchase.
- **Remote config** for dynamic ad and feature toggling.
- **In-app update checks** for non-store builds.
- **Download completion notifications**.
- **Service locator** (`get_it`) for dependency injection, used by background notification handlers.

---

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

## Development setup

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **3.44.6** (SDK constraint `^3.5.3`)
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
