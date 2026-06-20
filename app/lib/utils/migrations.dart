import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gravity_torrent/engine/transmission/transmission.dart';
import 'package:gravity_torrent/main.dart';

/// Run all migrations for app updates.
/// This should be called on app startup after engine initialization.
Future<void> runMigrations() async {
  await migrateLegacyPikatorrentConfig();
  await cleanupLegacyStreamingStateFile();
  await resetAllFilePriorities();
}

/// Copy Transmission config from legacy PikaTorrent install locations if needed.
Future<void> migrateLegacyPikatorrentConfig() async {
  try {
    final targetDir = await getConfigDir();
    if (await targetDir.exists()) {
      final existing = await targetDir.list(followLinks: false).toList();
      if (existing.isNotEmpty) return;
    }

    Directory? legacyDir;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        legacyDir = Directory(path.join(appData, 'pikatorrent', 'transmission'));
        if (!await legacyDir.exists()) {
          legacyDir = Directory(
              path.join(appData, 'com.pikatorrent.PikaTorrent', 'transmission'));
        }
      }
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        legacyDir = Directory(path.join(home, '.local', 'share', 'pikatorrent', 'transmission'));
        if (!await legacyDir.exists()) {
          legacyDir = Directory(path.join(home, '.config', 'pikatorrent', 'transmission'));
        }
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        legacyDir = Directory(path.join(
            home, 'Library', 'Application Support', 'pikatorrent', 'transmission'));
      }
    }

    if (legacyDir == null || !await legacyDir.exists()) return;
    debugPrint('Migrating legacy torrent config from ${legacyDir.path}');
    await targetDir.create(recursive: true);
    await for (final entity in legacyDir.list(recursive: true)) {
      final relative = path.relative(entity.path, from: legacyDir.path);
      final destPath = path.join(targetDir.path, relative);
      if (entity is Directory) {
        await Directory(destPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(path.dirname(destPath)).create(recursive: true);
        await entity.copy(destPath);
      }
    }
  } catch (e) {
    debugPrint('Legacy config migration skipped: $e');
  }
}

/// Clean up legacy session state file from old streaming implementation.
/// This can be removed in future versions after users have migrated.
/// TODO: Remove this cleanup after a few releases (added in v1.x.x)
Future<void> cleanupLegacyStreamingStateFile() async {
  try {
    final filePath = path.join((await getApplicationSupportDirectory()).path,
        'torrents_resume_status.json');
    final file = File(filePath);
    if (await file.exists()) {
      debugPrint('Removing legacy streaming state file: $filePath');
      await file.delete();
    }
  } catch (e) {
    debugPrint('Error cleaning up legacy streaming state file: $e');
  }
}

/// Reset all file priorities to normal on startup.
/// This ensures that if the app crashed during streaming, file priorities
/// are restored to normal state.
Future<void> resetAllFilePriorities() async {
  try {
    final torrents = await engine.fetchTorrents();
    debugPrint('Resetting file priorities for ${torrents.length} torrents');

    for (final torrent in torrents) {
      if (torrent.files.isNotEmpty) {
        final allFileIndices =
            List.generate(torrent.files.length, (index) => index);
        await torrent.setFilesPriority(priorityNormal: allFileIndices);
      }
    }

    debugPrint('File priorities reset completed');
  } catch (e) {
    debugPrint('Error resetting file priorities: $e');
  }
}
