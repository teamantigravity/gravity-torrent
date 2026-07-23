import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
ScaffoldFeatureController? _activeSnackBarController;

// listen to network changes
void startConnectivityCheck(BuildContext context) {
  _connectivitySubscription?.cancel();

  _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> result,
  ) {
    if (!context.mounted) return;

    if (result.contains(ConnectivityResult.none)) {
      _activeSnackBarController?.close();
      _activeSnackBarController = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          showCloseIcon: true,
          content: Text('Network unavailable.'),
          backgroundColor: Colors.orange,
          duration: Duration(days: 365), // Ideally, unlimited duration
        ),
      );
    } else {
      // Close previous snackbar and notify recovery only if we were offline
      if (_activeSnackBarController != null) {
        _activeSnackBarController?.close();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are back online'),
            backgroundColor: Colors.lightGreen,
          ),
        );
        _activeSnackBarController = null;
      }
    }
  });
}

void stopConnectivityCheck() {
  _connectivitySubscription?.cancel();
  _connectivitySubscription = null;
  _activeSnackBarController?.close();
  _activeSnackBarController = null;
}
