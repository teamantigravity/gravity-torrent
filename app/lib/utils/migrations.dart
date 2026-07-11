import 'package:flutter/foundation.dart';

import 'package:gravity_torrent/main.dart';

/// Run all migrations for app updates.
/// This should be called on app startup after engine initialization.
Future<void> runMigrations() async {
  await resetAllFilePriorities();
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
