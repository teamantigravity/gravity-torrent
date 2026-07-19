import 'dart:async';

import 'package:async/async.dart';
import 'package:gravity_torrent/engine/file.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/main.dart';

class CancellationException implements Exception {}

/// Waits for a specified list of pieces to be downloaded.
///
/// [torrent] - The torrent containing the pieces
/// [neededPieces] - List of piece indices to wait for
/// [onCancelled] - Optional callback to check if operation should be cancelled
Future<void> waitForPiecesList({
  required Torrent torrent,
  required List<int> neededPieces,
  bool Function()? onCancelled,
}) async {
  final waitForPiecesCompleter = Completer<void>();

  Future<void> testPiecesComplete(Timer? timer) async {
    try {
      if (onCancelled != null && onCancelled()) {
        timer?.cancel();
        if (!waitForPiecesCompleter.isCompleted) {
          waitForPiecesCompleter.completeError(CancellationException());
        }
        return;
      }

      // Refresh torrent data
      final Torrent t = await engine.fetchTorrent(torrent.id);

      // Re-check cancellation after the async fetch completes.
      if (onCancelled != null && onCancelled()) {
        timer?.cancel();
        if (!waitForPiecesCompleter.isCompleted) {
          waitForPiecesCompleter.completeError(CancellationException());
        }
        return;
      }

      final hasLoaded = t.hasLoadedPieces(neededPieces);

      if (hasLoaded) {
        if (timer != null) {
          timer.cancel();
        }

        if (!waitForPiecesCompleter.isCompleted) {
          waitForPiecesCompleter.complete();
        }
      }
    } catch (e) {
      timer?.cancel();
      if (!waitForPiecesCompleter.isCompleted) {
        waitForPiecesCompleter.completeError(e);
      }
    }
  }

  await testPiecesComplete(null);

  if (!waitForPiecesCompleter.isCompleted) {
    Timer.periodic(const Duration(seconds: 1), testPiecesComplete);
  }

  return waitForPiecesCompleter.future;
}

/// Waits for a specified number of pieces to be downloaded for a given file.
///
/// [torrent] - The torrent containing the file
/// [file] - The file to wait for
/// [pieceCount] - Number of pieces to wait for (starting from file.beginPiece)
/// [cancelableCompleter] - Optional completer to support cancellation
Future<void> waitForPieces({
  required Torrent torrent,
  required File file,
  required int pieceCount,
  CancelableCompleter? cancelableCompleter,
}) async {
  if (pieceCount < 0) pieceCount = 0;
  List<int> neededPieces = [];
  final endPiece = (file.beginPiece + pieceCount).clamp(0, file.endPiece);
  for (int i = file.beginPiece; i < endPiece; i++) {
    neededPieces.add(i);
  }

  await waitForPiecesList(
    torrent: torrent,
    neededPieces: neededPieces,
    onCancelled: cancelableCompleter != null
        ? () => cancelableCompleter.isCanceled
        : null,
  );
}
