# Gauntlet Loop — Gravity Torrent SOTA Features

## Baseline

- Target bar: qBittorrent 4.4.1 + libtorrent-rasterbar 2.0.5
- Floor bar: Transmission 3.00
- Reference repos cloned to `/root/bars/qbittorrent`, `/root/bars/libtorrent`, `/root/bars/transmission`

## Current round - SOTA Feature Implementation

### Completed Features

**Feature 1: Torrent management enhancements** ✅
- Added per-torrent seeding limits (seedRatioMode, seedRatioLimit)
- Added per-torrent idle seeding (seedIdleMode, seedIdleLimit)
- Added session limits override (honorsSessionLimits)
- Added queue position management (queuePosition)
- Added upload queue support to Session model
- Updated RPC field mappings and request models
- Implemented Engine and Torrent interface methods
- Files modified:
  - `lib/engine/transmission/models/torrent.dart` - added fields
  - `lib/engine/transmission/models/torrent_get_request.dart` - field mappings
  - `lib/engine/transmission/models/torrent_set_request.dart` - request parameters
  - `lib/engine/torrent.dart` - abstract methods
  - `lib/engine/transmission/transmission.dart` - implementation
  - `lib/engine/engine.dart` - Engine interface
  - `lib/engine/session.dart` - upload queue fields

**Feature 2: RSS automation enhancements** ✅
- Created RssRule model with priority, must contain/must not contain filters
- Added regex support for pattern matching
- Created RssEpisodeParser for episode detection (S01E01, 1x01, date formats)
- Implemented episode history tracking to prevent duplicates
- Added rule-based system with priority ordering
- Multi-feed rule support (one rule can apply to multiple feeds)
- Last match tracking per rule
- Files created:
  - `lib/services/rss_rule.dart` - rule model
  - `lib/services/rss_episode_parser.dart` - episode parser
- Files modified:
  - `lib/services/rss_service.dart` - rule-based processing

**Feature 3: Search integration** ✅
- Created SearchService with search engine management
- Added SearchResult model with torrent metadata
- Added SearchEngine model for custom search engines
- Implemented search history tracking
- Default engines: The Pirate Bay, 1337x, RARBG
- Files created:
  - `lib/services/search_service.dart` - search service

**Feature 4: Bandwidth scheduling enhancements** ✅
- Added LAN exclusion option (ignoreLimitsOnLAN)
- Added overhead inclusion option (includeOverheadInLimits)
- Updated Session model with bandwidth options
- Updated Transmission RPC field mappings
- Files modified:
  - `lib/engine/session.dart` - bandwidth options
  - `lib/engine/transmission/models/session_get_request.dart` - field mappings
  - `lib/engine/transmission/models/session_set_request.dart` - request parameters
  - `lib/engine/transmission/models/session_get_response.dart` - response parsing
  - `lib/engine/transmission/transmission.dart` - implementation

**Feature 5: Remote control enhancements** ✅
- Added ApiKey model for API key management
- Added RemoteControlSettings for security options
- Implemented API key CRUD operations
- Added support for X-API-Key header authentication
- Added settings for auth requirement, local network access, and API key mode
- Added last-used tracking for API keys
- Files modified:
  - `lib/services/remote_control_service.dart` - API key management and settings

**Feature 6: Streaming enhancements** ✅
- Added preview mode option to StreamingServer
- Implemented piece priority setting for quick video preview
- Added automatic sequential download from piece on range requests
- Added automatic cleanup of sequential download on server stop
- Added preview mode that prioritizes first and last pieces
- Files modified:
  - `lib/utils/streaming_server.dart` - preview mode and piece priority
  - `lib/engine/torrent.dart` - setPriorityPieces method
  - `lib/engine/engine.dart` - setTorrentPriorityPieces method
  - `lib/engine/transmission/transmission.dart` - implementation

**Feature 7: DLNA casting enhancements** ✅
- Added device favorites with persistent storage
- Implemented auto-discovery with configurable interval
- Added settings for auto-discovery enable/disable
- Added favorite device filtering
- Files modified:
  - `lib/services/casting_service.dart` - favorites and auto-discovery

**Previous security fixes** ✅
- SSRF/IP validation hardening (IpAddressScope class)
- Constant-time comparison and PIN hashing (PBKDF2-HMAC-SHA256)
- BackupService encryption hardening (AES-GCM + PBKDF2)
- StreamingServer range parsing fixes
- SubtitlesServer token authentication

### In Progress

**Feature 4: Bandwidth scheduling enhancements** - pending
**Feature 5: Remote control enhancements** - pending
**Feature 6: Streaming enhancements** - pending
**Feature 7: DLNA casting enhancements** - pending
**Feature 8: Statistics enhancements** - pending
**Feature 9: Queue management enhancements** - pending
**Feature 10: UI polish** - pending
