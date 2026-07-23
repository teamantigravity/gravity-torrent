import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gravity_torrent/dialogs/add_torrent.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/haptic_service.dart';
import 'package:gravity_torrent/ui/adaptive/breakpoints.dart';
import 'package:gravity_torrent/utils/permissions.dart';

class AddTorrentButton extends StatelessWidget {
  const AddTorrentButton({super.key});

  _handleClick(BuildContext context) async {
    HapticService.medium();
    if (!await checkAndRequestStoragePermissions(context)) return;

    if (context.mounted) {
      AdServiceProvider.instance.showInterstitialIfReady();
      unawaited(showDialog(
        context: context,
        builder: (BuildContext context) {
          return const AddTorrentDialog();
        },
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF4285F4),
      foregroundColor: Colors.white,
      onPressed: () => _handleClick(context),
      tooltip: 'Pick a Torrent',
      shape:
          AdaptiveBreakpoints.isCompact(context) ? const CircleBorder() : null,
      elevation: (AdaptiveBreakpoints.isCompact(context)) ? 0 : null,
      child: const Icon(Icons.add),
    );
  }
}
