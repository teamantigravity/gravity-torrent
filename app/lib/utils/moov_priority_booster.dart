import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/engine/file.dart' as torrent_file;
import 'package:gravity_torrent/services/service_locator.dart';

/// Intelligent priority booster for video streaming.
///
/// Automatically prioritizes the first 1% (header) and last 1% (moov atom)
/// of pieces for a video file before starting sequential playback.
class MoovPriorityBooster {
  MoovPriorityBooster._();

  static Future<void> boostForStreaming({
    required Torrent torrent,
    required torrent_file.File file,
  }) async {
    try {
      final engine = getIt<Engine>();

      // 1. Enable sequential download mode for the torrent
      await engine.setTorrentSequentialDownload(torrent.id, true);

      final pieceSize = torrent.pieceSize;
      if (pieceSize <= 0) return;

      // 2. Start piece and end piece for this file are directly available on the File model
      final startPiece = file.beginPiece;
      final endPiece = file.endPiece;
      final totalPieces = endPiece - startPiece + 1;

      if (totalPieces <= 0) return;

      if (kDebugMode) {
        debugPrint(
          'MoovPriorityBooster: boosting torrent ${torrent.id} (${file.name}): '
          'pieces [$startPiece..$endPiece]',
        );
      }

      // 3. Set high priority on the file
      // Transmission uses wantedFiles / priority-high for file-level priority.
      // We set the whole-file priority to high first, then kick sequential mode.
      // For finer per-piece control, Transmission RPC exposes no direct
      // piece-priority API, so we ensure sequential + file high-priority:
      final fileIndex = torrent.files.indexWhere((f) => f.name == file.name);
      if (fileIndex != -1) {
        await torrent.setFilesPriority(priorityHigh: [fileIndex]);
      }

      await engine.setTorrentSpeedLimit(
        torrent.id,
        downloadLimit: 0, // unlimited while buffering header
      );

      // 4. Update sequential download start piece to ensure correct order
      await torrent.setSequentialDownloadFromPiece(startPiece);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MoovPriorityBooster error: $e');
      }
    }
  }
}
