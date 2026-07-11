import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:gravity_torrent/dialogs/add_torrent.dart';
import 'package:gravity_torrent/dialogs/confirm_exit.dart';
import 'package:gravity_torrent/dialogs/quitting.dart';
import 'package:gravity_torrent/dialogs/terms_of_use.dart';
import 'package:gravity_torrent/dialogs/update_available.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/navigation/navigation.dart';
import 'package:gravity_torrent/platforms/desktop/tray.dart';
import 'package:gravity_torrent/utils/app_links.dart';
import 'package:gravity_torrent/utils/connectivity.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/utils/update.dart';
import 'package:gravity_torrent/utils/permissions.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class AppShellRoute extends StatefulWidget {
  final Widget child;

  const AppShellRoute({super.key, required this.child});

  @override
  State<AppShellRoute> createState() => _AppShellRouteState();
}

class _AppShellRouteState extends State<AppShellRoute> with WindowListener {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _appLinksSubscription;
  bool isTermsOfUseDialogDisplayed = false;
  bool hasShownUpdateDialog = false;
  bool showQuittingDialog = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindowManager();
    // Defer context-dependent setup until the first frame so the widget is
    // safely mounted before we use `context`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      startConnectivityCheck(context);
      initTray(context);
      _initAppLinks();
    });
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    stopConnectivityCheck();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!mounted) return;
    // Workaround to detect if current route is the player, and pop it
    Navigator.of(context).popUntil((route) {
      final currentRouteName = route.settings.name;
      if (currentRouteName == 'player') {
        // Remove route immediately to avoid concurrency issue,
        // where player could still run while window is hidden
        Navigator.removeRoute(context, route);
      }

      return true;
    });

    windowManager.hide();
  }

  _initWindowManager() async {
    if (isDesktop()) {
      // Add this line to override the default close handler
      await windowManager.setPreventClose(true);
      if (!mounted) return;
      setState(() {});
    }
  }

  _initAppLinks() {
    _appLinks = AppLinks();
    _appLinksSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (Object e) {
        debugPrint('app_links stream error: $e');
      },
    );
    _appLinks.getInitialLink().then((uri) {
      if (uri != null && mounted) {
        _handleUri(uri);
      }
    }).catchError((Object e) {
      debugPrint('getInitialLink error: $e');
    });
  }

  void _handleUri(Uri uri) {
    var uriString = uri.toString();

    if (uri.scheme == 'magnet') {
      // Magnet link
      _openAddTorrentDialog(uriString, null);
    } else if (uri.scheme == 'content') {
      _openAddTorrentDialog(null, uriString);
    } else if (uri.scheme == 'file') {
      _openAddTorrentDialog(null, uri.toFilePath());
    } else if (uriString.startsWith(appUri)) {
      // App URI
      _openAddTorrentDialog(getTorrentLink(uriString), null);
    } else if (uri.scheme == 'gravitytorrent') {
      _openAddTorrentDialog(getTorrentLink(uriString), null);
    } else {
      // Filesystem path — check asynchronously to avoid blocking the UI thread.
      FileSystemEntity.isFile(uriString).then((isFile) {
        if (isFile && mounted) {
          _openAddTorrentDialog(null, uriString);
        }
      }).catchError((Object _) {/* not a file path, ignore */});
    }
  }

  /// Ignore updates on mobile devices & depending on user prefs
  _checkForUpdate() async {
    if (hasShownUpdateDialog) return;

    var appModel = Provider.of<AppModel>(context, listen: false);
    if (!appModel.checkForUpdate) return;

    var latestVersion = await checkForUpdate(appModel.version);
    if (latestVersion == null) return;
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      hasShownUpdateDialog = true;

      showDialog(
          context: context,
          builder: (BuildContext context) {
            return UpdateAvailableDialog(latestVersion: latestVersion);
          });
    });
  }

  _openAddTorrentDialog(
      String? initialMagnetLink, String? initialContentPath) async {
    if (!await checkAndRequestStoragePermissions(context)) return;
    if (!mounted) return;

    if (Navigator.canPop(context)) {
      // Pop current dialog, if any
      Navigator.pop(context);
    }

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AddTorrentDialog(
            initialMagnetLink: initialMagnetLink,
            initialContentPath: initialContentPath,
          );
        });
  }

  _openTermsOfUseDialog(AppModel appModel) {
    var termsOfUseAccepted = appModel.termsOfUseAccepted;

    if (!isTermsOfUseDialogDisplayed && !termsOfUseAccepted) {
      // Avoid calling the dialog multiple times
      isTermsOfUseDialogDisplayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const TermsOfUseDialog();
            });
      });
    }
  }

  _openQuittingDialog(AppModel appModel) {
    if (!showQuittingDialog) {
      showQuittingDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const QuittingDialog();
            });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(builder: (context, appModel, child) {
      if (appModel.loaded) {
        _openTermsOfUseDialog(appModel);
        _checkForUpdate();
      }

      if (appModel.quitting && !showQuittingDialog) {
        _openQuittingDialog(appModel);
      }

      return PopScope(
          canPop: false,
          onPopInvokedWithResult: (a, b) => _onWillPopApp(context),
          child: Navigation(child: widget.child));
    });
  }
}

Future<bool> _onWillPopApp(BuildContext context) async {
  return await showDialog(
    context: context,
    builder: (context) => const ConfirmExit(),
  );
}
