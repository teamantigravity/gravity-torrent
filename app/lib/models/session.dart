import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/main.dart';

const _sessionRefreshIntervalSeconds = 5;

class SessionModel extends ChangeNotifier {
  Session? session;
  Timer? _timer;
  bool _disposed = false;
  bool _isFetching = false;

  SessionModel() {
    unawaited(_startSessionFetching());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchSession() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      session = await engine.fetchSession();
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('SessionModel.fetchSession error: $e');
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _startSessionFetching() async {
    await fetchSession();
    if (_disposed) return;
    _timer = Timer.periodic(
      const Duration(seconds: _sessionRefreshIntervalSeconds),
      (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        unawaited(fetchSession());
      },
    );
  }
}
