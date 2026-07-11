import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gravity_torrent/dialogs/android/storage_permissions.dart';
import 'package:gravity_torrent/utils/device.dart';

/// Checks if storage permissions are granted.
/// If not, requests them and shows the appropriate dialog.
/// Returns true if permissions are fully granted, false otherwise.
Future<bool> checkAndRequestStoragePermissions(BuildContext context) async {
  if (!Platform.isAndroid) return true;

  final sdkVersion = await getAndroidSdkVersion();

  if (sdkVersion <= 29) {
    if (await Permission.storage.isGranted) return true;

    var isPermanentlyDenied = await Permission.storage.isPermanentlyDenied;
    if (context.mounted) {
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return StoragePermissionDialog(
                isPermanentlyDenied: isPermanentlyDenied);
          });
    }
    return await Permission.storage.isGranted;
  } else {
    if (await Permission.manageExternalStorage.isGranted) return true;

    var isPermanentlyDenied =
        await Permission.manageExternalStorage.isPermanentlyDenied;
    if (context.mounted) {
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return StoragePermissionDialog(
                isPermanentlyDenied: isPermanentlyDenied);
          });
    }
    return await Permission.manageExternalStorage.isGranted;
  }
}
