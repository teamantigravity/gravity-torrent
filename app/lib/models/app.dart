import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gravity_torrent/main.dart';
import 'package:gravity_torrent/platforms/android/foreground_service.dart';
import 'package:gravity_torrent/platforms/desktop/tray.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:window_manager/window_manager.dart';

class AppModel extends ChangeNotifier {
  ThemeMode theme = ThemeMode.system;
  bool termsOfUseAccepted = false;
  bool checkForUpdate = true;
  bool loaded = false;
  bool quitting = false;
  String locale = 'en';
  String version = '';
  bool amoledBlack = false;
  bool _disposed = false;

  AppModel() {
    _loadSettings();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      // Load theme
      final themeName =
          await SharedPrefsStorage.getString('theme') ?? ThemeMode.system.name;
      theme = ThemeMode.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ThemeMode.system,
      );
      // Load terms of use status
      termsOfUseAccepted =
          await SharedPrefsStorage.getBool('termsOfUseAccepted') ??
              termsOfUseAccepted;
      // Load check for update value
      checkForUpdate =
          await SharedPrefsStorage.getBool('checkForUpdate') ?? checkForUpdate;
      locale = await SharedPrefsStorage.getString('locale') ?? locale;
      amoledBlack = await SharedPrefsStorage.getBool('amoledBlack') ?? amoledBlack;

      // Load app version
      try {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        version = packageInfo.version;
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to get package info: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AppModel._loadSettings error: $e');
    } finally {
      loaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  void setTheme(ThemeMode value) async {
    theme = value;
    notifyListeners();
    await SharedPrefsStorage.setString('theme', value.name);
  }

  void setAmoledBlack(bool value) async {
    amoledBlack = value;
    notifyListeners();
    await SharedPrefsStorage.setBool('amoledBlack', value);
  }

  void setTermsOfUseAccepted(bool value) async {
    termsOfUseAccepted = value;
    notifyListeners();
    await SharedPrefsStorage.setBool('termsOfUseAccepted', value);
  }

  void setCheckForUpdate(bool value) async {
    checkForUpdate = value;
    notifyListeners();
    await SharedPrefsStorage.setBool('checkForUpdate', value);
  }

  void setQuitting(bool value) {
    quitting = value;
    notifyListeners();
  }

  void setLocale(String value) async {
    locale = value;
    notifyListeners();
    await SharedPrefsStorage.setString('locale', value);
  }

  Future<void> quitGracefully() async {
    await stopServices();
    await engine.shutdown();
    await quit();
  }

  Future<void> quit() async {
    if (isDesktop()) {
      await closeTray();
      // See https://github.com/leanflutter/window_manager/issues/478
      // calling only close seems to crash the app on macos,
      // meanwhile calling destroy crashes on windows.
      if (Platform.isWindows) {
        await windowManager.setPreventClose(false);
        await windowManager.close();
      } else {
        await windowManager.destroy();
      }
    } else {
      if (Platform.isAndroid) {
        await stopForegroundService();
      }
      await SystemNavigator.pop();
    }
  }
}
