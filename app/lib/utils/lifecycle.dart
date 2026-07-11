import 'package:flutter/material.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/navigation/router.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void closeApp([BuildContext? context]) async {
  final ctx = context ?? rootNavigatorKey.currentContext;
  if (ctx == null) return;
  final appModel = Provider.of<AppModel>(ctx, listen: false);
  final torrentModel = Provider.of<TorrentsModel>(ctx, listen: false);
  torrentModel.stopTimer();
  appModel.setQuitting(true);

  if (isDesktop()) {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      appModel.quitGracefully();
    }
  } else {
    appModel.quitGracefully();
  }
}
