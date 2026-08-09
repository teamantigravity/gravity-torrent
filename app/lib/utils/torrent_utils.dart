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
class _TorrentPieceWaiter {
  final int torrentId;
  final List<int> neededPieces;
  final Completer<void> completer;
  final bool Function()? onCancelled;

  _TorrentPieceWaiter(
    this.torrentId,
    this.neededPieces,
    this.completer,
    this.onCancelled,
  );
}

final List<_TorrentPieceWaiter> _waiters = [];
Timer? _sharedTimer;
bool _isFetchingShared = false;

void _startSharedTimer() {
  if (_sharedTimer != null) return;
  _sharedTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (_waiters.isEmpty) {
      timer.cancel();
      _sharedTimer = null;
      return;
    }
    if (_isFetchingShared) return;
    _isFetchingShared = true;
    try {
      final ids = _waiters.map((w) => w.torrentId).toSet();
      for (final id in ids) {
        try {
          final t = await engine.fetchTorrent(id);
          final waitersForId =
              _waiters.where((w) => w.torrentId == id).toList();
          for (final w in waitersForId) {
            if (w.onCancelled != null && w.onCancelled!()) {
              if (!w.completer.isCompleted) {
                w.completer.completeError(CancellationException());
              }
              _waiters.remove(w);
            } else if (t.hasLoadedPieces(w.neededPieces)) {
              if (!w.completer.isCompleted) w.completer.complete();
              _waiters.remove(w);
            }
          }
        } catch (e) {
          final waitersForId =
              _waiters.where((w) => w.torrentId == id).toList();
          for (final w in waitersForId) {
            if (!w.completer.isCompleted) w.completer.completeError(e);
            _waiters.remove(w);
          }
        }
      }
    } finally {
      _isFetchingShared = false;
    }
  });
}

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
  final completer = Completer<void>();

  try {
    if (onCancelled != null && onCancelled()) {
      completer.completeError(CancellationException());
      return completer.future;
    }
    final t = await engine.fetchTorrent(torrent.id);
    if (onCancelled != null && onCancelled()) {
      completer.completeError(CancellationException());
      return completer.future;
    }
    if (t.hasLoadedPieces(neededPieces)) {
      completer.complete();
      return completer.future;
    }
  } catch (e) {
    completer.completeError(e);
    return completer.future;
  }

  _waiters.add(
    _TorrentPieceWaiter(torrent.id, neededPieces, completer, onCancelled),
  );
  _startSharedTimer();

  return completer.future;
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
  CancelableCompleter<void>? cancelableCompleter,
}) async {
  if (pieceCount < 0) pieceCount = 0;
  final List<int> neededPieces = [];
  final endPiece = (file.beginPiece + pieceCount).clamp(0, file.endPiece + 1);
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
