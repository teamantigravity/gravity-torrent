import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
ScaffoldFeatureController? _activeSnackBarController;
bool _isOffline = false;

// listen to network changes
void startConnectivityCheck(BuildContext context) {
  _connectivitySubscription?.cancel();
  _isOffline = false;

  _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> results,
  ) {
    if (!context.mounted) return;

    final offline = results.every((r) => r == ConnectivityResult.none);

    if (offline) {
      _isOffline = true;
      _activeSnackBarController?.close();
      _activeSnackBarController = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          showCloseIcon: true,
          content: Text('Network unavailable.'),
          backgroundColor: Colors.orange,
          duration: Duration(days: 365), // Ideally, unlimited duration
        ),
      );
    } else if (_isOffline) {
      // Only show "back online" if we were previously offline
      _isOffline = false;
      _activeSnackBarController?.close();
      _activeSnackBarController = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are back online'),
          backgroundColor: Colors.lightGreen,
        ),
      );
    }
  });
}

void stopConnectivityCheck() {
  _connectivitySubscription?.cancel();
  _connectivitySubscription = null;
  _activeSnackBarController?.close();
  _activeSnackBarController = null;
  _isOffline = false;
}
