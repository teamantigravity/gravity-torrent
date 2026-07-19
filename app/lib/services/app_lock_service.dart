import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:gravity_torrent/storage/secure_storage.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Privacy vault / app lock service.
///
/// Uses biometric auth when the device supports it, falling back to a numeric PIN.
/// On unsupported platforms (web, Linux, or devices without biometrics), the PIN
/// is used instead.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _pinKey = 'gravity_torrent_app_lock_pin';
  static const _enabledKey = 'gravity_torrent_app_lock_enabled';
  static const _useBiometricsKey = 'gravity_torrent_app_lock_use_biometrics';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _enabled = false;
  bool _useBiometrics = true;
  String _pinHash = '';

  bool get enabled => _enabled;
  bool get useBiometrics => _useBiometrics;
  bool get hasPin => _pinHash.isNotEmpty;

  Future<void> load() async {
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    _useBiometrics =
        await SharedPrefsStorage.getBool(_useBiometricsKey) ?? true;
    try {
      _pinHash = await SecureStorage.getString(_pinKey) ?? '';
    } on SecureStorageException catch (e) {
      _pinHash = '';
      if (kDebugMode) {
        debugPrint(
            'AppLockService: secure storage unavailable, disabling PIN: $e');
      }
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await SharedPrefsStorage.setBool(_enabledKey, value);
  }

  Future<void> setPin(String pin) async {
    _pinHash = _hashPin(pin);
    await SecureStorage.setString(_pinKey, _pinHash);
  }

  Future<void> clearPin() async {
    _pinHash = '';
    await SecureStorage.remove(_pinKey);
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
    } on LocalAuthException catch (_) {
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

  Future<bool> authenticateWithPin(String pin) async {
    if (_pinHash.isEmpty) return false;
    return _verifyPin(pin, _pinHash);
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

  String _hashPin(String pin) {
    final salt = _generateSalt();
    final bytes = utf8.encode(salt + pin);
    return '$salt:${sha256.convert(bytes).toString()}';
  }

  bool _verifyPin(String pin, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    final salt = parts[0];
    final hash = parts[1];
    final bytes = utf8.encode(salt + pin);
    return sha256.convert(bytes).toString() == hash;
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
