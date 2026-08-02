import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Persists the last few search queries used to filter the torrent list.
///
/// Data is stored in shared_preferences and is never sent off-device.
class RecentSearchQueriesService {
  RecentSearchQueriesService._();
  static final RecentSearchQueriesService instance =
      RecentSearchQueriesService._();

  static const _storageKey = 'gravity_torrent_recent_searches_v1';
  static const _maxEntries = 8;

  final List<String> _queries = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await SharedPrefsStorage.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _queries.clear();
          for (final value in decoded) {
            if (value is String && value.isNotEmpty) {
              _queries.add(value);
            }
          }
        }
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('RecentSearchQueriesService load failed: $e\n$s');
        }
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    await SharedPrefsStorage.setString(
      _storageKey,
      jsonEncode(_queries.toList()),
    );
  }

  /// The cached list of recent queries (most recently used first).
  List<String> get queries => List.unmodifiable(_queries);

  /// Bumps [query] to the front of the recents list, or adds it.
  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await load();
    _queries.remove(trimmed);
    _queries.insert(0, trimmed);
    while (_queries.length > _maxEntries) {
      _queries.removeLast();
    }
    await _save();
  }

  /// Removes a query from recents.
  Future<void> remove(String query) async {
    await load();
    _queries.remove(query);
    await _save();
  }

  /// Clears all remembered queries.
  Future<void> clear() async {
    _queries.clear();
    await _save();
  }

  /// For tests.
  void reset() {
    _queries.clear();
    _loaded = false;
  }
}
