import 'package:flutter/foundation.dart';

import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

const _streamingActiveKey = 'streaming_active';

/// Run all migrations for app updates.
/// This should be called on app startup after engine initialization.
Future<void> runMigrations() async {
  final wasStreaming =
      await SharedPrefsStorage.getBool(_streamingActiveKey) ?? false;
  if (wasStreaming) {
    await resetAllFilePriorities();
    await SharedPrefsStorage.setBool(_streamingActiveKey, false);
  }
}

/// Reset all file priorities to normal on startup.
/// This is only run after an unclean shutdown while a streaming session was
/// active, so user-chosen priorities are not reset on a normal launch.
Future<void> resetAllFilePriorities() async {
  if (!getIt.isRegistered<Engine>()) return;
  final engine = getIt<Engine>();
  try {
    final torrents = await engine.fetchTorrents();
    debugPrint('Resetting file priorities for ${torrents.length} torrents');

    for (final torrent in torrents) {
      if (torrent.files.isNotEmpty) {
        final allFileIndices = List.generate(
          torrent.files.length,
          (index) => index,
        );
        await torrent.setFilesPriority(priorityNormal: allFileIndices);
      }
    }

    debugPrint('File priorities reset completed');
  } catch (e) {
    debugPrint('Error resetting file priorities: $e');
  }
}
