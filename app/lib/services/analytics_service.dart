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

  factory DataUsageSnapshot.fromJson(Map<String, dynamic> json) =>
      DataUsageSnapshot(
        day: DateTime.parse(json['day'] as String),
        downloadedBytes: (json['downloadedBytes'] as num).toInt(),
        uploadedBytes: (json['uploadedBytes'] as num).toInt(),
      );
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

  @visibleForTesting
  void reset() {
    _loaded = false;
    _history = [];
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await SharedPrefsStorage.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _history = list
            .map((e) => DataUsageSnapshot.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _history = [];
    }
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

    final previous = _history.isNotEmpty ? _history.last : null;
    final deltaDown = previous == null
        ? downloadedBytes
        : downloadedBytes >= previous.downloadedBytes
            ? downloadedBytes - previous.downloadedBytes
            : downloadedBytes; // counter reset — treat as fresh
    final deltaUp = previous == null
        ? uploadedBytes
        : uploadedBytes >= previous.uploadedBytes
            ? uploadedBytes - previous.uploadedBytes
            : uploadedBytes; // counter reset

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
