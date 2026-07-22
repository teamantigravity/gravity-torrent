import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

/// Mobile app shortcuts / quick actions service.
///
/// On Android/iOS this registers app shortcuts that jump to adding a torrent
/// or opening the torrents list. Desktop is not supported by the underlying
/// plugin, so registration is skipped there.
class ShortcutsService {
  static const QuickActions _quickActions = QuickActions();
  static VoidCallback? _onAddTorrent;
  static VoidCallback? _onOpenTorrents;
  static bool _initialized = false;

  static void initialize({
    required VoidCallback onAddTorrent,
    required VoidCallback onOpenTorrents,
  }) {
    if (isDesktop()) return;

    _onAddTorrent = onAddTorrent;
    _onOpenTorrents = onOpenTorrents;
    _initialized = true;

    _quickActions.initialize((String shortcutType) {
      if (shortcutType == 'add_torrent') {
        _onAddTorrent?.call();
      } else if (shortcutType == 'open_torrents') {
        _onOpenTorrents?.call();
      }
    });
  }

  static void setEnabled(bool enabled) {
    if (isDesktop() || !_initialized) return;

    if (!enabled) {
      _quickActions.setShortcutItems(<ShortcutItem>[]);
      return;
    }

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
    ]);
  }

  static bool isDesktop() =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}
