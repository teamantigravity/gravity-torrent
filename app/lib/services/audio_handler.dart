import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

/// Bridges [media_kit] playback with the platform media session / notification
/// via [audio_service]. This enables background audio and lock-screen / control
/// center controls on Android, iOS and macOS.
class MediaKitAudioHandler extends BaseAudioHandler {
  static MediaKitAudioHandler? _instance;
  static MediaKitAudioHandler? get instance => _instance;

  Player? _player;
  final List<StreamSubscription<void>> _subscriptions = [];

  bool _playing = false;
  bool _buffering = false;
  bool _completed = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;

  // Guards against emitting state after the handler has been disposed.
  bool _disposed = false;

  MediaKitAudioHandler() {
    _instance = this;
  }

  /// Attach or detach a [media_kit] player. Call with `null` when playback
  /// stops to clear the media notification.
  Future<void> setPlayer(Player? player, {MediaItem? item}) async {
    if (_disposed) return;
    await _disposeSubscriptions();
    if (_disposed) return;

    _player = player;
    _completed = false;
    _buffering = false;

    if (player == null) {
      mediaItem.add(null);
      playbackState.add(PlaybackState());
      return;
    }

    if (item != null) mediaItem.add(item);

    _subscriptions.add(
      player.stream.playing.listen((playing) {
        if (_disposed) return;
        _playing = playing;
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.buffering.listen((buffering) {
        if (_disposed) return;
        _buffering = buffering;
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.completed.listen((completed) {
        if (_disposed) return;
        _completed = completed;
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.position.listen((position) {
        if (_disposed) return;
        _position = position;
      }),
    );

    _subscriptions.add(
      player.stream.duration.listen((duration) {
        if (_disposed) return;
        _duration = duration;
        _updateMediaItemDuration();
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.rate.listen((rate) {
        if (_disposed) return;
        _speed = rate;
        _emitState();
      }),
    );

    _emitState();
  }

  Future<void> _disposeSubscriptions() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _updateMediaItemDuration() {
    if (_disposed) return;
    final current = mediaItem.value;
    if (current == null || _duration == current.duration) return;
    mediaItem.add(current.copyWith(duration: _duration));
  }

  void _emitState() {
    if (_disposed) return;
    final controls = <MediaControl>[
      if (_playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
    ];

    AudioProcessingState processing;
    if (_buffering) {
      processing = AudioProcessingState.buffering;
    } else if (_completed) {
      processing = AudioProcessingState.completed;
    } else if (_duration > Duration.zero) {
      processing = AudioProcessingState.ready;
    } else if (_playing) {
      processing = AudioProcessingState.loading;
    } else {
      processing = AudioProcessingState.idle;
    }

    playbackState.add(
      PlaybackState(
        processingState: processing,
        playing: _playing,
        controls: controls,
        systemActions: {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.seek,
        },
        updatePosition: _position,
        bufferedPosition: _position,
        speed: _speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await _player?.pause();
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _player?.stop();
    await setPlayer(null);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await _player?.seek(position);
    _position = position;
    _emitState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    await _player?.setRate(speed);
    _speed = speed;
    _emitState();
  }

  @override
  Future<void> onNotificationDeleted() => setPlayer(null);

  @override
  Future<void> onTaskRemoved() => setPlayer(null);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _disposeSubscriptions();
    _player = null;
    _instance = null;
    await playbackState.close();
    await mediaItem.close();
  }
}
