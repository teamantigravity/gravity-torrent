import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Stores per-torrent seed ratio goals and auto-stops torrents that have
/// exceeded their goal. Called after every torrent list refresh.
///
/// Goals are stored locally as JSON — no data leaves the device.
class SeedRatioService {
  SeedRatioService._();
  static final SeedRatioService instance = SeedRatioService._();

  static const _storageKey = 'gravity_torrent_seed_ratio_goals';

  /// Map from torrent ID (as String) to target ratio.
  final Map<String, double> _goals = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await SharedPrefsStorage.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _goals.clear();
        decoded.forEach((k, v) {
          if (v is num) _goals[k] = v.toDouble();
        });
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('SeedRatioService: failed to load goals: $e\n$s');
        }
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    await SharedPrefsStorage.setString(
      _storageKey,
      jsonEncode(_goals),
    );
  }

  /// Sets a personal seed ratio goal for [torrentId].
  Future<void> setGoal(int torrentId, double ratio) async {
    await load();
    _goals[torrentId.toString()] = ratio;
    await _save();
  }

  /// Removes the personal goal for [torrentId].
  Future<void> removeGoal(int torrentId) async {
    await load();
    _goals.remove(torrentId.toString());
    await _save();
  }

  /// Returns the goal for [torrentId], or null if none is set.
  double? getGoal(int torrentId) => _goals[torrentId.toString()];

  /// Returns true if a goal is set for [torrentId].
  bool hasGoal(int torrentId) => _goals.containsKey(torrentId.toString());

  /// Checks all [torrents] against their goals and pauses those that have
  /// exceeded their ratio. Called by [TorrentsModel] after each fetch.
  Future<void> checkAndStop(List<Torrent> torrents) async {
    if (_goals.isEmpty) return;
    try {
      final engine = getIt<Engine>();
      for (final torrent in torrents) {
        final goal = _goals[torrent.id.toString()];
        if (goal == null) continue;
        if (torrent.status != TorrentStatus.seeding) continue;
        final downloaded = torrent.downloadedEver;
        if (downloaded <= 0) continue;
        final ratio = torrent.uploadedEver / downloaded;
        if (ratio >= goal) {
          try {
            await engine.pauseTorrent(torrent.id);
            if (kDebugMode) {
              debugPrint(
                'SeedRatioService: paused torrent ${torrent.id} '
                '(ratio $ratio >= goal $goal)',
              );
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'SeedRatioService: failed to pause ${torrent.id}: $e',
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SeedRatioService checkAndStop error: $e');
    }
  }
}
