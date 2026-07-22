import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Daily data-usage snapshot.
class DataUsageSnapshot {
  final DateTime day;
  final int downloadedBytes;
  final int uploadedBytes;

  DataUsageSnapshot({
    required this.day,
    required this.downloadedBytes,
    required this.uploadedBytes,
  });

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'downloadedBytes': downloadedBytes,
        'uploadedBytes': uploadedBytes,
      };

  factory DataUsageSnapshot.fromJson(Map<String, dynamic> json) {
    final dayRaw = json['day'];
    if (dayRaw is! String) {
      throw FormatException('Missing or invalid day');
    }
    final day = DateTime.tryParse(dayRaw);
    if (day == null) {
      throw FormatException('Invalid day: $dayRaw');
    }
    return DataUsageSnapshot(
      day: day,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      uploadedBytes: (json['uploadedBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// On-device data-usage analytics.
///
/// Keeps a rolling window of daily upload/download totals in local storage.
/// New samples are upscaled from [Engine] session/torrent totals and merged
/// with the existing history so the dashboard always reflects recent activity.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _storageKey = 'gravity_torrent_analytics_history';
  static const _maxDays = 90;

  List<DataUsageSnapshot> _history = [];
  bool _loaded = false;
  Map<int, int> _lastDownloadedByTorrent = {};
  Map<int, int> _lastUploadedByTorrent = {};

  @visibleForTesting
  void reset() {
    _loaded = false;
    _history = [];
    _lastDownloadedByTorrent = {};
    _lastUploadedByTorrent = {};
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await SharedPrefsStorage.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          _history = decoded
              .whereType<Map>()
              .map((e) {
                try {
                  return DataUsageSnapshot.fromJson(
                    Map<String, dynamic>.from(e),
                  );
                } catch (e, s) {
                  if (kDebugMode) {
                    debugPrint('Skipping invalid analytics snapshot: $e\n$s');
                  }
                  return null;
                }
              })
              .whereType<DataUsageSnapshot>()
              .toList();
        }
      }
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('Failed to load analytics history: $e\n$s');
      }
      _history = [];
    }
    _history.sort((a, b) => a.day.compareTo(b.day));
    _loaded = true;
  }

  Future<void> save() async {
    final raw = jsonEncode(_history.map((e) => e.toJson()).toList());
    await SharedPrefsStorage.setString(_storageKey, raw);
  }

  /// Record the latest cumulative totals. The delta since the last sample is
  /// added to today's bucket.
  Future<void> recordTorrentStats(List<dynamic> torrents) async {
    await load();
    final today = DateTime.now();
    final key = DateTime(today.year, today.month, today.day);

    int deltaDown = 0;
    int deltaUp = 0;

    for (final t in torrents) {
      final id = t.id as int;
      final down = t.downloadedEver as int;
      final up = t.uploadedEver as int;

      final lastD = _lastDownloadedByTorrent[id];
      final lastU = _lastUploadedByTorrent[id];

      if (lastD == null) {
        // First time seeing this torrent this session, don't count existing
      } else if (down >= lastD) {
        deltaDown += down - lastD;
      } else {
        deltaDown += down;
      }

      if (lastU == null) {
        // First time seeing this torrent
      } else if (up >= lastU) {
        deltaUp += up - lastU;
      } else {
        deltaUp += up;
      }

      _lastDownloadedByTorrent[id] = down;
      _lastUploadedByTorrent[id] = up;
    }

    final currentIds = torrents.map((t) => t.id as int).toSet();
    _lastDownloadedByTorrent.removeWhere((id, _) => !currentIds.contains(id));
    _lastUploadedByTorrent.removeWhere((id, _) => !currentIds.contains(id));

    // Keep only the last [_maxDays] days
    final excess = _history.length - _maxDays;
    bool trimmed = false;
    if (excess > 0) {
      _history.removeRange(0, excess);
      trimmed = true;
    }

    // Skip writing if both deltas are zero to avoid spurious entries.
    if (deltaDown == 0 && deltaUp == 0) {
      if (trimmed) await save();
      return;
    }

    final existing = _history.where((s) => s.day == key).toList();
    if (existing.isNotEmpty) {
      final last = existing.last;
      final index = _history.indexOf(last);
      _history[index] = DataUsageSnapshot(
        day: key,
        downloadedBytes: last.downloadedBytes + deltaDown,
        uploadedBytes: last.uploadedBytes + deltaUp,
      );
    } else {
      _history.add(
        DataUsageSnapshot(
          day: key,
          downloadedBytes: deltaDown,
          uploadedBytes: deltaUp,
        ),
      );
    }

    await save();
  }

  List<DataUsageSnapshot> get history => List.unmodifiable(_history);

  List<DataUsageSnapshot> getLastDays(int count) {
    if (_history.length <= count) return List.unmodifiable(_history);
    return List.unmodifiable(_history.sublist(_history.length - count));
  }

  DataUsageSnapshot? get today {
    if (_history.isEmpty) return null;
    // History is kept sorted by day and trimmed to [_maxDays], so today's
    // bucket — if it exists — is always the last element. Days are normalized
    // to midnight, so a direct DateTime comparison is safe.
    final last = _history.last;
    final now = DateTime.now();
    final key = DateTime(now.year, now.month, now.day);
    return last.day == key ? last : null;
  }
}
