// ignore_for_file: deprecated_member_use
// import 'package:flutter/material.dart' hide MenuItem;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/utils/lifecycle.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

AppTrayListener? _trayListener;

initTray(BuildContext context) async {
  if (!isDesktop()) return;

  try {
    if (_trayListener != null) {
      trayManager.removeListener(_trayListener!);
    }
    _trayListener = AppTrayListener(onExit: closeApp);
    trayManager.addListener(_trayListener!);

    if (Platform.isWindows) {
      await trayManager.setIcon('assets/tray_icon.ico');
    } else if (isFlatpak()) {
      await trayManager.setIcon(
        Platform.environment['FLATPAK_ID'] ?? 'assets/tray_icon.png',
      );
    } else {
      await trayManager.setIcon('assets/tray_icon.png');
    }

    if (Platform.isWindows || Platform.isMacOS) {
      await trayManager.setToolTip('Gravity Torrent');
    }

    Menu menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'Show Window'),
        MenuItem.separator(),
        MenuItem(key: 'pause_all', label: 'Pause All Torrents'),
        MenuItem(key: 'resume_all', label: 'Resume All Torrents'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit App'),
      ],
    );

    await trayManager.setContextMenu(menu);
  } catch (e) {
    debugPrint(e.toString());
  }
}

closeTray() async {
  if (!isDesktop()) return;
  await trayManager.destroy();
}

class AppTrayListener extends TrayListener {
  final VoidCallback onExit;

  AppTrayListener({required this.onExit});

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    debugPrint('onTrayMenuItemClick ${menuItem.key}');
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'pause_all') {
      try {
        final engine = getIt<Engine>();
        final torrents = await engine.fetchTorrents();
        await engine.pauseTorrents(torrents.map((t) => t.id).toList());
      } catch (e) {
        debugPrint('Tray pause_all error: $e');
      }
    } else if (menuItem.key == 'resume_all') {
      try {
        final engine = getIt<Engine>();
        final torrents = await engine.fetchTorrents();
        await engine.resumeTorrents(torrents.map((t) => t.id).toList());
      } catch (e) {
        debugPrint('Tray resume_all error: $e');
      }
    } else if (menuItem.key == 'exit_app') {
      await windowManager.show();
      await windowManager.focus();
      onExit();
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // bringAppToFront should be set until
    // https://github.com/leanflutter/tray_manager/issues/63 is resolved
    trayManager.popUpContextMenu(bringAppToFront: true);
  }
}
