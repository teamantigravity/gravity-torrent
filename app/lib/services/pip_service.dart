import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop compact floating player support.
///
/// Uses [window_manager] to create a small always-on-top floating window for
/// the player on desktop. Mobile and web are not supported by the current
/// player.
class PipService {
  PipService._();
  static final PipService instance = PipService._();

  bool _isFloating = false;
  bool _disposed = false;
  Future<void>? _operation;

  bool get isFloating => _isFloating;

  Future<void> enterCompactFloating(BuildContext context) async {
    if (_disposed || kIsWeb || !isDesktop()) return;
    await _withLock(() async {
      await windowManager.setSize(const Size(480, 270));
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setMinimumSize(const Size(320, 180));
      _isFloating = true;
    });
  }

  Future<void> exitCompactFloating(BuildContext context) async {
    if (_disposed || kIsWeb || !isDesktop()) return;
    await _withLock(() async {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(const Size(360, 360));
      await windowManager.setSize(const Size(1280, 720));
      _isFloating = false;
    });
  }

  Future<T> _withLock<T>(Future<T> Function() task) {
    final previous = _operation;
    final current = Future<T>(() async {
      if (previous != null) await previous;
      return task();
    });
    _operation = current;
    unawaited(
      current.whenComplete(() {
        if (_operation == current) _operation = null;
      }),
    );
    return current;
  }

  void dispose() {
    _disposed = true;
    _operation = null;
  }

  static bool isDesktop() =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}
