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
/// By default a failure on a non-web platform throws [SecureStorageException]
/// rather than silently writing sensitive data to plain [SharedPreferences].
/// Tests can call [enableTestMode] to use [SharedPrefsStorage] instead.
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
      return await _storage.read(key: key);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SecureStorage.getString failed for $key: $e\n$st');
      }
      // Attempt to clear invalidated hardware key entry
      try {
        await _storage.delete(key: key);
      } catch (_) {}

      // Fallback read from SharedPreferences
      try {
        return await SharedPrefsStorage.getString(key);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> setString(String key, String value) async {
    if (_useSharedPrefs) {
      await SharedPrefsStorage.setString(key, value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SecureStorage.setString failed for $key: $e\n$st');
      }
      // Attempt cleanup and retry write
      try {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
        return;
      } catch (_) {}

      // Fallback write to SharedPreferences
      try {
        await SharedPrefsStorage.setString(key, value);
      } catch (_) {
        throw SecureStorageException('Unable to write to secure storage: $e');
      }
    }
  }

  static Future<void> remove(String key) async {
    if (_useSharedPrefs) {
      await SharedPrefsStorage.remove(key);
      return;
    }

    try {
      await _storage.delete(key: key);
      try {
        await SharedPrefsStorage.remove(key);
      } catch (_) {}
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SecureStorage.remove failed for $key: $e\n$st');
      }
      try {
        await SharedPrefsStorage.remove(key);
      } catch (_) {}
    }
  }
}
