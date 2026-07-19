import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop compact floating player support.
///
/// Uses [window_manager] to create a small always-on-top floating window for
/// the player on desktop. Mobile is not supported by the current player.
class PipService {
  PipService._();
  static final PipService instance = PipService._();

  bool _isFloating = false;

  bool get isFloating => _isFloating;

  Future<void> enterCompactFloating(BuildContext context) async {
    if (!isDesktop()) return;
    await windowManager.setSize(const Size(480, 270));
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setMinimumSize(const Size(320, 180));
    _isFloating = true;
  }

  Future<void> exitCompactFloating(BuildContext context) async {
    if (!isDesktop()) return;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMinimumSize(const Size(360, 360));
    await windowManager.setSize(const Size(1280, 720));
    _isFloating = false;
  }

  static bool isDesktop() =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
