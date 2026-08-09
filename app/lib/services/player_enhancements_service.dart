import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

enum LoopMode { off, one, all }

class ABRepeatState {
  final Duration? a;
  final Duration? b;

  const ABRepeatState({this.a, this.b});

  bool get isActive => a != null && b != null;
  ABRepeatState setA(Duration d) => ABRepeatState(a: d, b: b);
  ABRepeatState setB(Duration d) => ABRepeatState(a: a, b: d);
  ABRepeatState clear() => const ABRepeatState();
}

class PlaylistItem {
  final String title;

  /// On-disk path of the media. Used as the stable identity for resume
  /// positions even when playback happens through the local streaming server.
  final String filePath;
  final int? torrentId;

  /// Name of the file inside the torrent, needed to resolve the matching
  /// [torrent_file.File] when re-opening a queue item.
  final String? fileName;

  const PlaylistItem({
    required this.title,
    required this.filePath,
    this.torrentId,
    this.fileName,
  });

  @override
  bool operator ==(Object other) =>
      other is PlaylistItem &&
      other.filePath == filePath &&
      other.torrentId == torrentId;

  @override
  int get hashCode => Object.hash(filePath, torrentId);
}

class PlayerEnhancementsService extends ChangeNotifier {
  bool _disposed = false;

  void _safeNotify() {
    if (!_disposed) super.notifyListeners();
  }

  // ── Speed ────────────────────────────────────────────────────────────────
  static const List<double> speeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];
  double _speed = 1.0;
  double get speed => _speed;

  // ── Loop ─────────────────────────────────────────────────────────────────
  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;

  // ── A-B repeat ───────────────────────────────────────────────────────────
  ABRepeatState _abRepeat = const ABRepeatState();
  ABRepeatState get abRepeat => _abRepeat;

  // ── Sleep timer ──────────────────────────────────────────────────────────
  Timer? _sleepTimer;
  DateTime? _sleepAt;
  DateTime? get sleepAt => _sleepAt;
  bool get sleepTimerActive => _sleepTimer?.isActive ?? false;

  // ── Playlist ─────────────────────────────────────────────────────────────
  List<PlaylistItem> _queue = [];
  int _currentIndex = -1;
  List<PlaylistItem> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  PlaylistItem? get currentItem =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  // ── Resume position ──────────────────────────────────────────────────────
  static const _resumePrefix = 'player_resume_';

  Player? _player;

  /// Opens a queue item on behalf of the service.
  ///
  /// A torrent file cannot simply be handed to the player as a path — it may be
  /// incomplete and has to be served through the local streaming server — so
  /// the player screen installs a handler that rebuilds the streaming pipeline
  /// and returns `true` once the media is open.
  Future<bool> Function(PlaylistItem item)? openHandler;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _completedSub;

  // Throttle resume-position persistence to avoid spamming SharedPreferences.
  Duration? _lastSavedResumePosition;

  void attachPlayer(Player player) {
    if (_disposed) return;
    _player = player;
    _positionSub?.cancel();
    _completedSub?.cancel();
    _lastSavedResumePosition = null;

    _positionSub = player.stream.position.listen(_onPosition);
    _completedSub = player.stream.completed.listen(_onCompleted);

    // Apply the current loop/speed settings to the attached player.
    unawaited(
      player.setRate(_speed).catchError((e) {
        if (kDebugMode) debugPrint('attachPlayer setRate failed: $e');
        return null;
      }),
    );
    unawaited(
      _applyLoopMode().catchError((e) {
        if (kDebugMode) debugPrint('attachPlayer _applyLoopMode failed: $e');
        return null;
      }),
    );
  }

  void detachPlayer() {
    _positionSub?.cancel();
    _completedSub?.cancel();
    _positionSub = null;
    _completedSub = null;
    _player = null;
    openHandler = null;
  }

  // ── Speed control ────────────────────────────────────────────────────────

  void setSpeed(double s) {
    if (_disposed) return;
    _speed = s.clamp(0.25, 4.0);
    final player = _player;
    if (player != null) {
      unawaited(
        player.setRate(_speed).catchError((e) {
          if (kDebugMode) debugPrint('setSpeed setRate failed: $e');
          return null;
        }),
      );
    }
    _safeNotify();
  }

  void cycleSpeed() {
    if (_disposed) return;
    final idx = speeds.indexOf(_speed);
    setSpeed(idx < 0 || idx >= speeds.length - 1 ? 1.0 : speeds[idx + 1]);
  }

  // ── Loop ─────────────────────────────────────────────────────────────────

  void cycleLoopMode() {
    if (_disposed) return;
    _loopMode = LoopMode.values[(_loopMode.index + 1) % LoopMode.values.length];
    unawaited(
      _applyLoopMode().catchError((e) {
        if (kDebugMode) debugPrint('cycleLoopMode failed: $e');
        return null;
      }),
    );
    _safeNotify();
  }

  void setLoopMode(LoopMode mode) {
    if (_disposed) return;
    _loopMode = mode;
    unawaited(
      _applyLoopMode().catchError((e) {
        if (kDebugMode) debugPrint('setLoopMode failed: $e');
        return null;
      }),
    );
    _safeNotify();
  }

  Future<void> _applyLoopMode() async {
    if (_disposed) return;
    final player = _player;
    if (player == null) return;
    switch (_loopMode) {
      case LoopMode.one:
        await player.setPlaylistMode(PlaylistMode.single);
      case LoopMode.all:
        await player.setPlaylistMode(PlaylistMode.loop);
      case LoopMode.off:
        await player.setPlaylistMode(PlaylistMode.none);
    }
  }

  // ── A-B repeat ───────────────────────────────────────────────────────────

  void setA() {
    if (_disposed) return;
    final pos = _player?.state.position;
    if (pos == null) return;
    _abRepeat = _abRepeat.setA(pos);
    _safeNotify();
  }

  void setB() {
    if (_disposed) return;
    final pos = _player?.state.position;
    if (pos == null) return;
    _abRepeat = _abRepeat.setB(pos);
    _safeNotify();
  }

  void clearABRepeat() {
    if (_disposed) return;
    _abRepeat = _abRepeat.clear();
    _safeNotify();
  }

  // ── Sleep timer ──────────────────────────────────────────────────────────

  void startSleepTimer(Duration duration) {
    if (_disposed) return;
    cancelSleepTimer();
    _sleepAt = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      if (_disposed) return;
      _player?.pause();
      _sleepAt = null;
      _safeNotify();
    });
    _safeNotify();
  }

  void cancelSleepTimer() {
    if (_disposed) return;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    _safeNotify();
  }

  // ── Playlist ─────────────────────────────────────────────────────────────

  void setQueue(List<PlaylistItem> items, {int startIndex = 0}) {
    if (_disposed) return;
    _queue = List.of(items);
    _currentIndex = items.isEmpty ? -1 : startIndex.clamp(0, items.length - 1);
    _safeNotify();
  }

  void addToQueue(PlaylistItem item) {
    if (_disposed) return;
    _queue.add(item);
    if (_queue.length == 1) _currentIndex = 0;
    _safeNotify();
  }

  void removeFromQueue(int index) {
    if (_disposed || index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _safeNotify();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (_disposed || oldIndex < 0 || oldIndex >= _queue.length) return;
    // ReorderableListView reports the *insertion* index, which is computed
    // before the dragged row is removed. Dragging downwards therefore has to be
    // shifted back by one or the item lands one slot too far.
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) targetIndex -= 1;

    final current = currentItem;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(targetIndex.clamp(0, _queue.length), item);

    _currentIndex = current != null ? _queue.indexOf(current) : -1;
    if (_currentIndex < 0 || _currentIndex >= _queue.length) {
      _currentIndex = _queue.isNotEmpty ? 0 : -1;
    }
    _safeNotify();
  }

  Future<PlaylistItem?> playNext() async {
    if (_disposed) return null;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _openCurrent();
      if (_disposed) return null;
      _safeNotify();
      return currentItem;
    } else if (_loopMode == LoopMode.all && _queue.isNotEmpty) {
      _currentIndex = 0;
      await _openCurrent();
      if (_disposed) return null;
      _safeNotify();
      return currentItem;
    }
    return null;
  }

  Future<PlaylistItem?> playPrevious() async {
    if (_disposed) return null;
    if (_currentIndex > 0) {
      _currentIndex--;
      await _openCurrent();
      if (_disposed) return null;
      _safeNotify();
      return currentItem;
    }
    return null;
  }

  Future<void> _openCurrent() async {
    if (_disposed) return;
    final item = currentItem;
    if (item == null) return;

    final handler = openHandler;
    if (handler != null) {
      if (!await handler(item)) return;
      if (_disposed) return;
    } else {
      final player = _player;
      if (player == null) return;
      await player.open(Media(item.filePath));
      if (_disposed) return;
    }

    await restoreResumePosition(item.filePath);
    if (_disposed) return;

    // Re-apply speed/loop after each open because some players reset them.
    await _player?.setRate(_speed);
    if (_disposed) return;
    await _applyLoopMode();
  }

  /// Seeks the attached player to the stored resume position for [path].
  ///
  /// Very early positions are ignored so that restarting a title the user only
  /// glanced at does not drop them a few seconds in.
  Future<void> restoreResumePosition(String path) async {
    if (_disposed) return;
    _lastSavedResumePosition = null;
    final player = _player;
    if (player == null) return;
    final resume = await getResumePosition(path);
    if (_disposed || resume == null || resume.inSeconds <= 5) return;
    await player.seek(resume);
    _lastSavedResumePosition = resume;
  }

  // ── Resume position ──────────────────────────────────────────────────────

  /// Builds the storage key for a media [path].
  ///
  /// A SHA-1 digest is used instead of `String.hashCode` because `hashCode` is
  /// not guaranteed to be stable across Dart VM versions (so saved positions
  /// would silently disappear after an SDK upgrade) and its 32-bit range
  /// collides far too easily across a large library.
  @visibleForTesting
  static String resumeKeyFor(String path) =>
      '$_resumePrefix${sha1.convert(utf8.encode(path))}';

  Future<void> saveResumePosition(String path, Duration position) async {
    await SharedPrefs.setInt(resumeKeyFor(path), position.inMilliseconds);
  }

  Future<Duration?> getResumePosition(String path) async {
    final ms = SharedPrefs.getInt(resumeKeyFor(path));
    return ms != null ? Duration(milliseconds: ms) : null;
  }

  Future<void> clearResumePosition(String path) async {
    await SharedPrefs.remove(resumeKeyFor(path));
  }

  // ── Internal listeners ───────────────────────────────────────────────────

  void _onPosition(Duration pos) {
    if (_disposed) return;
    // A-B repeat enforcement
    if (_abRepeat.isActive) {
      if (pos >= _abRepeat.b!) {
        unawaited(
          _player?.seek(_abRepeat.a!).catchError((e) {
            if (kDebugMode) debugPrint('A-B repeat seek failed: $e');
            return null;
          }),
        );
      }
    }

    // Save resume position every 5 seconds of playback (or after a seek)
    final item = currentItem;
    if (item != null && pos.inSeconds > 0) {
      final last = _lastSavedResumePosition ?? Duration.zero;
      if ((pos - last).inSeconds.abs() >= 5) {
        _lastSavedResumePosition = pos;
        unawaited(
          saveResumePosition(item.filePath, pos).catchError((e) {
            if (kDebugMode) debugPrint('saveResumePosition failed: $e');
            return null;
          }),
        );
      }
    }
  }

  void _onCompleted(bool completed) {
    if (!completed || _disposed) return;

    final item = currentItem;
    if (item != null) {
      clearResumePosition(item.filePath);
    }

    if (_loopMode == LoopMode.one) {
      final player = _player;
      if (player != null) {
        unawaited(
          player.seek(Duration.zero).then((_) => player.play()).catchError((e) {
            if (kDebugMode) debugPrint('Loop-one restart failed: $e');
            return null;
          }),
        );
      }
    } else {
      unawaited(
        playNext().catchError((e) {
          if (kDebugMode) debugPrint('playNext failed: $e');
          return null;
        }),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    detachPlayer();
    cancelSleepTimer();
    super.dispose();
  }
}
