# Changelog

## Player & casting overhaul

### Fixed

- **Streaming no longer hangs on startup.** `StreamingServer.start()` and `SubtitlesServer.start()` run the HTTP accept loop, so they only return once the socket closes. Player initialisation awaited them, which meant `player.open(...)` was never reached and playback never began. Both are now started without awaiting, and the player waits on the server-ready signal instead.
- **DLNA / UPnP casting actually casts.** The casting service previously only flipped an `isCasting` flag; no UPnP request was ever sent. It now performs real SSDP discovery, fetches and parses each device description (resolving the friendly name and `AVTransport:1` control endpoint, honouring `URLBase`), and drives the renderer with `SetAVTransportURI` and `Play`.
- **Cast discovery no longer lists devices that cannot play.** Renderers are only offered when they advertise an `AVTransport:1` control URL, and they are shown with their real friendly name instead of `Smart TV / DLNA (<ip>)`.
- **Casting is reachable on desktop.** The cast button existed only in the mobile control bar.
- **The playback queue is no longer always empty.** Nothing ever populated it, so the queue sheet was unreachable and `Play next` did nothing.
- **Resume positions are saved and restored again.** Persistence was gated on the current queue item, which was always `null`, so no position was ever written. Positions are also keyed by a SHA-1 digest instead of `String.hashCode`, which is not stable across Dart SDK versions and collides easily.
- **Reordering the queue no longer drops items one slot too far.** `ReorderableListView` reports the insertion index before the dragged row is removed, which needs a downward-drag adjustment.
- **Subtitle requests are served concurrently.** The accept loop awaited each request, so one stalled client blocked every other subtitle fetch.
- **Cast state no longer goes stale.** The cast button listens to the service rather than relying on a captured `setState`.

### Security

- **LAN streaming is protected by a capability token.** The stream server can bind to every interface so a TV can reach it; every request must now present an unguessable, per-session path token, and unauthorised paths get a `404` so the stream cannot be discovered by scanning. Previously the LAN option existed but was never enabled by any caller.
- **LAN streaming is opt-in.** A new `enableLanStreaming` flag (off by default, with the usual remote kill-switch) gates binding beyond loopback, and Settings explains the trade-off.
- **Removed an authentication bypass in the remote-control API.** `OPTIONS` requests skipped the token middleware to support a CORS preflight that could never work (no `Access-Control-Allow-Origin` was ever sent). All methods now authenticate, and cross-origin browser access stays disabled by design so a visited web page cannot drive a user's torrent session.
- **DLNA payloads are XML-escaped.** Titles and URLs are escaped for both the SOAP body and the nested DIDL-Lite metadata, so a file name containing `&` or `<` cannot corrupt the request.

### Added

- **Cast transport controls** — pause, resume, seek, and renderer volume over `AVTransport:1` / `RenderingControl:1`, surfaced in a control sheet; local playback pauses automatically so a title never plays twice at once.
- **Episode-aware playback queue** — the queue is built from the torrent's playable files using natural ordering, so `E2` comes before `E10`, and release-group `sample` clips are skipped unless nothing else is playable.
- **Auto-play the next file** — completing a file advances the queue, rebuilding the streaming pipeline for the next one, with per-file resume positions.
- **Clear casting diagnostics** — failures explain themselves (unreachable stream, renderer refused, timeout) instead of silently doing nothing, including a hint when LAN streaming is off.

## Recent updates

A continuous stream of cross-platform, privacy-first improvements added to the main torrents and settings experience. All data stays on the device; no analytics or remote calls are made beyond the existing AdMob and optional update-check flows.

- **Live session speed & transfer totals** — see aggregate download/upload speed and lifetime downloaded/uploaded bytes at the top of the torrent list.
- **Visible/total torrent count** — header shows `X of Y torrents` while filtering or searching; can be toggled from Settings.
- **Status filter chips** — quick-filter the list by stopped, checking, downloading, seeding, and queued states; each chip shows the matching torrent count.
- **Recent search queries** — search terms are saved locally and shown as quick-select chips under the search bar; they can be cleared from the chip row or Settings.
- **Recent download directories** — frequently used save paths are remembered locally and can be cleared from the Add torrent chip row or Settings.
- **Copy & share torrent links** — copy a magnet link, info hash, or name from the desktop list tile copy popup menu or details; copy or share one or many selected torrents via the multi-select popup menu.
- **Copy torrent name, info hash, labels, creator, comment, download directory, size, piece count/size, peers count, downloaded/uploaded bytes, ratio, state, privacy status, remaining time, added date, and error string** — each has a copy button in the details tab.
- **Copy app version** — copy the full `version+build` from Settings.
- **Keyboard shortcuts** — `Ctrl`/`Cmd` + `N` open *Add torrent*, `Ctrl`/`Cmd` + `R` refresh the list, `Ctrl`/`Cmd` + `A` select all visible torrents, `Ctrl`/`Cmd` + `F` focus the search field, `Ctrl`/`Cmd` + `K` clear the search field, `Ctrl`/`Cmd` + `S` open the sort dialog, `Ctrl`/`Cmd` + `,` open Settings, `Esc` exits multi-select mode, and `Delete` removes the selected torrents.
- **Add torrent from empty state** — a prominent button appears when no torrents exist yet.
- **Clear favorites & notes** — clear all locally-stored favorite torrents and per-torrent notes from Settings.
- **Compact list density** — switch to a denser torrent list layout from Settings.
- **Show/hide torrent labels** — toggle label chips in the torrent list from Settings.
- **Show/hide status filter chips** — toggle the status filter chip row from Settings.
- **Show/hide recent search queries** — toggle the recent search query chip row from Settings.
- **Show/hide live speed header** — toggle the live download/upload speed and totals row from Settings.
- **Show/hide torrent health badge** — toggle the health/peer count badge on each list tile from Settings.
- **Favorites-only filter** — tap the star icon in the torrent list action bar to toggle between all torrents and favorited ones; favorites remain pinned to the top when the filter is off.
- **Local "What's New" dialog** — shown once per app version after launch; content is bundled in the app, no remote fetch.

