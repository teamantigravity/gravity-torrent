import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// A single RSS feed configuration.
class RssFeed {
  final String url;
  final String keyword; // empty = match all entries
  final bool enabled;

  const RssFeed({required this.url, this.keyword = '', this.enabled = true});

  Map<String, dynamic> toJson() => {
        'url': url,
        'keyword': keyword,
        'enabled': enabled,
      };

  factory RssFeed.fromJson(Map<String, dynamic> json) => RssFeed(
        url: (json['url'] as String?) ?? '',
        keyword: (json['keyword'] as String?) ?? '',
        enabled: (json['enabled'] as bool?) ?? true,
      );
}

/// RSS auto-download service.
///
/// Polls configured RSS feeds periodically and auto-adds matching torrents
/// (magnet links or .torrent URLs) to the engine. All processing is local —
/// no data is uploaded to any server.
class RssService {
  RssService._();
  static final RssService instance = RssService._();

  static const _feedsKey = 'gravity_torrent_rss_feeds';
  static const _seenKey = 'gravity_torrent_rss_seen';
  static const _pollMinutes = 30;
  static const _maxSeenLinks = 1000;

  List<RssFeed> _feeds = [];
  // Dart's default Set is a LinkedHashSet, so skip() keeps the [_maxSeenLinks]
  // most recently inserted links. Explicit type to make the assumption visible.
  Set<String> _seenLinks = <String>{};
  bool _loaded = false;
  Timer? _timer;

  List<RssFeed> get feeds => List.unmodifiable(_feeds);

  Future<void> load() async {
    if (_loaded) return;
    final rawFeeds = await SharedPrefsStorage.getString(_feedsKey);
    if (rawFeeds != null && rawFeeds.isNotEmpty) {
      try {
        final list = jsonDecode(rawFeeds) as List<dynamic>;
        _feeds = list
            .whereType<Map>()
            .map((e) => RssFeed.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Failed to load RSS feeds: $e\n$s');
        }
        _feeds = [];
      }
    }
    final rawSeen = await SharedPrefsStorage.getString(_seenKey);
    if (rawSeen != null && rawSeen.isNotEmpty) {
      try {
        final list = jsonDecode(rawSeen) as List<dynamic>;
        _seenLinks = LinkedHashSet<String>.from(
          list.map((e) => e.toString()),
        );
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Failed to load seen links: $e\n$s');
        }
        _seenLinks = {};
      }
    }
    _trimSeenLinks();
    _loaded = true;
  }

  Future<void> _saveFeeds() async {
    await SharedPrefsStorage.setString(
      _feedsKey,
      jsonEncode(_feeds.map((f) => f.toJson()).toList()),
    );
  }

  void _trimSeenLinks() {
    if (_seenLinks.length <= _maxSeenLinks) return;
    _seenLinks = LinkedHashSet<String>.from(
      _seenLinks.skip(_seenLinks.length - _maxSeenLinks),
    );
  }

  Future<void> _saveSeen() async {
    await SharedPrefsStorage.setString(
      _seenKey,
      jsonEncode(_seenLinks.toList()),
    );
  }

  Future<void> addFeed(RssFeed feed) async {
    await load();
    _feeds.add(feed);
    await _saveFeeds();
  }

  Future<void> removeFeedAt(int index) async {
    await load();
    if (index >= 0 && index < _feeds.length) {
      _feeds.removeAt(index);
      await _saveFeeds();
    }
  }

  Future<void> removeFeed(RssFeed feed) async {
    await load();
    _feeds.removeWhere((f) => f.url == feed.url && f.keyword == feed.keyword);
    await _saveFeeds();
  }

  Future<void> updateFeedAt(int index, RssFeed feed) async {
    await load();
    if (index >= 0 && index < _feeds.length) {
      _feeds[index] = feed;
      await _saveFeeds();
    }
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: _pollMinutes),
      (_) => pollNow(),
    );
    pollNow(); // poll immediately
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> setEnabled(bool value) async {
    await load();
    if (value) {
      startPolling();
    } else {
      stopPolling();
    }
  }

  Future<void> pollNow() async {
    await load();
    if (!RemoteConfigService.instance.isFeatureEnabled(
      'enableRssAutoDownload',
    )) {
      stopPolling();
      return;
    }
    for (final feed in List.of(_feeds)) {
      if (!feed.enabled) continue;
      try {
        await _pollFeed(feed);
      } catch (e) {
        if (kDebugMode) debugPrint('RssService poll error for ${feed.url}: $e');
      }
    }
  }

  Future<void> _pollFeed(RssFeed feed) async {
    final response = await http
        .get(Uri.parse(feed.url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return;

    final body = response.body;

    try {
      final document = XmlDocument.parse(body);
      final items = document.findAllElements('item').toList();
      if (items.isEmpty) {
        await _processSection(feed, body);
      } else {
        for (final item in items) {
          await _processItem(feed, item);
        }
      }
    } on XmlParserException catch (e) {
      if (kDebugMode) {
        debugPrint('RssService: XML parse failed for ${feed.url}: $e');
      }
      // Fallback to regex on raw body for non-XML feeds.
      await _processSection(feed, body);
    }

    _trimSeenLinks();

    await _saveSeen();
  }

  Future<void> _processItem(RssFeed feed, XmlElement item) async {
    final text = item.innerText;
    final candidates = candidateLinks(item, text);
    await _processCandidates(feed, candidates, text);
  }

  Future<void> _processSection(RssFeed feed, String section) async {
    final candidates = candidateLinks(null, section);
    await _processCandidates(feed, candidates, section);
  }

  Future<void> _processCandidates(
    RssFeed feed,
    List<String> candidates,
    String contextText,
  ) async {
    for (final link in candidates) {
      if (_seenLinks.contains(link)) continue;

      // Apply keyword filter per item/section
      if (feed.keyword.isNotEmpty &&
          !contextText.toLowerCase().contains(feed.keyword.toLowerCase())) {
        continue;
      }

      _seenLinks.add(link);

      try {
        if (!(await QuotaService.instance.canAddTorrent())) {
          if (kDebugMode) {
            debugPrint('RssService: quota exceeded, skipping $link');
          }
          _seenLinks.remove(link);
          continue;
        }
        if (!getIt.isRegistered<Engine>()) {
          _seenLinks.remove(link);
          continue;
        }
        final engine = getIt<Engine>();
        // Transmission accepts both magnet links and .torrent URLs in the
        // filename argument.
        await engine.addTorrent(link, null, null);
        if (kDebugMode) debugPrint('RssService: auto-added $link');
      } catch (e) {
        if (kDebugMode) debugPrint('RssService: failed to add $link: $e');
        _seenLinks.remove(link); // retry next poll
      }
    }
  }

  /// Extracts magnet links and .torrent URLs from the given [text] and from
  /// common RSS child elements such as `<link>`, `<enclosure url="...">`, and
  /// namespaced `<torrent:magnetURI>`.
  @visibleForTesting
  List<String> candidateLinks(XmlElement? item, String text) {
    final raw = <String>{};

    // Extract from raw text (handles CDATA content as well).
    final magnetPattern = RegExp(r'magnet:\?[^\s"<>]+', caseSensitive: false);
    final torrentPattern = RegExp(
      r'https?://[^\s"<>]+\.torrent',
      caseSensitive: false,
    );
    raw.addAll(magnetPattern.allMatches(text).map((m) => m.group(0)!));
    raw.addAll(torrentPattern.allMatches(text).map((m) => m.group(0)!));

    if (item != null) {
      for (final element in item.findElements('link')) {
        raw.add(element.innerText.trim());
      }
      for (final enclosure in item.findElements('enclosure')) {
        final url = enclosure.getAttribute('url');
        if (url != null && url.isNotEmpty) raw.add(url);
      }
      for (final magnetUri in item.findAllElements('magnetURI')) {
        final uri = magnetUri.innerText.trim();
        if (uri.isNotEmpty) raw.add(uri);
      }
    }

    return raw.where(isTorrentLink).toList();
  }

  @visibleForTesting
  bool isTorrentLink(String link) {
    final lower = link.toLowerCase();
    return lower.startsWith('magnet:') || lower.endsWith('.torrent');
  }
}
