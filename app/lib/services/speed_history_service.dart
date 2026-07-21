import 'dart:collection';

/// In-memory per-torrent download speed history.
///
/// Stores up to [maxSamples] speed readings per torrent. Readings are added
/// every 5 seconds by [TorrentsModel]. This data is session-only — it is not
/// persisted to disk.
class SpeedHistoryService {
  SpeedHistoryService._();
  static final SpeedHistoryService instance = SpeedHistoryService._();

  /// Maximum number of samples to keep per torrent.
  /// At one sample every 5 s this covers the last 5 minutes.
  static const int maxSamples = 60;

  final Map<int, Queue<double>> _history = {};

  /// Records a [speedBytesPerSec] sample for [torrentId].
  void record(int torrentId, double speedBytesPerSec) {
    final q = _history.putIfAbsent(torrentId, Queue.new);
    q.addLast(speedBytesPerSec);
    if (q.length > maxSamples) q.removeFirst();
  }

  /// Returns up to [maxSamples] speed readings for [torrentId], oldest first.
  /// Returns an empty list if no data exists.
  List<double> getHistory(int torrentId) {
    final q = _history[torrentId];
    if (q == null) return [];
    return List<double>.unmodifiable(q);
  }

  /// Removes all speed history for [torrentId]. Call when a torrent is deleted.
  void removeTorrent(int torrentId) {
    _history.remove(torrentId);
  }

  /// Clears all speed history.
  void clear() {
    _history.clear();
  }
}
