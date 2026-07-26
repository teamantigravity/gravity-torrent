import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/navigation/router.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/platforms/android/foreground_service.dart'
    as foreground;
import 'package:gravity_torrent/main.dart';
import 'package:provider/provider.dart';

Future<void> closeApp([BuildContext? context]) async {
  final ctx = context ?? rootNavigatorKey.currentContext;
  if (ctx != null) {
    final appModel = Provider.of<AppModel>(ctx, listen: false);
    final torrentModel = Provider.of<TorrentsModel>(ctx, listen: false);
    torrentModel.stopTimer();
    appModel.setQuitting(true);
    await appModel.quitGracefully();
  } else {
    // Fallback if context is null
    await stopServices();
    if (getIt.isRegistered<Engine>()) {
      await getIt<Engine>().shutdown();
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await foreground.stopForegroundService();
    }
    exit(0);
  }
}
