import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/main.dart';

const _sessionRefreshIntervalSeconds = 5;

class SessionModel extends ChangeNotifier {
  Session? session;
  Timer? _timer;
  bool _disposed = false;

  SessionModel() {
    _startSessionFetching();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchSession() async {
    try {
      session = await engine.fetchSession();
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('SessionModel.fetchSession error: $e');
    }
  }

  void _startSessionFetching() async {
    await fetchSession();
    _timer = Timer.periodic(
        const Duration(seconds: _sessionRefreshIntervalSeconds), (timer) {
      fetchSession();
    });
  }
}
