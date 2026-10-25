import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Thrown when secure storage (Keystore/Keychain) is unavailable and storing
/// the value in plain [SharedPreferences] would be unsafe.
class SecureStorageException implements Exception {
  final String message;
  SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}

/// Keystore/Keychain-backed secure storage.
///
/// Uses [FlutterSecureStorage] on non-web platforms. On web it falls back to
/// [SharedPrefsStorage] because browsers do not provide a secure keychain.
///
/// On non-web platforms, legacy values in [SharedPreferences] are moved into
/// secure storage before they are returned. A keychain failure never falls
/// back to leaving a secret in plain preferences. Tests can call
/// [enableTestMode] to use [SharedPrefsStorage] instead.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static bool _testMode = false;

  /// Use [SharedPreferences] as the backing store. Intended for tests only.
  @visibleForTesting
  static void enableTestMode() => _testMode = true;

  /// Restore the real secure storage backend. Intended for tests only.
  @visibleForTesting
  static void disableTestMode() => _testMode = false;

  static bool get _useSharedPrefs => kIsWeb || _testMode;

  static Future<String?> getString(String key) async {
    if (_useSharedPrefs) return SharedPrefsStorage.getString(key);

    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        await SharedPrefsStorage.remove(key);
        return value;
      }
      final legacyValue = await SharedPrefsStorage.getString(key);
      if (legacyValue == null) return null;

      // Migrate values written by older versions that fell back to plaintext
      // preferences. Do not return them unless the secure write succeeds.
      await _storage.write(key: key, value: legacyValue);
      await SharedPrefsStorage.remove(key);
      return legacyValue;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SecureStorage.getString failed for $key: $e\n$st');
      }
      throw SecureStorageException('Unable to read secure storage value: $e');
    }
  }

  static Future<void> setString(String key, String value) async {
    if (_useSharedPrefs) {
      await SharedPrefsStorage.setString(key, value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
      await SharedPrefsStorage.remove(key);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SecureStorage.setString failed for $key: $e\n$st');
      }
      throw SecureStorageException('Unable to write secure storage value: $e');
    }
  }

  static Future<void> remove(String key) async {
    if (_useSharedPrefs) {
      await SharedPrefsStorage.remove(key);
      return;
    }

    Object? secureStorageError;
    try {
      await _storage.delete(key: key);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SecureStorage.remove failed for $key: $e\n$st');
      }
      secureStorageError = e;
    }

    Object? legacyStorageError;
    try {
      await SharedPrefsStorage.remove(key);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SecureStorage legacy cleanup failed for $key: $e\n$st');
      }
      legacyStorageError = e;
    }

    if (secureStorageError != null) {
      throw SecureStorageException(
        'Unable to remove secure storage value: $secureStorageError',
      );
    }
    if (legacyStorageError != null) {
      throw SecureStorageException(
        'Unable to remove legacy storage value: $legacyStorageError',
      );
    }
  }
}
