import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// A weekly schedule window during which downloads are allowed.
class ScheduleWindow {
  final ScheduleTime start;
  final ScheduleTime end;

  /// Bitmask: bit 0 = Mon, bit 1 = Tue, … bit 6 = Sun.
  final int dayBitmask;

  const ScheduleWindow({
    required this.start,
    required this.end,
    this.dayBitmask = 127, // all days
  });

  bool get allDays => dayBitmask == 127;

  Map<String, dynamic> toJson() => {
        'startHour': start.hour,
        'startMinute': start.minute,
        'endHour': end.hour,
        'endMinute': end.minute,
        'dayBitmask': dayBitmask,
      };

  factory ScheduleWindow.fromJson(Map<String, dynamic> json) => ScheduleWindow(
        start: ScheduleTime(
          hour: (json['startHour'] as num?)?.toInt() ?? 0,
          minute: (json['startMinute'] as num?)?.toInt() ?? 0,
        ),
        end: ScheduleTime(
          hour: (json['endHour'] as num?)?.toInt() ?? 0,
          minute: (json['endMinute'] as num?)?.toInt() ?? 0,
        ),
        dayBitmask: (json['dayBitmask'] as num?)?.toInt() ?? 127,
      );

  /// Returns true if [now] falls within this window.
  bool isActiveAt(DateTime now) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // No wrap, so just check today's bit
      final dayBit = 1 << ((now.weekday - 1) % 7);
      if ((dayBitmask & dayBit) == 0) return false;
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Window wraps midnight
      if (nowMinutes >= startMinutes) {
        // Before midnight, corresponds to today's schedule
        final dayBit = 1 << ((now.weekday - 1) % 7);
        return (dayBitmask & dayBit) != 0;
      } else if (nowMinutes < endMinutes) {
        // After midnight, corresponds to yesterday's schedule
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayBit = 1 << ((yesterday.weekday - 1) % 7);
        return (dayBitmask & yesterdayBit) != 0;
      }
      return false;
    }
  }
}

/// Service that enforces download time windows.
///
/// When enabled, it checks every minute whether downloads should be running,
/// pausing or resuming torrents accordingly. The schedule is persisted locally
/// — no data leaves the device.
class SchedulerService {
  SchedulerService._();
  static final SchedulerService instance = SchedulerService._();

  static const _storageKey = 'gravity_torrent_scheduler';
  static const _enabledKey = 'gravity_torrent_scheduler_enabled';

  ScheduleWindow _window = const ScheduleWindow(
    start: ScheduleTime(hour: 23, minute: 0),
    end: ScheduleTime(hour: 7, minute: 0),
  );

  bool _enabled = false;
  bool _loaded = false;
  Timer? _timer;
  final Set<int> _pausedByScheduler = {};

  bool get enabled => _enabled;
  ScheduleWindow get window => _window;

  Future<void> load() async {
    if (_loaded) return;
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    final raw = await SharedPrefsStorage.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _window = ScheduleWindow.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Failed to load scheduler window: $e\n$s');
        }
      }
    }
    _loaded = true;
    if (_enabled) _startTimer();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await SharedPrefsStorage.setBool(_enabledKey, value);
    if (value) {
      _startTimer();
    } else {
      _stopTimer();
      await _resumeAll();
    }
  }

  Future<void> setWindow(ScheduleWindow window) async {
    _window = window;
    await SharedPrefsStorage.setString(
      _storageKey,
      jsonEncode(window.toJson()),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _enforce());
    _enforce(); // run immediately
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _enforce() async {
    if (!_enabled) return;
    if (!RemoteConfigService.instance.isFeatureEnabled('enableScheduler')) {
      return;
    }
    if (!getIt.isRegistered<Engine>()) return;
    final now = DateTime.now();
    final shouldDownload = _window.isActiveAt(now);

    try {
      final engine = getIt<Engine>();
      final torrents = await engine.fetchTorrents();

      if (shouldDownload) {
        // Resume torrents paused by the scheduler
        for (final id in List<int>.from(_pausedByScheduler)) {
          final t = torrents.firstWhereOrNull((t) => t.id == id);
          if (t == null) {
            // Torrent no longer exists; drop it from the set.
            _pausedByScheduler.remove(id);
            continue;
          }
          if (t.status == TorrentStatus.stopped) {
            try {
              await engine.resumeTorrent(id);
              _pausedByScheduler.remove(id);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('SchedulerService failed to resume torrent $id: $e');
              }
            }
          } else {
            // Already active; remove from scheduler-managed set.
            _pausedByScheduler.remove(id);
          }
        }
      } else {
        // Pause active torrents and remember them
        for (final torrent in torrents) {
          if (torrent.status == TorrentStatus.downloading ||
              torrent.status == TorrentStatus.seeding ||
              torrent.status == TorrentStatus.queuedToDownload ||
              torrent.status == TorrentStatus.queuedToSeed) {
            await engine.pauseTorrent(torrent.id);
            _pausedByScheduler.add(torrent.id);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SchedulerService _enforce error: $e');
    }
  }

  Future<void> _resumeAll() async {
    if (_pausedByScheduler.isEmpty) return;
    if (!getIt.isRegistered<Engine>()) {
      _pausedByScheduler.clear();
      return;
    }
    try {
      final engine = getIt<Engine>();
      final torrents = await engine.fetchTorrents();
      final existingIds = {for (final t in torrents) t.id};
      for (final id in List<int>.from(_pausedByScheduler)) {
        if (!existingIds.contains(id)) {
          _pausedByScheduler.remove(id);
          continue;
        }
        try {
          await engine.resumeTorrent(id);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('SchedulerService failed to resume torrent $id: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SchedulerService _resumeAll error: $e');
    }
  }

  void dispose() {
    _stopTimer();
  }
}

/// Simple hour/minute value for use in non-widget service code.
/// Do not confuse with Flutter's [material.TimeOfDay].
class ScheduleTime {
  final int hour;
  final int minute;

  const ScheduleTime({required this.hour, required this.minute});

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
