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
import 'package:gravity_torrent/dialogs/analytics_opt_in.dart';
import 'package:gravity_torrent/dialogs/whats_new.dart';
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
  bool isAnalyticsOptInDialogDisplayed = false;
  bool isWhatsNewDialogDisplayed = false;
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
      ConnectivityService.instance.start(context);
      initTray(context);
      _initAppLinks();
      _initShortcuts();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appModel = Provider.of<AppModel>(context);
    if (_appModel != appModel) {
      _appModel?.removeListener(_onAppModelChanged);
      _appModel = appModel;
      _appModel?.addListener(_onAppModelChanged);
      _onAppModelChanged();
    }
  }

  void _onAppModelChanged() {
    if (!mounted) return;
    final appModel = _appModel!;
    if (appModel.loaded && !_postLoadChecksDone) {
      if (!appModel.termsOfUseAccepted) {
        _openTermsOfUseDialog(appModel);
      } else if (!appModel.analyticsOptInDisplayed) {
        _openAnalyticsOptInDialog(appModel);
      } else if (appModel.shouldShowWhatsNew && !isWhatsNewDialogDisplayed) {
        _openWhatsNewDialog(appModel);
      } else {
        _postLoadChecksDone = true;
        _checkForUpdate();
      }
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
    ConnectivityService.instance.stop();
    windowManager.removeListener(this);
    _appModel?.removeListener(_onAppModelChanged);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
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
        if (!mounted) return;
        _handleUri(uri);
      },
      onError: (Object e) {
        if (kDebugMode) debugPrint('app_links stream error: $e');
      },
    );
    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null && mounted) {
            _handleUri(uri);
          }
        })
        .catchError((Object e) {
          if (kDebugMode) debugPrint('getInitialLink error: $e');
        });
  }

  void _handleUri(Uri uri) {
    final uriString = uri.toString();

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
      // Filesystem path — check synchronously (avoids async dart:io lint).
      if (File(uriString).existsSync() && mounted) {
        _openAddTorrentDialog(null, uriString);
      }
    }
  }

  /// Check for updates depending on user prefs
  _checkForUpdate() async {
    if (hasShownUpdateDialog) return;

    final appModel = Provider.of<AppModel>(context, listen: false);
    if (!appModel.checkForUpdate) return;

    final latestVersion = await checkForUpdate(appModel.version);
    if (latestVersion == null) return;
    if (!mounted) return;

    hasShownUpdateDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

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
    if (!mounted) return;
    if (!await checkAndRequestStoragePermissions(context)) return;
    if (!mounted) return;

    unawaited(
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AddTorrentDialog(
            initialMagnetLink: initialMagnetLink,
            initialContentPath: initialContentPath,
          );
        },
      ),
    );
  }

  _openTermsOfUseDialog(AppModel appModel) {
    final termsOfUseAccepted = appModel.termsOfUseAccepted;

    if (!isTermsOfUseDialogDisplayed && !termsOfUseAccepted) {
      // Avoid calling the dialog multiple times
      isTermsOfUseDialogDisplayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const TermsOfUseDialog();
            },
          ).then((_) {
            if (mounted) {
              isTermsOfUseDialogDisplayed = false;
              _onAppModelChanged(); // Trigger next check
            }
          }),
        );
      });
    }
  }

  _openAnalyticsOptInDialog(AppModel appModel) {
    final analyticsOptInDisplayed = appModel.analyticsOptInDisplayed;

    if (!isAnalyticsOptInDialogDisplayed && !analyticsOptInDisplayed) {
      // Avoid calling the dialog multiple times
      isAnalyticsOptInDialogDisplayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const AnalyticsOptInDialog();
            },
          ).then((_) {
            if (mounted) {
              isAnalyticsOptInDialogDisplayed = false;
              _onAppModelChanged(); // Trigger next check
            }
          }),
        );
      });
    }
  }

  _openWhatsNewDialog(AppModel appModel) {
    if (!isWhatsNewDialogDisplayed && appModel.shouldShowWhatsNew) {
      isWhatsNewDialogDisplayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return WhatsNewDialog(version: appModel.version);
            },
          ).then((_) async {
            if (mounted) {
              await appModel.markWhatsNewShown();
              isWhatsNewDialogDisplayed = false;
              _onAppModelChanged();
            }
          }),
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
