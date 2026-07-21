import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';
import 'package:gravity_torrent/services/haptic_service.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:gravity_torrent/services/remote_control_service.dart';
import 'package:gravity_torrent/services/rss_service.dart';
import 'package:gravity_torrent/services/scheduler_service.dart';
import 'package:gravity_torrent/services/shortcuts_service.dart';
import 'package:gravity_torrent/services/wifi_guard_service.dart';
import 'package:gravity_torrent/services/battery_service.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Persistent, user-controllable feature flags for SOTA cross-platform
/// features, combined with a remote kill-switch from [RemoteConfigService].
///
/// Public getters return the *effective* state (local preference AND remote
/// config). Setters update the local preference only. When the remote config
/// disables a feature, the effective state becomes `false` regardless of the
/// local toggle. This lets new features be rolled back in an emergency.
class FeatureFlagsModel extends ChangeNotifier {
  bool _useDynamicColor = true;
  bool _useEnhancedNotifications = true;
  bool _usePipBackgroundAudio = true;
  bool _enableRemoteControl = false;
  bool _enableAnalytics = false;
  bool _enableAppLock = false;
  bool _enableShortcuts = false;
  bool _enableHaptic = false;
  bool _enableScheduler = false;
  bool _enableQuota = false;
  bool _enableRssAutoDownload = false;
  bool _enableWifiOnly = false;
  bool _enableBatterySaver = false;
  bool loaded = false;
  bool _disposed = false;
  late final Future<void> _initialization;

  FeatureFlagsModel() {
    _initialization = _load();
  }

  /// A future that completes when the initial local prefs and remote config have
  /// been loaded. Callers (e.g. [main]) can await this before starting services.
  Future<void> get initialization => _initialization;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _isEnabled(String key, bool localValue) =>
      localValue && RemoteConfigService.instance.isFeatureEnabled(key);

  bool get useDynamicColor => _isEnabled('useDynamicColor', _useDynamicColor);
  bool get useEnhancedNotifications =>
      _isEnabled('useEnhancedNotifications', _useEnhancedNotifications);
  bool get usePipBackgroundAudio =>
      _isEnabled('usePipBackgroundAudio', _usePipBackgroundAudio);
  bool get enableRemoteControl =>
      _isEnabled('enableRemoteControl', _enableRemoteControl);
  bool get enableAnalytics => _isEnabled('enableAnalytics', _enableAnalytics);
  bool get enableAppLock => _isEnabled('enableAppLock', _enableAppLock);
  bool get enableShortcuts => _isEnabled('enableShortcuts', _enableShortcuts);
  bool get enableHaptic => _isEnabled('enableHaptic', _enableHaptic);
  bool get enableScheduler => _isEnabled('enableScheduler', _enableScheduler);
  bool get enableQuota => _isEnabled('enableQuota', _enableQuota);
  bool get enableRssAutoDownload =>
      _isEnabled('enableRssAutoDownload', _enableRssAutoDownload);
  bool get enableWifiOnly => _isEnabled('enableWifiOnly', _enableWifiOnly);
  bool get enableBatterySaver =>
      _isEnabled('enableBatterySaver', _enableBatterySaver);

  /// True when the remote config explicitly disables this feature.
  bool isRemotelyDisabled(String key) =>
      RemoteConfigService.instance.featureFlags.containsKey(key) &&
      RemoteConfigService.instance.featureFlags[key] == false;

  Future<void> _load() async {
    _useDynamicColor =
        await SharedPrefsStorage.getBool('useDynamicColor') ?? true;
    _useEnhancedNotifications =
        await SharedPrefsStorage.getBool('useEnhancedNotifications') ?? true;
    _usePipBackgroundAudio =
        await SharedPrefsStorage.getBool('usePipBackgroundAudio') ?? true;
    _enableRemoteControl =
        await SharedPrefsStorage.getBool('enableRemoteControl') ?? false;
    _enableAnalytics =
        await SharedPrefsStorage.getBool('enableAnalytics') ?? false;
    _enableAppLock = await SharedPrefsStorage.getBool('enableAppLock') ?? false;
    _enableShortcuts =
        await SharedPrefsStorage.getBool('enableShortcuts') ?? false;
    _enableHaptic = await SharedPrefsStorage.getBool('enableHaptic') ?? false;
    _enableScheduler =
        await SharedPrefsStorage.getBool('enableScheduler') ?? false;
    _enableQuota = await SharedPrefsStorage.getBool('enableQuota') ?? false;
    _enableRssAutoDownload =
        await SharedPrefsStorage.getBool('enableRssAutoDownload') ?? false;
    _enableWifiOnly =
        await SharedPrefsStorage.getBool('enableWifiOnly') ?? false;
    _enableBatterySaver =
        await SharedPrefsStorage.getBool('enableBatterySaver') ?? false;

    await RemoteConfigService.instance.refresh();
    HapticService.setEnabled(enableHaptic);
    unawaited(
      AppLockService.instance.setEnabled(enableAppLock).catchError((e) {
        if (kDebugMode) debugPrint('AppLockService sync failed: $e');
        return null;
      }),
    );
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> setUseDynamicColor(bool value) async {
    _useDynamicColor = value;
    await SharedPrefsStorage.setBool('useDynamicColor', value);
    if (!_disposed) notifyListeners();
  }

  Future<void> setUseEnhancedNotifications(bool value) async {
    _useEnhancedNotifications = value;
    await SharedPrefsStorage.setBool('useEnhancedNotifications', value);
    if (!_disposed) notifyListeners();
  }

  Future<void> setUsePipBackgroundAudio(bool value) async {
    _usePipBackgroundAudio = value;
    await SharedPrefsStorage.setBool('usePipBackgroundAudio', value);
    if (!_disposed) notifyListeners();
  }

  /// Effective boolean helper used by setters so service calls honour the
  /// remote kill-switch even when the user toggles the local preference.
  bool _effective(String key, bool localValue) => RemoteConfigService.instance
      .isFeatureEnabled(key, defaultValue: localValue);

  Future<void> setEnableRemoteControl(bool value) async {
    _enableRemoteControl = value;
    await SharedPrefsStorage.setBool('enableRemoteControl', value);
    if (!_disposed) notifyListeners();
    unawaited(
      RemoteControlService.instance
          .setEnabled(_effective('enableRemoteControl', value))
          .catchError((e) {
        if (kDebugMode) debugPrint('RemoteControlService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableAnalytics(bool value) async {
    _enableAnalytics = value;
    await SharedPrefsStorage.setBool('enableAnalytics', value);
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnableAppLock(bool value) async {
    _enableAppLock = value;
    await SharedPrefsStorage.setBool('enableAppLock', value);
    if (!_disposed) notifyListeners();
    unawaited(
      AppLockService.instance
          .setEnabled(_effective('enableAppLock', value))
          .catchError((e) {
        if (kDebugMode) debugPrint('AppLockService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableShortcuts(bool value) async {
    _enableShortcuts = value;
    await SharedPrefsStorage.setBool('enableShortcuts', value);
    if (!_disposed) notifyListeners();
    ShortcutsService.setEnabled(_effective('enableShortcuts', value));
  }

  Future<void> setEnableHaptic(bool value) async {
    _enableHaptic = value;
    await SharedPrefsStorage.setBool('enableHaptic', value);
    if (!_disposed) notifyListeners();
    HapticService.setEnabled(_effective('enableHaptic', value));
  }

  Future<void> setEnableScheduler(bool value) async {
    _enableScheduler = value;
    await SharedPrefsStorage.setBool('enableScheduler', value);
    if (!_disposed) notifyListeners();
    unawaited(
      SchedulerService.instance
          .setEnabled(_effective('enableScheduler', value))
          .catchError((e) {
        if (kDebugMode) debugPrint('SchedulerService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableQuota(bool value) async {
    _enableQuota = value;
    await SharedPrefsStorage.setBool('enableQuota', value);
    if (!_disposed) notifyListeners();
    unawaited(
      QuotaService.instance
          .setEnabled(_effective('enableQuota', value))
          .catchError((e) {
        if (kDebugMode) debugPrint('QuotaService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableRssAutoDownload(bool value) async {
    _enableRssAutoDownload = value;
    await SharedPrefsStorage.setBool('enableRssAutoDownload', value);
    if (!_disposed) notifyListeners();
    unawaited(
      RssService.instance
          .setEnabled(_effective('enableRssAutoDownload', value))
          .catchError((e) {
        if (kDebugMode) debugPrint('RssService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableWifiOnly(bool value) async {
    _enableWifiOnly = value;
    await SharedPrefsStorage.setBool('enableWifiOnly', value);
    if (!_disposed) notifyListeners();
    unawaited(
      WifiGuardService.instance
          .setEnabled(_effective('enableWifiOnly', value))
          .catchError((e) {
        if (kDebugMode) debugPrint('WifiGuardService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableBatterySaver(bool value) async {
    _enableBatterySaver = value;
    await SharedPrefsStorage.setBool('enableBatterySaver', value);
    if (!_disposed) notifyListeners();
    unawaited(
      BatteryService.instance
          .setEnabled(_effective('enableBatterySaver', value))
          .catchError((e) {
        if (kDebugMode) debugPrint('BatteryService toggle failed: $e');
        return null;
      }),
    );
  }
}
