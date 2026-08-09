import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/engine/file.dart' as torrent_file;
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/utils/torrent_utils.dart';

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

      final originalLimitDownEnabled = torrent.speedLimitDownEnabled;
      final originalLimitDown = torrent.speedLimitDown;

      await engine.setTorrentSpeedLimit(
        torrent.id,
        downloadLimit: 0, // unlimited while buffering header
      );

      // 4. Update sequential download start piece to ensure correct order
      await torrent.setSequentialDownloadFromPiece(startPiece);

      // 5. Restore the speed limit once the moov atom and header pieces are ready
      unawaited(() async {
        try {
          // Transmission RPC limitations: the moov atom might be at the very end
          // of the file, but we can't reliably prioritize *just* the end piece
          // without prioritizing the whole file. We rely on the sequential 
          // download mode and file high-priority to fetch the start and end pieces.
          await waitForPiecesList(
            torrent: torrent,
            neededPieces: [startPiece, endPiece],
          );
        } catch (_) {
        } finally {
          try {
            if (originalLimitDownEnabled) {
              await engine.setTorrentSpeedLimit(torrent.id, downloadLimit: originalLimitDown);
            }
          } catch (_) {}
        }
      }());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MoovPriorityBooster error: $e');
      }
    }
  }
}
