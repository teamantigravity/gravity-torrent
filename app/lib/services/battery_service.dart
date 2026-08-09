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
  Timer? _levelTimer;
  bool _enabled = false;
  bool _loaded = false;
  bool _throttledByBattery = false;
  int _threshold = 20;

  bool _disposed = false;
  bool _checking = false;

  bool get isEnabled => _enabled;
  int get threshold => _threshold;
  bool get isThrottling => _throttledByBattery;

  Future<void> load() async {
    if (_disposed || _loaded) return;
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    if (_disposed) return;
    _threshold =
        (await SharedPrefsStorage.getString(
          _thresholdKey,
        ).then((s) => s != null ? int.tryParse(s) : null)) ??
        20;
    if (_disposed) return;
    _loaded = true;
    if (_enabled) _subscribe();
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed) return;
    _enabled = value;
    await SharedPrefsStorage.setBool(_enabledKey, value);
    if (_disposed) return;
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
    if (_disposed) return;
    _threshold = percent.clamp(5, 95);
    await SharedPrefsStorage.setString(_thresholdKey, _threshold.toString());
    if (_disposed) return;
    if (_enabled) await _checkBattery();
  }

  void _subscribe() {
    if (_disposed) return;
    _unsubscribe();
    _stateSub = _battery.onBatteryStateChanged.listen(
      (_) => unawaited(
        _checkBattery().catchError((Object e) {
          if (kDebugMode) debugPrint('BatteryService _checkBattery error: $e');
        }),
      ),
      onError: (e) {
        if (kDebugMode) debugPrint('BatteryService state stream error: $e');
      },
    );
    _levelTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(
        _checkBattery().catchError((Object e) {
          if (kDebugMode) debugPrint('BatteryService _checkBattery error: $e');
        }),
      );
    });
  }

  void _unsubscribe() {
    _stateSub?.cancel();
    _stateSub = null;
    _levelTimer?.cancel();
    _levelTimer = null;
  }

  Future<void> _checkBattery() async {
    if (_disposed || _checking || !_enabled) return;
    _checking = true;
    try {
      final level = await _battery.batteryLevel;
      if (_disposed) return;
      final state = await _battery.batteryState;
      if (_disposed) return;
      final isCharging =
          state == BatteryState.charging || state == BatteryState.full;

      if (isCharging) {
        if (_throttledByBattery) await _restoreNormalSpeed();
        return;
      }

      // On desktop/web the level can be -1 or otherwise invalid; skip throttle.
      if (level < 0 || level > 100) {
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
    } finally {
      _checking = false;
    }
  }

  Future<void> _enableThrottle() async {
    if (_disposed) return;
    try {
      if (!getIt.isRegistered<Engine>()) return;
      final engine = getIt<Engine>();
      // Enable the engine's built-in turtle (alt speed) mode.
      final session = await engine.fetchSession();
      if (_disposed) return;
      await session.update(SessionBase(altSpeedEnabled: true));
      _throttledByBattery = true;
      if (kDebugMode) {
        debugPrint('BatteryService: throttle enabled (battery low)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BatteryService _enableThrottle error: $e');
    }
  }

  Future<void> _restoreNormalSpeed() async {
    if (_disposed) return;
    try {
      if (!getIt.isRegistered<Engine>()) return;
      final engine = getIt<Engine>();
      final session = await engine.fetchSession();
      if (_disposed) return;

      // Unconditionally disable alt-speed. If the BandwidthHeatmapService has
      // an active limit it will re-apply it within its next scheduled tick
      // (at most 1 minute), avoiding a circular import dependency.
      await session.update(SessionBase(altSpeedEnabled: false));
      _throttledByBattery = false;
      if (kDebugMode) {
        debugPrint('BatteryService: normal speed restored');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BatteryService _restoreNormalSpeed error: $e');
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unsubscribe();
  }
}
