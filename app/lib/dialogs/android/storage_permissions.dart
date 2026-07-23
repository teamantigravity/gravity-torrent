import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gravity_torrent/utils/device.dart';

class StoragePermissionDialog extends StatelessWidget {
  final bool isPermanentlyDenied;

  const StoragePermissionDialog({super.key, required this.isPermanentlyDenied});

  _requestPermission(BuildContext context) async {
    if (isPermanentlyDenied) {
      openAppSettings();
    } else {
      final sdkVersion = await getAndroidSdkVersion();
      if (Platform.isAndroid && sdkVersion != null && sdkVersion > 29) {
        await Permission.manageExternalStorage.request();
      } else {
        await Permission.storage.request();
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: const Text(
        'Gravity Torrent needs storage access to download files.',
      ),
      actions: [
        TextButton(
          onPressed: () => _requestPermission(context),
          child: Text(isPermanentlyDenied ? 'Open settings' : 'Continue'),
        ),
      ],
    );
  }
}
