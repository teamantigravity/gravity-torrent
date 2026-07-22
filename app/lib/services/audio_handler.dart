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
  final List<StreamSubscription> _subscriptions = [];

  bool _playing = false;
  bool _buffering = false;
  bool _completed = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;

  MediaKitAudioHandler() {
    _instance = this;
  }

  /// Attach or detach a [media_kit] player. Call with `null` when playback
  /// stops to clear the media notification.
  Future<void> setPlayer(Player? player, {MediaItem? item}) async {
    await _disposeSubscriptions();

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
        _playing = playing;
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.buffering.listen((buffering) {
        _buffering = buffering;
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.completed.listen((completed) {
        _completed = completed;
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.position.listen((position) {
        _position = position;
      }),
    );

    _subscriptions.add(
      player.stream.duration.listen((duration) {
        _duration = duration;
        _updateMediaItemDuration();
        _emitState();
      }),
    );

    _subscriptions.add(
      player.stream.rate.listen((rate) {
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
    final current = mediaItem.value;
    if (current == null || _duration == current.duration) return;
    mediaItem.add(current.copyWith(duration: _duration));
  }

  void _emitState() {
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
  Future<void> play() async => await _player?.play();

  @override
  Future<void> pause() async => await _player?.pause();

  @override
  Future<void> stop() async {
    await _player?.stop();
    await setPlayer(null);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
    _position = position;
    _emitState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player?.setRate(speed);
    _speed = speed;
    _emitState();
  }

  @override
  Future<void> onNotificationDeleted() async => await setPlayer(null);

  @override
  Future<void> onTaskRemoved() async => await setPlayer(null);

  Future<void> dispose() async {
    await _disposeSubscriptions();
    _player = null;
    _instance = null;
  }
}
