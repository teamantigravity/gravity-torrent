import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:gravity_torrent/services/rss_episode_parser.dart';
import 'package:gravity_torrent/services/rss_rule.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:gravity_torrent/utils/ip_address.dart';
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
  static const _rulesKey = 'gravity_torrent_rss_rules';
  static const _seenKey = 'gravity_torrent_rss_seen';
  static const _episodeHistoryKey = 'gravity_torrent_rss_episode_history';
  static const _pollMinutes = 30;
  static const _maxSeenLinks = 1000;
  static const _maxEpisodeHistory = 2000;
  static const _maxFeedBytes = 2 * 1024 * 1024;
  static const _maxItemsPerFeed = 500;
  static const _maxLinksPerFeed = 100;
  static const _maxLinksPerItem = 25;

  List<RssFeed> _feeds = [];
  List<RssRule> _rules = [];
  // Dart's default Set is a LinkedHashSet, so skip() keeps the [_maxSeenLinks]
  // most recently inserted links. Explicit type to make the assumption visible.
  Set<String> _seenLinks = <String>{};
  Set<String> _episodeHistory = <String>{};
  bool _loaded = false;
  bool _isPolling = false;
  bool _disposed = false;
  Timer? _timer;

  List<RssFeed> get feeds => List.unmodifiable(_feeds);
  List<RssRule> get rules => List.unmodifiable(_rules);

  Future<void> load() async {
    if (_disposed || _loaded) return;
    final rawFeeds = await SharedPrefsStorage.getString(_feedsKey);
    if (rawFeeds != null && rawFeeds.isNotEmpty) {
      try {
        final list = jsonDecode(rawFeeds) as List<dynamic>;
        _feeds = list
            .whereType<Map<String, dynamic>>()
            .map((e) => RssFeed.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Failed to load RSS feeds: $e\n$s');
        }
        _feeds = [];
      }
    }
    final rawRules = await SharedPrefsStorage.getString(_rulesKey);
    if (rawRules != null && rawRules.isNotEmpty) {
      try {
        final list = jsonDecode(rawRules) as List<dynamic>;
        _rules = list
            .whereType<Map<String, dynamic>>()
            .map((e) => RssRule.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        // Sort by priority (higher priority first)
        _rules.sort((a, b) => b.priority.compareTo(a.priority));
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Failed to load RSS rules: $e\n$s');
        }
        _rules = [];
      }
    }
    final rawSeen = await SharedPrefsStorage.getString(_seenKey);
    if (rawSeen != null && rawSeen.isNotEmpty) {
      try {
        final list = jsonDecode(rawSeen) as List<dynamic>;
        _seenLinks = LinkedHashSet<String>.from(list.map((e) => e.toString()));
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Failed to load seen links: $e\n$s');
        }
        _seenLinks = {};
      }
    }
    final rawEpisodeHistory = await SharedPrefsStorage.getString(
      _episodeHistoryKey,
    );
    if (rawEpisodeHistory != null && rawEpisodeHistory.isNotEmpty) {
      try {
        final list = jsonDecode(rawEpisodeHistory) as List<dynamic>;
        _episodeHistory = LinkedHashSet<String>.from(
          list.map((e) => e.toString()),
        );
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Failed to load episode history: $e\n$s');
        }
        _episodeHistory = {};
      }
    }
    if (_disposed) return;
    _trimSeenLinks();
    _loaded = true;
  }

  Future<void> _saveFeeds() async {
    await SharedPrefsStorage.setString(
      _feedsKey,
      jsonEncode(_feeds.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> _saveRules() async {
    await SharedPrefsStorage.setString(
      _rulesKey,
      jsonEncode(_rules.map((r) => r.toJson()).toList()),
    );
  }

  void _trimSeenLinks() {
    if (_seenLinks.length <= _maxSeenLinks) return;
    _seenLinks = LinkedHashSet<String>.from(
      _seenLinks.skip(_seenLinks.length - _maxSeenLinks),
    );
  }

  void _trimEpisodeHistory() {
    if (_episodeHistory.length <= _maxEpisodeHistory) return;
    _episodeHistory = LinkedHashSet<String>.from(
      _episodeHistory.skip(_episodeHistory.length - _maxEpisodeHistory),
    );
  }

  Future<void> _saveSeen() async {
    await SharedPrefsStorage.setString(
      _seenKey,
      jsonEncode(_seenLinks.toList()),
    );
  }

  Future<void> _saveEpisodeHistory() async {
    await SharedPrefsStorage.setString(
      _episodeHistoryKey,
      jsonEncode(_episodeHistory.toList()),
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

  Future<void> addRule(RssRule rule) async {
    await load();
    _rules.add(rule);
    _rules.sort((a, b) => b.priority.compareTo(a.priority));
    await _saveRules();
  }

  Future<void> removeRuleAt(int index) async {
    await load();
    if (index >= 0 && index < _rules.length) {
      _rules.removeAt(index);
      await _saveRules();
    }
  }

  Future<void> removeRule(RssRule rule) async {
    await load();
    _rules.removeWhere((r) => r.name == rule.name);
    await _saveRules();
  }

  Future<void> updateRuleAt(int index, RssRule rule) async {
    await load();
    if (index >= 0 && index < _rules.length) {
      _rules[index] = rule;
      _rules.sort((a, b) => b.priority.compareTo(a.priority));
      await _saveRules();
    }
  }

  void startPolling() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: _pollMinutes),
      (_) => unawaited(pollNow()),
    );
    unawaited(pollNow()); // poll immediately
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    stopPolling();
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed) return;
    await load();
    if (_disposed) return;
    if (value) {
      startPolling();
    } else {
      stopPolling();
    }
  }

  Future<void> pollNow() async {
    if (_isPolling) return;
    _isPolling = true;
    try {
      await load();
      if (_disposed) return;
      if (!RemoteConfigService.instance.isFeatureEnabled(
        'enableRssAutoDownload',
      )) {
        stopPolling();
        return;
      }

      // Collect all unique feed URLs from rules
      final feedUrls = <String>{};
      for (final rule in _rules) {
        if (rule.enabled) {
          feedUrls.addAll(rule.feedUrls);
        }
      }

      // Also include legacy feeds
      for (final feed in _feeds) {
        if (feed.enabled) {
          feedUrls.add(feed.url);
        }
      }

      // Poll each unique feed URL
      for (final feedUrl in feedUrls) {
        if (_disposed) return;
        if (!await _isValidFeedUrl(feedUrl)) continue;
        try {
          await _pollFeed(feedUrl);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('RssService poll error for $feedUrl: $e');
          }
        }
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<bool> _isValidFeedUrl(String url) async {
    try {
      if (url.length > 4096) return false;
      final uri = Uri.parse(url);
      if (!(uri.isScheme('http') || uri.isScheme('https'))) return false;
      if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
      return await IpAddressScope.isPubliclyRoutableHost(uri.host);
    } catch (_) {
      return false;
    }
  }

  Future<void> _pollFeed(String feedUrl) async {
    final response = await _safeGet(feedUrl);
    if (_disposed || response == null || response.statusCode != 200) return;

    final body = response.body;

    try {
      final document = XmlDocument.parse(body);
      final items = document.findAllElements('item').toList();
      if (items.isEmpty) {
        await _processSection(feedUrl, body, maxCandidates: _maxLinksPerFeed);
      } else {
        var remainingLinks = _maxLinksPerFeed;
        for (final item in items.take(_maxItemsPerFeed)) {
          if (remainingLinks == 0) break;
          remainingLinks -= await _processItem(
            feedUrl,
            item,
            maxCandidates: remainingLinks,
          );
        }
      }
    } on XmlParserException catch (e) {
      if (kDebugMode) {
        debugPrint('RssService: XML parse failed for $feedUrl: $e');
      }
      // Fallback to regex on raw body for non-XML feeds.
      await _processSection(feedUrl, body, maxCandidates: _maxLinksPerFeed);
    }

    _trimSeenLinks();
    _trimEpisodeHistory();

    await _saveSeen();
    await _saveEpisodeHistory();
  }

  /// Fetches a URL without blindly following redirects. Each redirect target
  /// is validated so a public feed cannot redirect to an internal host.
  Future<http.Response?> _safeGet(String url, {int redirectCount = 0}) async {
    const maxRedirects = 5;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
    if (!await IpAddressScope.isPubliclyRoutableHost(uri.host)) return null;

    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0;
      final streamed =
          await client.send(request).timeout(const Duration(seconds: 15));
      final body = BytesBuilder(copy: false);
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      await for (final chunk in streamed.stream.timeout(
        const Duration(seconds: 15),
      )) {
        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('RSS response body timed out');
        }
        if (body.length + chunk.length > _maxFeedBytes) return null;
        body.add(chunk);
      }
      final response = http.Response.bytes(
        body.takeBytes(),
        streamed.statusCode,
        request: streamed.request,
        headers: streamed.headers,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );

      if (response.statusCode >= 300 && response.statusCode < 400) {
        if (redirectCount >= maxRedirects) return null;
        final location = response.headers['location'];
        if (location == null || location.isEmpty) return null;
        final resolved = uri.resolve(location);
        return await _safeGet(
          resolved.toString(),
          redirectCount: redirectCount + 1,
        );
      }

      return response;
    } on TimeoutException {
      if (kDebugMode) debugPrint('RssService: timeout fetching $url');
      return null;
    } on SocketException {
      if (kDebugMode) debugPrint('RssService: cannot reach $url');
      return null;
    } on FormatException {
      return null;
    } finally {
      client.close();
    }
  }

  Future<int> _processItem(
    String feedUrl,
    XmlElement item, {
    required int maxCandidates,
  }) async {
    final text = item.innerText;
    final candidates = candidateLinks(item, text).take(maxCandidates).toList();
    await _processCandidates(feedUrl, candidates, text);
    return candidates.length;
  }

  Future<void> _processSection(
    String feedUrl,
    String section, {
    required int maxCandidates,
  }) async {
    final candidates = candidateLinks(
      null,
      section,
    ).take(maxCandidates).toList();
    await _processCandidates(feedUrl, candidates, section);
  }

  Future<void> _processCandidates(
    String feedUrl,
    List<String> candidates,
    String contextText,
  ) async {
    for (final link in candidates) {
      if (_seenLinks.contains(link)) continue;

      // Apply rules to determine if this link should be added
      bool shouldAdd = false;
      RssRule? matchingRule;

      for (final rule in _rules) {
        if (!rule.enabled) continue;
        if (!rule.feedUrls.contains(feedUrl)) continue;

        if (_matchesRule(rule, contextText, link)) {
          shouldAdd = true;
          matchingRule = rule;
          break; // First matching rule wins (sorted by priority)
        }
      }

      // Fallback to legacy feed-based filtering
      if (!shouldAdd) {
        try {
          final feed = _feeds.firstWhere((f) => f.url == feedUrl);
          if (feed.enabled) {
            if (feed.keyword.isEmpty ||
                contextText.toLowerCase().contains(
                      feed.keyword.toLowerCase(),
                    )) {
              shouldAdd = true;
            }
          }
        } catch (_) {
          // Feed not found, skip
        }
      }

      if (!shouldAdd) continue;

      _seenLinks.add(link);

      try {
        if (!await IpAddressScope.isPubliclyRoutableLink(link)) {
          if (kDebugMode) {
            debugPrint('RssService: rejected private/internal link $link');
          }
          // DNS can be temporarily unavailable. Retry on the next poll rather
          // than permanently marking a valid feed item as seen.
          _seenLinks.remove(link);
          continue;
        }
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

        // Record an episode only after the torrent add succeeds. Failed or
        // quota-blocked attempts must remain eligible for a later poll.
        final episodeInfo = RssEpisodeParser.parse(contextText);
        if (episodeInfo != null) {
          _episodeHistory.add(episodeInfo.key);
        }

        // Update last match time for the matching rule
        if (matchingRule != null) {
          final ruleName = matchingRule.name;
          final ruleIndex = _rules.indexWhere((r) => r.name == ruleName);
          if (ruleIndex >= 0) {
            _rules[ruleIndex] = _rules[ruleIndex].copyWith(
              lastMatch: DateTime.now(),
            );
            await _saveRules();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('RssService: failed to add $link: $e');
        // Retain link in _seenLinks so broken items do not loop infinitely
      }
    }
  }

  bool _matchesRule(RssRule rule, String contextText, String link) {
    final lowerText = contextText.toLowerCase();

    // Must contain filters
    if (rule.mustContain.isNotEmpty) {
      final mustContainTerms = rule.mustContain.split(RegExp(r'\s+'));
      for (final term in mustContainTerms) {
        if (term.isEmpty) continue;
        if (rule.useRegex) {
          try {
            if (!RegExp(term, caseSensitive: false).hasMatch(contextText)) {
              return false;
            }
          } catch (e) {
            // Invalid regex, treat as literal
            if (!lowerText.contains(term.toLowerCase())) {
              return false;
            }
          }
        } else {
          if (!lowerText.contains(term.toLowerCase())) {
            return false;
          }
        }
      }
    }

    // Must not contain filters
    if (rule.mustNotContain.isNotEmpty) {
      final mustNotContainTerms = rule.mustNotContain.split(RegExp(r'\s+'));
      for (final term in mustNotContainTerms) {
        if (term.isEmpty) continue;
        if (rule.useRegex) {
          try {
            if (RegExp(term, caseSensitive: false).hasMatch(contextText)) {
              return false;
            }
          } catch (e) {
            // Invalid regex, treat as literal
            if (lowerText.contains(term.toLowerCase())) {
              return false;
            }
          }
        } else {
          if (lowerText.contains(term.toLowerCase())) {
            return false;
          }
        }
      }
    }

    // Episode history check
    final episodeInfo = RssEpisodeParser.parse(contextText);
    if (episodeInfo != null) {
      if (_episodeHistory.contains(episodeInfo.key)) {
        return false;
      }
    }

    return true;
  }

  /// Extracts magnet links and .torrent URLs from the given [text] and from
  /// common RSS child elements such as `<link>`, `<enclosure url="...">`, and
  /// namespaced `<torrent:magnetURI>`.
  @visibleForTesting
  List<String> candidateLinks(XmlElement? item, String text) {
    final raw = <String>{};
    final verified = <String>{};

    // Extract from raw text (handles CDATA content as well).
    final magnetPattern = RegExp(r'magnet:\?[^\s"<>]+', caseSensitive: false);
    final torrentPattern = RegExp(
      r'https?://[^\s"<>]+\.torrent(?:\?[^\s"<>]*)?',
      caseSensitive: false,
    );
    raw.addAll(
      magnetPattern
          .allMatches(text)
          .take(_maxLinksPerItem)
          .map((m) => m.group(0)!),
    );
    raw.addAll(
      torrentPattern
          .allMatches(text)
          .take(_maxLinksPerItem)
          .map((m) => m.group(0)!),
    );

    if (item != null) {
      for (final element in item.findElements('link')) {
        if (raw.length + verified.length >= _maxLinksPerItem) break;
        raw.add(element.innerText.trim());
      }
      for (final enclosure in item.findElements('enclosure')) {
        if (raw.length + verified.length >= _maxLinksPerItem) break;
        final url = enclosure.getAttribute('url');
        final type = enclosure.getAttribute('type');
        if (url != null && url.isNotEmpty) {
          if (type != null &&
              type.toLowerCase() == 'application/x-bittorrent') {
            verified.add(url);
          } else {
            raw.add(url);
          }
        }
      }
      for (final magnetUri in item.findAllElements('magnetURI')) {
        if (raw.length + verified.length >= _maxLinksPerItem) break;
        final uri = magnetUri.innerText.trim();
        if (uri.isNotEmpty) raw.add(uri);
      }
    }

    final result = raw.where(isTorrentLink).toSet();
    result.addAll(verified);
    return result.take(_maxLinksPerItem).toList();
  }

  @visibleForTesting
  bool isTorrentLink(String link) {
    final trimmed = link.trim();
    if (trimmed.toLowerCase().startsWith('magnet:')) return true;
    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.isEmpty) return false;
      if (!(uri.isScheme('http') || uri.isScheme('https'))) return false;
      return uri.path.toLowerCase().endsWith('.torrent');
    } catch (_) {
      return false;
    }
  }
}
