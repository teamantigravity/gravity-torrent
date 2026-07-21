import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:async/async.dart';
import 'package:audio_service/audio_service.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/audio_handler.dart';
import 'package:gravity_torrent/services/haptic_service.dart';
import 'package:gravity_torrent/services/pip_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:gravity_torrent/engine/file.dart' as torrent_file;
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/utils/device.dart' as device;
import 'package:gravity_torrent/models/feature_flags.dart';
import 'package:gravity_torrent/utils/streaming_server.dart';
import 'package:gravity_torrent/utils/subtitles.dart';
import 'package:gravity_torrent/utils/subtitles_server.dart';
import 'package:gravity_torrent/utils/torrent_utils.dart';
import 'package:gravity_torrent/widgets/torrent_player/dialogs/audio_track_selector.dart';
import 'package:gravity_torrent/widgets/torrent_player/dialogs/subtitles_selector.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';

const bufferSize = 2 * 1024 * 1024;

class TorrentPlayer extends StatefulWidget {
  final torrent_file.File file;
  final String filePath;
  final Torrent torrent;

  const TorrentPlayer({
    super.key,
    required this.filePath,
    required this.torrent,
    required this.file,
  });

  @override
  State<TorrentPlayer> createState() => TorrentPlayerState();
}

class StreamingPlayer extends Player {
  StreamingServer server;

  StreamingPlayer({required super.configuration, required this.server});

  @override
  Future<void> seek(Duration duration) {
    // Cancel previous request, which might block next seek command
    server.cancelRequest();
    return super.seek(duration);
  }
}

class TorrentPlayerState extends State<TorrentPlayer> {
  StreamingPlayer? player;
  StreamingServer? server;
  SubtitlesServer? subsServer;
  VideoController? controller;
  bool _disposed = false;
  final GlobalKey _videoComponentKey = GlobalKey();

  @override
  void initState() {
    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    super.initState();
    initPlayer();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    await widget.torrent.stopStreaming();
    // Stop playback and detach from the platform media session before
    // disposing the native player.
    await player?.stop();
    await MediaKitAudioHandler.instance?.setPlayer(null);
    await player?.dispose();
    await server?.stop();
    await subsServer?.stop();
    // leave immersive mode
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void initPlayer() async {
    // Streaming server
    server = StreamingServer(
      filePath: widget.filePath,
      bufferSize: bufferSize,
      torrent: widget.torrent,
      torrentFile: widget.file,
    );

    player = StreamingPlayer(
      configuration: const PlayerConfiguration(bufferSize: bufferSize),
      server: server!,
    );

    controller = VideoController(
      player!,
      configuration: const VideoControllerConfiguration(),
    );

    await (player!.platform as NativePlayer).setProperty(
      'network-timeout',
      '0',
    );
    await (player!.platform as NativePlayer).setProperty('cache', 'no');
    if (_disposed) return;

    player!.stream.log.listen((log) {
      if (kDebugMode) debugPrint('mpv: $log');
    });

    await widget.torrent.startStreaming(widget.file);

    // Preload video file (wait for first piece)
    if (widget.torrent.progress != 1) {
      final completer = CancelableCompleter<void>();
      if (!mounted) return;
      onVideoLoading(completer);

      try {
        await waitForPieces(
          torrent: widget.torrent,
          file: widget.file,
          pieceCount: 1,
          cancelableCompleter: completer,
        );
      } catch (e) {
        if (!mounted) return;
        if (e is CancellationException) {
          return; // Exit silently
        }
        // Close the loading dialog and exit the player on other errors.
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (Navigator.canPop(context)) Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      // Check if we're still showing a dialog before popping
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;
    }

    if (_disposed) return;
    // Start streaming server after video file is ready
    await server!.start();
    final serverAdress = await server!.getAddress();
    if (_disposed) return;

    if (kDebugMode) debugPrint('download subs');
    // Download subtitles
    if (widget.torrent.progress != 1) {
      final completer = CancelableCompleter<void>();
      if (!mounted) return;
      onSubtitlesLoading(completer);

      try {
        await downloadSubtitles(
          widget.file,
          widget.torrent,
          cancelableCompleter: completer,
        );
      } catch (e) {
        if (!mounted) return;
        if (e is CancellationException) {
          return; // Exit silently
        }
        // Close the loading dialog and exit the player on other errors.
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (Navigator.canPop(context)) Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      // Check if we're still showing a dialog before popping
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;
    }

    // Initialize subtitles server
    final subsServer = SubtitlesServer(torrent: widget.torrent);
    this.subsServer = subsServer;
    await subsServer.start();
    final subtitlesServerAdress = await subsServer.getAddress();
    if (_disposed) return;

    if (kDebugMode) debugPrint('open player');
    await player!.open(Media(serverAdress));
    if (_disposed) return;
    final externalSubtitlesFiles = getExternalSubtitles(
      widget.file,
      widget.torrent,
    );

    final externalSubtitles = externalSubtitlesFiles
        .map(
          (f) => ExternalSubtitle(
            name: truncateFromLastSlash(f.name),
            url: Uri.encodeFull('$subtitlesServerAdress/${f.name}'),
            language: detectSubtitleLanguage(f.name),
          ),
        )
        .toList();

    // Load external subtitles to be able to select them
    for (final sub in externalSubtitles) {
      await player!.setSubtitleTrack(
        SubtitleTrack.uri(sub.url, title: sub.name, language: sub.language),
      );
    }

    await player!.setSubtitleTrack(SubtitleTrack.no());

    await player!.play();

    // Register with the platform media session for background controls
    final audioHandler = MediaKitAudioHandler.instance;
    if (audioHandler != null) {
      await audioHandler.setPlayer(
        player!,
        item: MediaItem(
          id: widget.filePath,
          title: widget.file.name,
          album: widget.torrent.name,
          duration: player!.state.duration,
        ),
      );
    }
  }

  void onVideoLoading(CancelableCompleter completer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Loading Video...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [Center(child: CircularProgressIndicator())],
        ),
        actions: [
          TextButton(
            onPressed: () {
              completer.operation.cancel();
              Navigator.pop(context); // Close dialog
              if (Navigator.canPop(context)) {
                Navigator.pop(context); // Exit player screen
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void onSubtitlesLoading(CancelableCompleter completer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Loading Subtitles...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [Center(child: CircularProgressIndicator())],
        ),
        actions: [
          TextButton(
            onPressed: () {
              completer.operation.cancel();
              Navigator.pop(context); // Close dialog
              if (Navigator.canPop(context)) {
                Navigator.pop(context); // Exit player screen
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  onSubtitlesClick() {
    if (player == null) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SubtitlesSelectorDialog(
          subtitles: player!.state.tracks.subtitle,
          currentValue: player!.state.track.subtitle.id,
          onSubtitleSelected: (SubtitleTrack sub) async {
            await player!.setSubtitleTrack(sub);
          },
        );
      },
    );
  }

  onAudioTrackClick() {
    if (player == null) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AudioTrackSelectorDialog(
          tracks: player!.state.tracks.audio,
          currentValue: player!.state.track.audio.id,
          onTrackSelected: (AudioTrack track) async {
            await player!.setAudioTrack(track);
          },
        );
      },
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        HapticService.light();
        Navigator.pop(context);
        AdServiceProvider.instance.showInterstitialIfReady();
      },
    );
  }

  Widget _buildPipButton() {
    if (!device.isDesktop()) return const SizedBox.shrink();
    final pipEnabled = context.select<FeatureFlagsModel, bool>(
      (flags) => flags.usePipBackgroundAudio,
    );
    if (!pipEnabled) return const SizedBox.shrink();

    return MaterialDesktopCustomButton(
      icon: Icon(
        PipService.instance.isFloating
            ? Icons.fullscreen
            : Icons.picture_in_picture_alt,
      ),
      onPressed: () async {
        HapticService.medium();
        if (PipService.instance.isFloating) {
          await PipService.instance.exitCompactFloating(context);
        } else {
          await PipService.instance.enterCompactFloating(context);
        }
        setState(() {});
      },
    );
  }

  Widget _buildSubtitlesButton() {
    return MaterialDesktopCustomButton(
      icon: const Icon(Icons.subtitles),
      onPressed: onSubtitlesClick,
    );
  }

  Widget _buildAudioTrackButton() {
    return MaterialDesktopCustomButton(
      icon: const Icon(Icons.multitrack_audio),
      onPressed: onAudioTrackClick,
    );
  }

  List<Widget> _buildMobileBottomButtonBar() {
    return [
      const MaterialPositionIndicator(),
      const Spacer(),
      _buildSubtitlesButton(),
      _buildAudioTrackButton(),
      _buildPipButton(),
    ];
  }

  List<Widget> _buildDesktopBottomButtonBar() {
    return [
      const MaterialDesktopSkipPreviousButton(),
      const MaterialDesktopPlayOrPauseButton(),
      const MaterialDesktopSkipNextButton(),
      const MaterialDesktopVolumeButton(),
      const MaterialDesktopPositionIndicator(),
      const Spacer(),
      _buildSubtitlesButton(),
      _buildAudioTrackButton(),
      _buildPipButton(),
      const MaterialDesktopFullscreenButton(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final videoController = controller;
    final body = videoController == null
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              device.isMobile()
                  ? MaterialVideoControlsTheme(
                      normal: MaterialVideoControlsThemeData(
                        seekBarThumbColor: const Color(0xFF4285F4),
                        seekBarPositionColor: const Color(0xFF4285F4),
                        padding: const EdgeInsets.only(bottom: 64),
                        topButtonBar: [_buildBackButton()],
                        bottomButtonBar: _buildMobileBottomButtonBar(),
                      ),
                      fullscreen: MaterialVideoControlsThemeData(
                        seekBarThumbColor: const Color(0xFF4285F4),
                        seekBarPositionColor: const Color(0xFF4285F4),
                        padding: const EdgeInsets.only(bottom: 64),
                        topButtonBar: [_buildBackButton()],
                        bottomButtonBar: _buildMobileBottomButtonBar(),
                      ),
                      child: Video(
                        key: _videoComponentKey,
                        controller: videoController,
                        controls: MaterialVideoControls,
                      ),
                    )
                  : MaterialDesktopVideoControlsTheme(
                      normal: MaterialDesktopVideoControlsThemeData(
                        seekBarThumbColor: const Color(0xFF4285F4),
                        seekBarPositionColor: const Color(0xFF4285F4),
                        topButtonBar: [_buildBackButton()],
                        bottomButtonBar: _buildDesktopBottomButtonBar(),
                      ),
                      fullscreen: MaterialDesktopVideoControlsThemeData(
                        seekBarThumbColor: const Color(0xFF4285F4),
                        seekBarPositionColor: const Color(0xFF4285F4),
                        topButtonBar: [_buildBackButton()],
                        bottomButtonBar: _buildDesktopBottomButtonBar(),
                      ),
                      child: Video(
                        key: _videoComponentKey,
                        controller: videoController,
                        controls: MaterialDesktopVideoControls,
                      ),
                    ),
            ],
          );

    return Theme(
      data: ThemeData.dark(),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: device.isDesktop()
              ? const WindowTitleBar(backgroundColor: Colors.black)
              : AppBar(toolbarHeight: 0),
          body: body,
        ),
      ),
    );
  }
}
