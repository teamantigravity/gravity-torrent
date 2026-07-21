import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Automatically throttles downloads (enables turtle/alt-speed mode) when
/// battery level drops below [threshold] percent and the device is not charging.
///
/// When the device starts charging OR battery recovers above [threshold] + 5%
/// hysteresis, normal speeds are restored.
class BatteryService {
  BatteryService._();
  static final BatteryService instance = BatteryService._();

  static const _enabledKey = 'gravity_torrent_battery_saver_enabled';
  static const _thresholdKey = 'gravity_torrent_battery_saver_threshold';

  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _stateSub;
  bool _enabled = false;
  bool _loaded = false;
  bool _throttledByBattery = false;
  int _threshold = 20;

  bool get isEnabled => _enabled;
  int get threshold => _threshold;
  bool get isThrottling => _throttledByBattery;

  Future<void> load() async {
    if (_loaded) return;
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    _threshold = (await SharedPrefsStorage.getString(_thresholdKey)
                .then((s) => s != null ? int.tryParse(s) : null)) ??
        20;
    _loaded = true;
    if (_enabled) _subscribe();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await SharedPrefsStorage.setBool(_enabledKey, value);
    if (value) {
      _subscribe();
      // Check immediately on enable
      await _checkBattery();
    } else {
      _unsubscribe();
      if (_throttledByBattery) {
        await _restoreNormalSpeed();
      }
    }
  }

  Future<void> setThreshold(int percent) async {
    _threshold = percent.clamp(5, 95);
    await SharedPrefsStorage.setString(_thresholdKey, _threshold.toString());
    if (_enabled) await _checkBattery();
  }

  void _subscribe() {
    _unsubscribe();
    _stateSub = _battery.onBatteryStateChanged.listen(
      (_) async => _checkBattery(),
      onError: (e) {
        if (kDebugMode) debugPrint('BatteryService state stream error: $e');
      },
    );
  }

  void _unsubscribe() {
    _stateSub?.cancel();
    _stateSub = null;
  }

  Future<void> _checkBattery() async {
    if (!_enabled) return;
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final isCharging = state == BatteryState.charging ||
          state == BatteryState.full;

      if (isCharging) {
        if (_throttledByBattery) await _restoreNormalSpeed();
        return;
      }

      if (!_throttledByBattery && level <= _threshold) {
        // Battery dropped below threshold — enable throttle.
        await _enableThrottle();
      } else if (_throttledByBattery && level > _threshold + 5) {
        // Battery recovered past hysteresis — restore.
        await _restoreNormalSpeed();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BatteryService _checkBattery error: $e');
    }
  }

  Future<void> _enableThrottle() async {
    try {
      final engine = getIt<Engine>();
      // Enable the engine's built-in turtle (alt speed) mode.
      final session = await engine.fetchSession();
      await session.update(SessionBase(altSpeedEnabled: true));
      _throttledByBattery = true;
      if (kDebugMode) {
        debugPrint(
          'BatteryService: throttle enabled (battery low)',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BatteryService _enableThrottle error: $e');
    }
  }

  Future<void> _restoreNormalSpeed() async {
    try {
      final engine = getIt<Engine>();
      final session = await engine.fetchSession();
      await session.update(SessionBase(altSpeedEnabled: false));
      _throttledByBattery = false;
      if (kDebugMode) {
        debugPrint(
          'BatteryService: normal speed restored',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BatteryService _restoreNormalSpeed error: $e');
    }
  }

  void dispose() {
    _unsubscribe();
  }
}
