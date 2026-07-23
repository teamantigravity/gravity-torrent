import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Keys that are included in the settings backup.
const List<String> _backupKeys = [
  'theme',
  'locale',
  'checkForUpdate',
  'useDynamicColor',
  'useEnhancedNotifications',
  'usePipBackgroundAudio',
  'enableRemoteControl',
  'enableAnalytics',
  'enableAppLock',
  'enableShortcuts',
  'enableHaptic',
  'enableScheduler',
  'enableQuota',
  'enableRssAutoDownload',
  'enableWifiOnly',
  'enableBatterySaver',
  'gravity_torrent_scheduler',
  'gravity_torrent_scheduler_enabled',
  'gravity_torrent_quota',
  'gravity_torrent_quota_enabled',
  'gravity_torrent_seed_ratio_goals',
  'gravity_torrent_wifi_guard_enabled',
  'gravity_torrent_wifi_guard_mode',
  'gravity_torrent_battery_saver_enabled',
  'gravity_torrent_battery_saver_threshold',
  'gravity_torrent_rss_feeds',
  'stopSeedingWhenComplete',
];

/// Backup version — increment when the schema changes in a breaking way.
const int _backupVersion = 1;

/// Migrates a backup from an older [_backupVersion] to the current schema.
/// Currently a no-op because version 1 is the only known schema, but new
/// migrations should be added here when the schema changes.
Map<String, dynamic> _migrateBackup(
    int version, Map<String, dynamic> settings) {
  if (version < _backupVersion) {
    if (kDebugMode) {
      debugPrint(
          'BackupService: migrating backup from version $version to $_backupVersion');
    }
    // Add future schema migrations here.
  }
  return settings;
}

/// Exports and imports Gravity Torrent settings as a JSON file.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Reads all backup keys from SharedPrefs and writes them to a temp JSON
  /// file, then shares it via the system share sheet.
  Future<void> export() async {
    try {
      final Map<String, dynamic> data = {
        'version': _backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {},
      };

      for (final key in _backupKeys) {
        // Try bool first, then String.
        final boolVal = await SharedPrefsStorage.getBool(key);
        if (boolVal != null) {
          (data['settings'] as Map)[key] = boolVal;
          continue;
        }
        final strVal = await SharedPrefsStorage.getString(key);
        if (strVal != null) {
          (data['settings'] as Map)[key] = strVal;
        }
      }

      final json = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName =
          'gravity_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Gravity Torrent settings backup',
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('BackupService export error: $e');
      rethrow;
    }
  }

  /// Reads a JSON backup file from [filePath] and restores all settings to
  /// SharedPrefs. Returns a list of restored keys.
  Future<List<String>> import(String filePath) async {
    final raw = await File(filePath).readAsString();
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid backup file: $e');
    }

    final version = (data['version'] as num?)?.toInt();
    if (version == null || version > _backupVersion) {
      throw FormatException(
        'Unsupported backup version: $version. '
        'Please update Gravity Torrent.',
      );
    }

    final settingsRaw = data['settings'];
    final settings = settingsRaw is Map
        ? _migrateBackup(
            version,
            Map<String, dynamic>.from(settingsRaw),
          )
        : <String, dynamic>{};
    final restored = <String>[];

    for (final entry in settings.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is bool) {
        await SharedPrefsStorage.setBool(key, value);
        restored.add(key);
      } else if (value is String) {
        await SharedPrefsStorage.setString(key, value);
        restored.add(key);
      }
    }

    if (kDebugMode) {
      debugPrint('BackupService: restored ${restored.length} keys');
    }
    return restored;
  }
}
