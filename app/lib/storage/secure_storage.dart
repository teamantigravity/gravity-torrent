import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'shared_preferences.dart';

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
    if (_useSharedPrefs) return await SharedPrefsStorage.getString(key);

    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw SecureStorageException('Unable to read from secure storage: $e');
    }
  }

  static Future<void> setString(String key, String value) async {
    if (_useSharedPrefs) {
      await SharedPrefsStorage.setString(key, value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw SecureStorageException('Unable to write to secure storage: $e');
    }
  }

  static Future<void> remove(String key) async {
    if (_useSharedPrefs) {
      await SharedPrefsStorage.remove(key);
      return;
    }

    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw SecureStorageException('Unable to delete from secure storage: $e');
    }
  }
}
