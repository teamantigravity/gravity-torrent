import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity_torrent/navigation/app_shell_route.dart';
import 'package:gravity_torrent/screens/settings/settings.dart';
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
                  key: state.pageKey, child: const TorrentsScreen());
            },
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) {
              return NoTransitionPage(
                  key: state.pageKey,
                  child: const Center(child: SettingsScreen()));
            },
          ),
        ])
  ],
);
