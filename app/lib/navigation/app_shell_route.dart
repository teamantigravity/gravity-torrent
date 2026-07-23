import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity_torrent/dialogs/add_torrent.dart';
import 'package:gravity_torrent/dialogs/confirm_exit.dart';
import 'package:gravity_torrent/dialogs/quitting.dart';
import 'package:gravity_torrent/dialogs/terms_of_use.dart';
import 'package:gravity_torrent/dialogs/update_available.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/feature_flags.dart';
import 'package:gravity_torrent/ui/adaptive/adaptive_navigation.dart';
import 'package:gravity_torrent/platforms/desktop/tray.dart';
import 'package:gravity_torrent/services/shortcuts_service.dart';
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
  AppModel? _appModel;
  bool _postLoadChecksDone = false;

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
      _initShortcuts();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appModel == null) {
      _appModel = context.read<AppModel>();
      _appModel!.addListener(_onAppModelChanged);
      _onAppModelChanged();
    }
  }

  void _onAppModelChanged() {
    if (!mounted) return;
    final appModel = _appModel!;
    if (appModel.loaded && !_postLoadChecksDone) {
      _postLoadChecksDone = true;
      _openTermsOfUseDialog(appModel);
      _checkForUpdate();
    }
    if (appModel.quitting && !showQuittingDialog) {
      _openQuittingDialog(appModel);
    }
  }

  void _initShortcuts() {
    final flags = Provider.of<FeatureFlagsModel>(context, listen: false);

    ShortcutsService.initialize(
      onAddTorrent: () {
        if (!mounted) return;
        _openAddTorrentDialog(null, null);
      },
      onOpenTorrents: () {
        if (!mounted) return;
        if (context.mounted) context.go('/torrents');
      },
    );

    ShortcutsService.setEnabled(flags.enableShortcuts);
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    stopConnectivityCheck();
    windowManager.removeListener(this);
    _appModel?.removeListener(_onAppModelChanged);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!mounted) return;
    // Detect if current route is the player, and pop it
    Navigator.of(context).popUntil((route) => route.settings.name != 'player');

    unawaited(windowManager.hide());
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
        if (kDebugMode) debugPrint('app_links stream error: $e');
      },
    );
    _appLinks.getInitialLink().then((uri) {
      if (uri != null && mounted) {
        _handleUri(uri);
      }
    }).catchError((Object e) {
      if (kDebugMode) debugPrint('getInitialLink error: $e');
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
      }).catchError((Object _) {
        /* not a file path, ignore */
      });
    }
  }

  /// Ignore updates on mobile devices & depending on user prefs
  _checkForUpdate() async {
    if (!isDesktop()) return;
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
        },
      );
    });
  }

  _openAddTorrentDialog(
    String? initialMagnetLink,
    String? initialContentPath,
  ) async {
    if (!await checkAndRequestStoragePermissions(context)) return;
    if (!mounted) return;

    unawaited(showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddTorrentDialog(
          initialMagnetLink: initialMagnetLink,
          initialContentPath: initialContentPath,
        );
      },
    ));
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
          },
        );
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
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPopApp(context);
        if (shouldPop && context.mounted) {
          await Provider.of<AppModel>(context, listen: false).quitGracefully();
        }
      },
      child: AdaptiveNavigation(child: widget.child),
    );
  }
}

Future<bool> _onWillPopApp(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => const ConfirmExit(),
      ) ??
      false;
}
