import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _activeSnackBar;
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  void start(BuildContext context) {
    _subscription?.cancel();
    _isOffline = false;

    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (!context.mounted) return;

      final offline = results.every((r) => r == ConnectivityResult.none);

      if (offline && !_isOffline) {
        _isOffline = true;
        _activeSnackBar = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).connectionLost,
            ),
            duration: const Duration(days: 1),
            backgroundColor: Colors.red,
          ),
        );
      } else if (!offline && _isOffline) {
        _isOffline = false;
        _activeSnackBar?.close();
        _activeSnackBar = null;
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _activeSnackBar?.close();
    _activeSnackBar = null;
    _isOffline = false;
  }
}
