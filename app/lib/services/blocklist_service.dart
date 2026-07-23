import 'dart:async';
import 'dart:io';

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
    return _isPublicHost(uri.host);
  }

  /// Returns true when [host] is a public, resolvable name or a public IP
  /// address. Blocks localhost, private IPv4 ranges, and IPv6 unique-local /
  /// link-local addresses.
  static bool _isPublicHost(String host) {
    final address = InternetAddress.tryParse(host);
    if (address != null) {
      return _isPublicAddress(address);
    }

    final lower = host.toLowerCase();
    if (lower == 'localhost' || !host.contains('.')) return false;

    // Reject hostnames that are just an IPv4 literal with a port or other noise
    // already handled by the IP path above.
    return true;
  }

  /// Returns true for public (non-loopback, non-private) IP addresses.
  static bool _isPublicAddress(InternetAddress address) {
    if (address.isLoopback) return false;

    if (address.type == InternetAddressType.IPv4) {
      final parts = address.address.split('.');
      if (parts.length != 4) return false;
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      if (first == null || second == null) return false;

      if (first == 10) return false; // 10/8
      if (first == 172 && second >= 16 && second <= 31) return false; // 172.16/12
      if (first == 192 && second == 168) return false; // 192.168/16
      if (first == 169 && second == 254) return false; // link-local 169.254/16

      return true;
    }

    if (address.type == InternetAddressType.IPv6) {
      final bytes = address.rawAddress;
      if (bytes.isEmpty) return false;
      // fe80::/10
      if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) return false;
      // fc00::/7
      if ((bytes[0] & 0xfe) == 0xfc) return false;
      return true;
    }

    return false;
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
