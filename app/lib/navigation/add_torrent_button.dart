import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gravity_torrent/dialogs/add_torrent.dart';
import 'package:gravity_torrent/dialogs/android/storage_permissions.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/utils/device.dart';

class AddTorrentButton extends StatelessWidget {
  const AddTorrentButton({super.key});

  _handleClick(BuildContext context) async {
    if (Platform.isAndroid) {
      final sdkVersion = await getAndroidSdkVersion();
      if (sdkVersion <= 29 && await Permission.storage.isGranted == false) {
        var isPermanentlyDenied = await Permission.storage.isPermanentlyDenied;
        if (context.mounted) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return StoragePermissionDialog(
                    isPermanentlyDenied: isPermanentlyDenied);
              });
        }
        return;
      } else if (sdkVersion > 29 &&
          await Permission.manageExternalStorage.isGranted == false) {
        var isPermanentlyDenied =
            await Permission.manageExternalStorage.isPermanentlyDenied;
        if (context.mounted) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return StoragePermissionDialog(
                    isPermanentlyDenied: isPermanentlyDenied);
              });
        }
        return;
      }
    }

    if (context.mounted) {
      AdServiceProvider.instance.showInterstitialIfReady();
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return const AddTorrentDialog();
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF4285F4),
      foregroundColor: Colors.white,
      onPressed: () => _handleClick(context),
      tooltip: 'Pick a Torrent',
      shape: isMobileSize(context) ? const CircleBorder() : null,
      elevation: (isMobileSize(context)) ? 0 : null,
      child: const Icon(Icons.add),
    );
  }
}
