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
  int _lastRawDownloaded = -1;
  int _lastRawUploaded = -1;

  @visibleForTesting
  void reset() {
    _loaded = false;
    _history = [];
    _lastRawDownloaded = -1;
    _lastRawUploaded = -1;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await SharedPrefsStorage.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          _history = decoded
              .whereType<Map<String, dynamic>>()
              .map((e) {
                try {
                  return DataUsageSnapshot.fromJson(e);
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
  Future<void> recordTotals({
    required int downloadedBytes,
    required int uploadedBytes,
  }) async {
    await load();
    final today = DateTime.now();
    final key = DateTime(today.year, today.month, today.day);

    // Compute deltas using the last raw cumulative values, not the history bucket.
    final deltaDown = _lastRawDownloaded < 0
        ? 0  // First ever call — don't count existing downloads as "new"
        : downloadedBytes >= _lastRawDownloaded
            ? downloadedBytes - _lastRawDownloaded
            : downloadedBytes; // counter reset after engine restart
    final deltaUp = _lastRawUploaded < 0
        ? 0
        : uploadedBytes >= _lastRawUploaded
            ? uploadedBytes - _lastRawUploaded
            : uploadedBytes;

    _lastRawDownloaded = downloadedBytes;
    _lastRawUploaded = uploadedBytes;

    // Skip writing if both deltas are zero to avoid spurious entries.
    if (deltaDown == 0 && deltaUp == 0) return;

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

    // Keep only the last [_maxDays] days
    final excess = _history.length - _maxDays;
    if (excess > 0) {
      _history.removeRange(0, excess);
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
