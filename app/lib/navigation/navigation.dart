import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity_torrent/navigation/add_torrent_button.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/haptic_service.dart';
import 'package:gravity_torrent/ui/adaptive/breakpoints.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';

class Destination {
  const Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<Destination> destinations = <Destination>[
  Destination(
    'Torrents',
    Icons.downloading,
    Icons.downloading,
  ),
  Destination(
    'Settings',
    Icons.settings,
    Icons.settings,
  ),
];

class Navigation extends StatefulWidget {
  const Navigation({super.key, required this.child});

  final Widget child;

  @override
  State<Navigation> createState() => _Navigation();
}

class _Navigation extends State<Navigation> {
  late bool showNavigationRail;

  @override
  void initState() {
    super.initState();
  }

  void _handleNavigationBarDestinationSelected(int selectedIndex) {
    HapticService.selection();
    if (selectedIndex == 0) {
      context.go('/torrents');
      AdServiceProvider.instance.showInterstitialIfReady();
    } else if (selectedIndex == 1) {
      context.go('/settings');
      AdServiceProvider.instance.showInterstitialIfReady();
    }
  }

  void _handleNavigationRailDestinationSelected(int selectedIndex) {
    HapticService.selection();
    if (selectedIndex == 0) {
      context.go('/torrents');
      AdServiceProvider.instance.showInterstitialIfReady();
    }

    if (selectedIndex == 1) {
      context.go('/settings');
      AdServiceProvider.instance.showInterstitialIfReady();
    }
  }

  static int _calculateNavigationRailSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    if (location == '/settings' || location.startsWith('/settings/')) {
      return 1;
    }

    // torrents
    return 0;
  }

  static int _calculateNavigationBarSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    if (location == '/settings' || location.startsWith('/settings/')) {
      return 1;
    }

    // torrents
    return 0;
  }

  bool _isTorrentsRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return location == '/torrents';
  }

  // Mobile Navigation
  Widget buildBottomBarScaffold(BuildContext context) {
    final isTorrents = _isTorrentsRoute(context);
    return Scaffold(
      appBar: isDesktop() ? const WindowTitleBar() : AppBar(toolbarHeight: 0),
      body: Column(
        children: [
          Expanded(child: widget.child),
          const Divider(thickness: 1, height: 1),
        ],
      ),
      floatingActionButton: isTorrents ? const AddTorrentButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: _calculateNavigationBarSelectedIndex(context),
        onDestinationSelected: _handleNavigationBarDestinationSelected,
        destinations: destinations.map((Destination destination) {
          final theme = Theme.of(context);
          return NavigationDestination(
            label: destination.label,
            icon: Icon(
              destination.icon,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              destination.selectedIcon,
              color: theme.colorScheme.primary,
            ),
            tooltip: destination.label,
          );
        }).toList(),
      ),
    );
  }

  // Desktop Navigation
  Widget buildNavigationRailScaffold(BuildContext context) {
    final isTorrents = _isTorrentsRoute(context);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(toolbarHeight: 0),
        body: Row(
          children: <Widget>[
            NavigationRail(
              leading: isTorrents
                  ? Padding(
                      padding: (!kIsWeb && Platform.isMacOS)
                          ? const EdgeInsets.only(
                              top: 20,
                              bottom: 4,
                              left: 4,
                              right: 4,
                            )
                          : const EdgeInsets.symmetric(vertical: 4),
                      child: const AddTorrentButton(),
                    )
                  : null,
              destinations: destinations.map((Destination destination) {
                final theme = Theme.of(context);
                return NavigationRailDestination(
                  label: Text(destination.label),
                  icon: Tooltip(
                    message: destination.label,
                    child: Icon(
                      destination.icon,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  selectedIcon: Tooltip(
                    message: destination.label,
                    child: Icon(
                      destination.selectedIcon,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              }).toList(),
              selectedIndex: _calculateNavigationRailSelectedIndex(context),
              useIndicator: true,
              onDestinationSelected: _handleNavigationRailDestinationSelected,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Column(
                children: [
                  if (isDesktop()) const WindowTitleBar(),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    showNavigationRail = AdaptiveBreakpoints.useNavigationRail(context);
  }

  @override
  Widget build(BuildContext context) {
    return showNavigationRail
        ? buildNavigationRailScaffold(context) // Desktop
        : buildBottomBarScaffold(context); // Mobile
  }
}
