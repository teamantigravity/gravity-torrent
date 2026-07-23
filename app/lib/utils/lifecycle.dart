import 'package:flutter/material.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/navigation/router.dart';
import 'package:provider/provider.dart';

void closeApp([BuildContext? context]) async {
  final ctx = context ?? rootNavigatorKey.currentContext;
  if (ctx == null) return;
  final appModel = Provider.of<AppModel>(ctx, listen: false);
  final torrentModel = Provider.of<TorrentsModel>(ctx, listen: false);
  torrentModel.stopTimer();
  appModel.setQuitting(true);

  await appModel.quitGracefully();
}
