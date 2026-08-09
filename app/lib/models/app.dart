import 'dart:async';
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
  String buildNumber = '';
  bool amoledBlack = false;
  bool analyticsOptInDisplayed = false;
  bool shouldShowWhatsNew = false;
  bool compactList = false;
  bool showTorrentLabels = true;
  bool showStatusFilterChips = true;
  bool showRecentSearchQueries = true;
  bool showLiveSpeedHeader = true;
  bool showVisibleTorrentCount = true;
  bool showTorrentHealthBadge = true;
  bool _disposed = false;

  AppModel() {
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
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
      amoledBlack =
          await SharedPrefsStorage.getBool('amoledBlack') ?? amoledBlack;
      analyticsOptInDisplayed =
          await SharedPrefsStorage.getBool('analyticsOptInDisplayed') ??
          analyticsOptInDisplayed;
      compactList =
          await SharedPrefsStorage.getBool('compactList') ?? compactList;
      showTorrentLabels =
          await SharedPrefsStorage.getBool('showTorrentLabels') ??
          showTorrentLabels;
      showStatusFilterChips =
          await SharedPrefsStorage.getBool('showStatusFilterChips') ??
          showStatusFilterChips;
      showRecentSearchQueries =
          await SharedPrefsStorage.getBool('showRecentSearchQueries') ??
          showRecentSearchQueries;
      showLiveSpeedHeader =
          await SharedPrefsStorage.getBool('showLiveSpeedHeader') ??
          showLiveSpeedHeader;
      showVisibleTorrentCount =
          await SharedPrefsStorage.getBool('showVisibleTorrentCount') ??
          showVisibleTorrentCount;
      showTorrentHealthBadge =
          await SharedPrefsStorage.getBool('showTorrentHealthBadge') ??
          showTorrentHealthBadge;

      // Load app version
      try {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        version = packageInfo.version;
        buildNumber = packageInfo.buildNumber;

        final previousVersion =
            await SharedPrefsStorage.getString('lastWhatsNewVersion') ?? '';
        if (previousVersion.isEmpty) {
          await SharedPrefsStorage.setString('lastWhatsNewVersion', version);
        } else if (previousVersion != version) {
          shouldShowWhatsNew = true;
        }
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

  Future<void> setTheme(ThemeMode value) async {
    theme = value;
    try {
      await SharedPrefsStorage.setString('theme', value.name);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist theme: $e');
    }
    _safeNotify();
  }

  Future<void> setAmoledBlack(bool value) async {
    amoledBlack = value;
    try {
      await SharedPrefsStorage.setBool('amoledBlack', value);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist amoledBlack: $e');
    }
    _safeNotify();
  }

  Future<void> setTermsOfUseAccepted(bool value) async {
    termsOfUseAccepted = value;
    try {
      await SharedPrefsStorage.setBool('termsOfUseAccepted', value);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist termsOfUseAccepted: $e');
    }
    _safeNotify();
  }

  Future<void> setAnalyticsOptInDisplayed(bool value) async {
    analyticsOptInDisplayed = value;
    try {
      await SharedPrefsStorage.setBool('analyticsOptInDisplayed', value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist analyticsOptInDisplayed: $e');
      }
    }
    _safeNotify();
  }

  Future<void> markWhatsNewShown() async {
    shouldShowWhatsNew = false;
    try {
      await SharedPrefsStorage.setString('lastWhatsNewVersion', version);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist lastWhatsNewVersion: $e');
    }
    _safeNotify();
  }

  Future<void> setCompactList(bool value) async {
    compactList = value;
    try {
      await SharedPrefsStorage.setBool('compactList', value);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist compactList: $e');
    }
    _safeNotify();
  }

  Future<void> setShowTorrentLabels(bool value) async {
    showTorrentLabels = value;
    try {
      await SharedPrefsStorage.setBool('showTorrentLabels', value);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist showTorrentLabels: $e');
    }
    _safeNotify();
  }

  Future<void> setShowStatusFilterChips(bool value) async {
    showStatusFilterChips = value;
    try {
      await SharedPrefsStorage.setBool('showStatusFilterChips', value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist showStatusFilterChips: $e');
      }
    }
    _safeNotify();
  }

  Future<void> setShowRecentSearchQueries(bool value) async {
    showRecentSearchQueries = value;
    try {
      await SharedPrefsStorage.setBool('showRecentSearchQueries', value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist showRecentSearchQueries: $e');
      }
    }
    _safeNotify();
  }

  Future<void> setShowLiveSpeedHeader(bool value) async {
    showLiveSpeedHeader = value;
    try {
      await SharedPrefsStorage.setBool('showLiveSpeedHeader', value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist showLiveSpeedHeader: $e');
      }
    }
    _safeNotify();
  }

  Future<void> setShowVisibleTorrentCount(bool value) async {
    showVisibleTorrentCount = value;
    try {
      await SharedPrefsStorage.setBool('showVisibleTorrentCount', value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist showVisibleTorrentCount: $e');
      }
    }
    _safeNotify();
  }

  Future<void> setShowTorrentHealthBadge(bool value) async {
    showTorrentHealthBadge = value;
    try {
      await SharedPrefsStorage.setBool('showTorrentHealthBadge', value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist showTorrentHealthBadge: $e');
      }
    }
    _safeNotify();
  }

  Future<void> setCheckForUpdate(bool value) async {
    checkForUpdate = value;
    try {
      await SharedPrefsStorage.setBool('checkForUpdate', value);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist checkForUpdate: $e');
    }
    _safeNotify();
  }

  void setQuitting(bool value) {
    quitting = value;
    _safeNotify();
  }

  Future<void> setLocale(String value) async {
    locale = value;
    try {
      await SharedPrefsStorage.setString('locale', value);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to persist locale: $e');
    }
    _safeNotify();
  }

  Future<void> quitGracefully() async {
    try {
      await stopServices();
    } catch (e) {
      if (kDebugMode) debugPrint('quitGracefully stopServices error: $e');
    }
    try {
      await engine.shutdown();
    } catch (e) {
      if (kDebugMode) debugPrint('quitGracefully shutdown error: $e');
    } finally {
      await quit();
    }
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
      if (!kIsWeb && Platform.isAndroid) {
        await stopForegroundService();
      }
      await SystemNavigator.pop();
    }
  }
}
