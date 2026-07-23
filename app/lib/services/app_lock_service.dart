import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:gravity_torrent/services/pin_service.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Privacy vault / app lock service.
///
/// Uses biometric auth when the device supports it, falling back to a numeric PIN.
/// On unsupported platforms (web, Linux, or devices without biometrics), the PIN
/// is used instead.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _enabledKey = 'gravity_torrent_app_lock_enabled';
  static const _useBiometricsKey = 'gravity_torrent_app_lock_use_biometrics';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _enabled = false;
  bool _useBiometrics = true;

  bool get enabled => _enabled;
  bool get useBiometrics => _useBiometrics;
  bool get hasPin => PinService.instance.hasPin;

  Future<void> load() async {
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    _useBiometrics =
        await SharedPrefsStorage.getBool(_useBiometricsKey) ?? true;
    await PinService.instance.load();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await SharedPrefsStorage.setBool(_enabledKey, value);
  }

  Future<void> setPin(String pin) async {
    await PinService.instance.setPin(pin);
  }

  Future<void> clearPin() async {
    await PinService.instance.clearPin();
  }

  Future<void> setUseBiometrics(bool value) async {
    _useBiometrics = value;
    await SharedPrefsStorage.setBool(_useBiometricsKey, value);
  }

  /// Returns true when the device has enrolled biometrics (or Windows Hello).
  Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on LocalAuthException catch (e) {
      if (kDebugMode) debugPrint('AppLockService biometrics not available: $e');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('AppLockService canUseBiometrics error: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;
    try {
      // Windows Hello does not support the biometricOnly flag.
      final biometricOnly = defaultTargetPlatform != TargetPlatform.windows;
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Gravity Torrent',
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on LocalAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('AppLockService biometric auth error: ${e.code}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('AppLockService biometric auth exception: $e');
      return false;
    }
  }

  /// Stops an in-progress biometric authentication prompt.
  Future<void> stopBiometricAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      if (kDebugMode) debugPrint('AppLockService stop biometric failed: $e');
    }
  }

  Future<bool> authenticateWithPin(String pin) async {
    try {
      return await PinService.instance.verifyPin(pin);
    } on PinLockoutException catch (e) {
      if (kDebugMode) debugPrint('AppLockService: $e');
      return false;
    }
  }

  /// Attempts biometric authentication, then PIN authentication if a PIN is set.
  /// Returns true if either succeeds or if app lock is disabled.
  Future<bool> authenticate({String? pin}) async {
    if (!_enabled) return true;

    if (_useBiometrics) {
      final biometricsAvailable = await canUseBiometrics();
      if (biometricsAvailable) {
        final ok = await authenticateWithBiometrics();
        if (ok) return true;
      }
    }

    if (pin != null && pin.isNotEmpty) {
      return authenticateWithPin(pin);
    }

    return false;
  }
}
