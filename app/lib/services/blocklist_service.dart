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

  bool get isEnabled => _enabled;
  bool get isUpdating => _updating;
  String get url => _url;
  DateTime? get lastUpdated => _lastUpdated;
  int get rulesCount => _rulesCount;

  Future<void> load() async {
    if (_loaded) return;
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    _url = await SharedPrefsStorage.getString(_urlKey) ?? defaultUrl;
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
    _url = url;
    await SharedPrefsStorage.setString(_urlKey, url);
    if (_enabled) {
      await setEnabled(true);
    }
  }

  Future<int> updateNow() async {
    await load();
    if (_updating) return _rulesCount;
    if (!getIt.isRegistered<Engine>()) return _rulesCount;
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
      return count;
    } catch (e) {
      if (kDebugMode) debugPrint('BlocklistService updateNow error: $e');
      rethrow;
    } finally {
      _updating = false;
    }
  }
}
