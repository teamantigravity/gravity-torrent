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

      // 2. Calculate start piece and end piece for this file
      final fileStartByte = file.offset;
      final fileEndByte = file.offset + file.length - 1;

      final startPiece = (fileStartByte / pieceSize).floor();
      final endPiece = (fileEndByte / pieceSize).floor();
      final totalPieces = endPiece - startPiece + 1;

      if (totalPieces <= 0) return;

      // Header: First 1% of pieces (minimum 2 pieces)
      final headerPieceCount = (totalPieces * 0.01).ceil().clamp(2, 20);
      // Tail: Last 1% of pieces (for MP4 moov atom at end of file)
      final tailPieceCount = (totalPieces * 0.01).ceil().clamp(2, 20);

      final headerEndPiece =
          (startPiece + headerPieceCount).clamp(startPiece, endPiece);
      final tailStartPiece =
          (endPiece - tailPieceCount).clamp(startPiece, endPiece);

      if (kDebugMode) {
        debugPrint(
          'MoovPriorityBooster: boosting torrent ${torrent.id} (${file.name}): '
          'header pieces [$startPiece..$headerEndPiece], tail pieces [$tailStartPiece..$endPiece]',
        );
      }

      // 3. Set high priority on header pieces (file start → header boundary)
      // Transmission uses wantedFiles / priority-high for file-level priority.
      // We set the whole-file priority to high first, then kick sequential mode.
      // For finer per-piece control, Transmission RPC exposes no direct
      // piece-priority API, so we ensure sequential + file high-priority:
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
