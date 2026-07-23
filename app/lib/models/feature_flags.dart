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

/// Feature toggles used by the app and remote-config kill-switch.
enum Feature {
  useDynamicColor,
  useEnhancedNotifications,
  usePipBackgroundAudio,
  enableRemoteControl,
  enableAnalytics,
  enableAppLock,
  enableShortcuts,
  enableHaptic,
  enableScheduler,
  enableQuota,
  enableRssAutoDownload,
  enableWifiOnly,
  enableBatterySaver,
}

const _featureDefaults = <Feature, bool>{
  Feature.useDynamicColor: true,
  Feature.useEnhancedNotifications: true,
  Feature.usePipBackgroundAudio: true,
  Feature.enableRemoteControl: false,
  Feature.enableAnalytics: false,
  Feature.enableAppLock: false,
  Feature.enableShortcuts: false,
  Feature.enableHaptic: false,
  Feature.enableScheduler: false,
  Feature.enableQuota: false,
  Feature.enableRssAutoDownload: false,
  Feature.enableWifiOnly: false,
  Feature.enableBatterySaver: false,
};

/// Persistent, user-controllable feature flags for SOTA cross-platform
/// features, combined with a remote kill-switch from [RemoteConfigService].
///
/// Public getters return the *effective* state (local preference AND remote
/// config). Setters update the local preference only. When the remote config
/// disables a feature, the effective state becomes `false` regardless of the
/// local toggle. This lets new features be rolled back in an emergency.
class FeatureFlagsModel extends ChangeNotifier {
  bool loaded = false;
  bool _disposed = false;
  late final Future<void> _initialization;
  final Map<Feature, bool> _values = {};

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

  bool isEnabled(Feature feature) =>
      (_values[feature] ?? _featureDefaults[feature]!) &&
      RemoteConfigService.instance.isFeatureEnabled(feature.name);

  bool get useDynamicColor => isEnabled(Feature.useDynamicColor);
  bool get useEnhancedNotifications =>
      isEnabled(Feature.useEnhancedNotifications);
  bool get usePipBackgroundAudio => isEnabled(Feature.usePipBackgroundAudio);
  bool get enableRemoteControl => isEnabled(Feature.enableRemoteControl);
  bool get enableAnalytics => isEnabled(Feature.enableAnalytics);
  bool get enableAppLock => isEnabled(Feature.enableAppLock);
  bool get enableShortcuts => isEnabled(Feature.enableShortcuts);
  bool get enableHaptic => isEnabled(Feature.enableHaptic);
  bool get enableScheduler => isEnabled(Feature.enableScheduler);
  bool get enableQuota => isEnabled(Feature.enableQuota);
  bool get enableRssAutoDownload => isEnabled(Feature.enableRssAutoDownload);
  bool get enableWifiOnly => isEnabled(Feature.enableWifiOnly);
  bool get enableBatterySaver => isEnabled(Feature.enableBatterySaver);

  /// True when the remote config explicitly disables this feature.
  bool isRemotelyDisabled(String key) =>
      RemoteConfigService.instance.featureFlags.containsKey(key) &&
      RemoteConfigService.instance.featureFlags[key] == false;

  Future<void> _load() async {
    try {
      for (final feature in Feature.values) {
        _values[feature] = await SharedPrefsStorage.getBool(feature.name) ??
            _featureDefaults[feature]!;
      }

      try {
        await RemoteConfigService.instance.refresh();
      } catch (e) {
        if (kDebugMode) debugPrint('RemoteConfigService refresh failed: $e');
      }

      HapticService.setEnabled(enableHaptic);
      try {
        await AppLockService.instance.setEnabled(enableAppLock);
      } catch (e, st) {
        if (kDebugMode) debugPrint('AppLockService sync failed: $e\n$st');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FeatureFlagsModel._load error: $e');
    } finally {
      loaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _persist(Feature feature, bool value) async {
    _values[feature] = value;
    await SharedPrefsStorage.setBool(feature.name, value);
  }

  /// Effective boolean helper used by setters so service calls honour the
  /// remote kill-switch even when the user toggles the local preference.
  bool _effective(Feature feature, bool localValue) =>
      RemoteConfigService.instance.isFeatureEnabled(
        feature.name,
        defaultValue: localValue,
      );

  Future<void> setUseDynamicColor(bool value) async {
    await _persist(Feature.useDynamicColor, value);
    if (!_disposed) notifyListeners();
  }

  Future<void> setUseEnhancedNotifications(bool value) async {
    await _persist(Feature.useEnhancedNotifications, value);
    if (!_disposed) notifyListeners();
  }

  Future<void> setUsePipBackgroundAudio(bool value) async {
    await _persist(Feature.usePipBackgroundAudio, value);
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnableRemoteControl(bool value) async {
    await _persist(Feature.enableRemoteControl, value);
    if (!_disposed) notifyListeners();
    unawaited(
      RemoteControlService.instance
          .setEnabled(_effective(Feature.enableRemoteControl, value))
          .catchError((e) {
        if (kDebugMode) debugPrint('RemoteControlService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableAnalytics(bool value) async {
    await _persist(Feature.enableAnalytics, value);
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnableAppLock(bool value) async {
    await _persist(Feature.enableAppLock, value);
    try {
      await AppLockService.instance
          .setEnabled(_effective(Feature.enableAppLock, value));
    } catch (e, st) {
      if (kDebugMode) debugPrint('AppLockService toggle failed: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnableShortcuts(bool value) async {
    await _persist(Feature.enableShortcuts, value);
    if (!_disposed) notifyListeners();
    ShortcutsService.setEnabled(_effective(Feature.enableShortcuts, value));
  }

  Future<void> setEnableHaptic(bool value) async {
    await _persist(Feature.enableHaptic, value);
    if (!_disposed) notifyListeners();
    HapticService.setEnabled(_effective(Feature.enableHaptic, value));
  }

  Future<void> setEnableScheduler(bool value) async {
    await _persist(Feature.enableScheduler, value);
    if (!_disposed) notifyListeners();
    unawaited(
      SchedulerService.instance
          .setEnabled(_effective(Feature.enableScheduler, value))
          .catchError((e) {
        if (kDebugMode) debugPrint('SchedulerService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableQuota(bool value) async {
    await _persist(Feature.enableQuota, value);
    if (!_disposed) notifyListeners();
    unawaited(
      QuotaService.instance
          .setEnabled(_effective(Feature.enableQuota, value))
          .catchError((e) {
        if (kDebugMode) debugPrint('QuotaService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableRssAutoDownload(bool value) async {
    await _persist(Feature.enableRssAutoDownload, value);
    if (!_disposed) notifyListeners();
    unawaited(
      RssService.instance
          .setEnabled(_effective(Feature.enableRssAutoDownload, value))
          .catchError((e) {
        if (kDebugMode) debugPrint('RssService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableWifiOnly(bool value) async {
    await _persist(Feature.enableWifiOnly, value);
    if (!_disposed) notifyListeners();
    unawaited(
      WifiGuardService.instance
          .setEnabled(_effective(Feature.enableWifiOnly, value))
          .catchError((e) {
        if (kDebugMode) debugPrint('WifiGuardService toggle failed: $e');
        return null;
      }),
    );
  }

  Future<void> setEnableBatterySaver(bool value) async {
    await _persist(Feature.enableBatterySaver, value);
    if (!_disposed) notifyListeners();
    unawaited(
      BatteryService.instance
          .setEnabled(_effective(Feature.enableBatterySaver, value))
          .catchError((e) {
        if (kDebugMode) debugPrint('BatteryService toggle failed: $e');
        return null;
      }),
    );
  }
}
