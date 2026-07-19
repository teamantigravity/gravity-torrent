import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity_torrent/navigation/app_shell_route.dart';
import 'package:gravity_torrent/screens/settings/settings.dart';
import 'package:gravity_torrent/screens/sota/analytics_screen.dart';
import 'package:gravity_torrent/screens/sota/privacy_vault_screen.dart';
import 'package:gravity_torrent/screens/sota/quota_screen.dart';
import 'package:gravity_torrent/screens/sota/remote_control_screen.dart';
import 'package:gravity_torrent/screens/sota/rss_screen.dart';
import 'package:gravity_torrent/screens/sota/scheduler_screen.dart';
import 'package:gravity_torrent/screens/settings/upgrade_page.dart';
import 'package:gravity_torrent/screens/torrents/torrents.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/torrents',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShellRoute(child: child),
      routes: [
        GoRoute(
          path: '/torrents',
          pageBuilder: (context, state) {
            return NoTransitionPage(
              key: state.pageKey,
              child: const TorrentsScreen(),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) {
            return NoTransitionPage(
              key: state.pageKey,
              child: const Center(child: SettingsScreen()),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/remote-control',
      builder: (context, state) => const RemoteControlScreen(),
    ),
    GoRoute(
      path: '/scheduler',
      builder: (context, state) => const SchedulerScreen(),
    ),
    GoRoute(
      path: '/quota',
      builder: (context, state) => const QuotaScreen(),
    ),
    GoRoute(
      path: '/rss',
      builder: (context, state) => const RssScreen(),
    ),
    GoRoute(
      path: '/privacy-vault',
      builder: (context, state) => const PrivacyVaultScreen(),
    ),
    GoRoute(
      path: '/upgrade',
      builder: (context, state) => const UpgradePage(),
    ),
  ],
);
