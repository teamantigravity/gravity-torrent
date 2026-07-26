import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Persists the last few directories a user has chosen when adding a torrent.
///
/// Data is stored in shared_preferences and is never sent off-device.
/// Useful for quickly re-selecting common download locations.
class RecentDownloadDirectoriesService {
  RecentDownloadDirectoriesService._();
  static final RecentDownloadDirectoriesService instance =
      RecentDownloadDirectoriesService._();

  static const _storageKey = 'gravity_torrent_recent_dirs_v1';
  static const _maxEntries = 5;

  final List<String> _directories = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await SharedPrefsStorage.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _directories.clear();
          for (final value in decoded) {
            if (value is String && value.isNotEmpty) {
              _directories.add(value);
            }
          }
        }
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('RecentDownloadDirectoriesService load failed: $e\n$s');
        }
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    await SharedPrefsStorage.setString(
      _storageKey,
      jsonEncode(_directories.toList()),
    );
  }

  /// The cached list of recent directories (most recently used first).
  List<String> get directories => List.unmodifiable(_directories);

  /// Bumps [path] to the front of the recents list, or adds it.
  Future<void> add(String path) async {
    await load();
    _directories.remove(path);
    _directories.insert(0, path);
    while (_directories.length > _maxEntries) {
      _directories.removeLast();
    }
    await _save();
  }

  /// Removes a directory from recents.
  Future<void> remove(String path) async {
    await load();
    _directories.remove(path);
    await _save();
  }

  /// Clears all remembered directories.
  Future<void> clear() async {
    _directories.clear();
    await _save();
  }

  /// For tests.
  void reset() {
    _directories.clear();
    _loaded = false;
  }
}
