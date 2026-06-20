# Gravity Torrent

Gravity Torrent is a cross-platform BitTorrent client forked from [PikaTorrent](https://github.com/G-Ray/pikatorrent), rebranded and extended for Team Antigravity.

## Product highlights

- **Full PikaTorrent feature parity** — magnets, `.torrent` files, streaming, tags, notifications, tray, deep links, localization, and Transmission backend.
- **Premium monetization (mobile)** — AdMob banners with graceful failure; one-time non-consumable IAP (`gravitytorrent_remove_ads`) removes all ads permanently with restore support.
- **Per-torrent controls** — pause/resume, sequential download toggle, per-torrent upload/download speed limits (persisted by Transmission).
- **Cross-platform safety** — ads and IAP use abstract services with conditional imports (`ad_service_stub` / `ad_service_mobile`, `purchase_service_stub` / `purchase_service_mobile`). Desktop/web builds never require store SDK behavior at runtime.
- **Remote ad kill-switch** — `https://teamantigravity.com/gravity_config.json` (`show_ads`).

## CI / releases

GitHub Actions workflow `.github/workflows/ci.yml`:

1. Format check  
2. Static analysis (`flutter analyze`)  
3. Unit/widget tests  
4. Platform builds (Linux, Windows, Android; iOS unsigned with graceful `continue-on-error`)  
5. Artifact upload  
6. `latest-build-manifest.json` published to the `latest-successful-build` GitHub release tag  

The [Team Antigravity website](https://github.com/teamantigravity/teamantigravity-web) resolves downloads via `/api/latest-download?platform=…` against that release tag.

## Build defines

| Define | Purpose |
|--------|---------|
| `GRAVITY_TORRENT_AD_TEST_IDS` | Use Google test ad units (default `true` in CI) |
| `GRAVITY_TORRENT_ADMOB_APP_ID` | Production AdMob app ID |
| `GRAVITY_TORRENT_ADMOB_BANNER` | Production banner unit |
| `GRAVITY_TORRENT_ADMOB_INTERSTITIAL` | Production interstitial unit |
| `GRAVITY_TORRENT_REMOTE_CONFIG_URL` | Override remote config URL |

## Legacy migration

On first launch, Gravity Torrent copies Transmission data from legacy PikaTorrent config folders when the new config directory is empty.

## Logo

Primary mark: `assets/logo.svg` — white background, geometric four-color orbit (blue/red/yellow/green arcs) with a central nucleus. Suitable for icon, splash, favicon, and store listings.
