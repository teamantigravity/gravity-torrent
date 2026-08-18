import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/utils/device.dart';

class StoragePermissionDialog extends StatelessWidget {
  final bool isPermanentlyDenied;

  const StoragePermissionDialog({super.key, required this.isPermanentlyDenied});

  Future<void> _requestPermission(BuildContext context) async {
    try {
      if (isPermanentlyDenied) {
        await openAppSettings();
      } else {
        final sdkVersion = await getAndroidSdkVersion();
        if (Platform.isAndroid && sdkVersion != null && sdkVersion > 29) {
          await Permission.manageExternalStorage.request();
        } else {
          await Permission.storage.request();
        }
      }
    } catch (e, st) {
      debugPrint('Permission request failed: $e\n$st');
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(localizations.storagePermissionTitle),
      content: Text(
        isPermanentlyDenied
            ? localizations.storagePermissionPermanentlyDenied
            : localizations.storagePermissionRationale,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.cancel),
        ),
        TextButton(
          onPressed: () => _requestPermission(context),
          child: Text(localizations.grant),
        ),
      ],
    );
  }
}
