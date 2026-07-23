import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Service that manages P2P peer blocklist downloads and automatic updates.
class BlocklistService {
  BlocklistService._();
  static final BlocklistService instance = BlocklistService._();

  static const _enabledKey = 'gravity_torrent_blocklist_enabled';
  static const _urlKey = 'gravity_torrent_blocklist_url';
  static const _lastUpdatedKey = 'gravity_torrent_blocklist_last_updated';
  static const _rulesCountKey = 'gravity_torrent_blocklist_rules_count';

  static const defaultUrl =
      'https://raw.githubusercontent.com/Naunter/BT_BlockList/master/bt_blocklist.txt';

  bool _enabled = false;
  bool _loaded = false;
  bool _updating = false;
  String _url = defaultUrl;
  DateTime? _lastUpdated;
  int _rulesCount = 0;
  Completer<int>? _updateCompleter;

  bool get isEnabled => _enabled;
  bool get isUpdating => _updating;
  String get url => _url;
  DateTime? get lastUpdated => _lastUpdated;
  int get rulesCount => _rulesCount;

  /// Validates that [url] is a safe HTTP/HTTPS URL. Empty string is allowed
  /// and represents "no blocklist URL / disabled".
  static bool isValidBlocklistUrl(String url) {
    if (url.isEmpty) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    // Block private/local network URLs to mitigate SSRF.
    if (uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host.startsWith('192.168.') ||
        uri.host.startsWith('10.') ||
        uri.host.startsWith('172.')) {
      return false;
    }
    return true;
  }

  Future<void> load() async {
    if (_loaded) return;
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    final storedUrl = await SharedPrefsStorage.getString(_urlKey) ?? defaultUrl;
    _url = isValidBlocklistUrl(storedUrl) ? storedUrl : defaultUrl;
    final lastUpdatedStr = await SharedPrefsStorage.getString(_lastUpdatedKey);
    if (lastUpdatedStr != null) {
      _lastUpdated = DateTime.tryParse(lastUpdatedStr);
    }
    _rulesCount = (await SharedPrefsStorage.getString(_rulesCountKey)
            .then((s) => s != null ? int.tryParse(s) : null)) ??
        0;
    _loaded = true;
  }

  Future<void> setEnabled(bool enabled) async {
    await load();
    _enabled = enabled;
    await SharedPrefsStorage.setBool(_enabledKey, enabled);
    try {
      if (!getIt.isRegistered<Engine>()) return;
      final engine = getIt<Engine>();
      final session = await engine.fetchSession();
      await session.update(SessionBase(
        blocklistEnabled: enabled,
        blocklistUrl: _url,
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('BlocklistService setEnabled error: $e');
    }
  }

  Future<void> setUrl(String url) async {
    await load();
    final trimmed = url.trim();
    if (!isValidBlocklistUrl(trimmed)) {
      throw ArgumentError('Invalid or unsafe blocklist URL: $trimmed');
    }
    _url = trimmed;
    await SharedPrefsStorage.setString(_urlKey, trimmed);
    if (_enabled) {
      await setEnabled(true);
    }
  }

  Future<int> updateNow() async {
    await load();

    // Wait for an in-progress update to finish rather than returning stale data.
    if (_updateCompleter != null) {
      return _updateCompleter!.future;
    }
    if (!getIt.isRegistered<Engine>()) return _rulesCount;

    _updateCompleter = Completer<int>();
    _updating = true;

    try {
      final engine = getIt<Engine>();
      // Apply URL to session first
      final session = await engine.fetchSession();
      await session.update(SessionBase(
        blocklistEnabled: true,
        blocklistUrl: _url,
      ));

      final count = await engine.updateBlocklist();
      _rulesCount = count;
      _lastUpdated = DateTime.now();

      await SharedPrefsStorage.setString(_rulesCountKey, count.toString());
      await SharedPrefsStorage.setString(
          _lastUpdatedKey, _lastUpdated!.toIso8601String());

      if (kDebugMode) {
        debugPrint('BlocklistService: updated $count blocklist rules');
      }
      _updateCompleter!.complete(count);
      return count;
    } catch (e) {
      if (kDebugMode) debugPrint('BlocklistService updateNow error: $e');
      _updateCompleter!.completeError(e);
      rethrow;
    } finally {
      _updating = false;
      _updateCompleter = null;
    }
  }
}
