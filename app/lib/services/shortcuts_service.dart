import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// Mobile app shortcuts / quick actions service.
///
/// On Android/iOS this registers app shortcuts that jump to adding a torrent
/// or opening the torrents list. Desktop and web are not supported by the
/// underlying plugin, so registration is skipped there.
class ShortcutsService {
  static const QuickActions _quickActions = QuickActions();
  static VoidCallback? _onAddTorrent;
  static VoidCallback? _onOpenTorrents;
  static bool _initialized = false;

  static bool get _supported => !kIsWeb && !isDesktop();

  static void initialize({
    required VoidCallback onAddTorrent,
    required VoidCallback onOpenTorrents,
  }) {
    if (!_supported) return;

    _onAddTorrent = onAddTorrent;
    _onOpenTorrents = onOpenTorrents;
    _initialized = true;

    unawaited(
      _quickActions.initialize((String shortcutType) {
        if (shortcutType == 'add_torrent') {
          _onAddTorrent?.call();
        } else if (shortcutType == 'open_torrents') {
          _onOpenTorrents?.call();
        }
      }).catchError((Object e) {
        if (kDebugMode) debugPrint('ShortcutsService initialize error: $e');
      }),
    );
  }

  static void setEnabled(bool enabled) {
    if (!_supported || !_initialized) return;

    if (!enabled) {
      unawaited(
        _quickActions.setShortcutItems(<ShortcutItem>[]).catchError((Object e) {
          if (kDebugMode) debugPrint('ShortcutsService setEnabled error: $e');
        }),
      );
      return;
    }

    unawaited(
      _quickActions.setShortcutItems(const <ShortcutItem>[
        ShortcutItem(
          type: 'add_torrent',
          localizedTitle: 'Add torrent',
          icon: 'ic_launcher',
        ),
        ShortcutItem(
          type: 'open_torrents',
          localizedTitle: 'My torrents',
          icon: 'ic_launcher',
        ),
      ]).catchError((Object e) {
        if (kDebugMode) debugPrint('ShortcutsService setEnabled error: $e');
      }),
    );
  }

  static void dispose() {
    if (!_supported || !_initialized) return;
    _onAddTorrent = null;
    _onOpenTorrents = null;
    _initialized = false;
    unawaited(
      _quickActions.setShortcutItems(<ShortcutItem>[]).catchError((Object e) {
        if (kDebugMode) debugPrint('ShortcutsService dispose error: $e');
      }),
    );
  }

  static bool isDesktop() =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}
