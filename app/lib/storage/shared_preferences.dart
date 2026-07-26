import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _guard(
  Future<void> Function() fn,
  String key,
  String action,
) async {
  try {
    await fn();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('SharedPrefs $action failed for $key: $e\n$st');
    }
  }
}

class SharedPrefsStorage {
  static Future<String?> getString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getString failed: $e');
      return null;
    }
  }

  static Future<void> setString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setString failed: $e');
    }
  }

  static Future<bool?> getBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getBool failed: $e');
      return null;
    }
  }

  static Future<void> setBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setBool failed: $e');
    }
  }

  static Future<double?> getDouble(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getDouble failed: $e');
      return null;
    }
  }

  static Future<void> setDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setDouble failed: $e');
    }
  }

  static Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.remove failed: $e');
    }
  }

  static Future<int?> getInt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getInt failed: $e');
      return null;
    }
  }

  static Future<void> setInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setInt failed: $e');
    }
  }

  static Future<List<String>?> getStringList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getStringList failed: $e');
      return null;
    }
  }

  static Future<void> setStringList(String key, List<String> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setStringList failed: $e');
    }
  }

  static Future<Set<String>> getKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys();
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getKeys failed: $e');
      return const <String>{};
    }
  }

  static Future<Object?> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.get(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.get failed: $e');
      return null;
    }
  }
}

/// Synchronous wrapper around [SharedPreferences].
///
/// Call [SharedPrefs.init] once during app startup before any service reads
/// shared preferences synchronously.
class SharedPrefs {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefs.init failed: $e');
    }
  }

  static bool? getBool(String key) => _prefs?.getBool(key);
  static int? getInt(String key) => _prefs?.getInt(key);
  static double? getDouble(String key) => _prefs?.getDouble(key);
  static String? getString(String key) => _prefs?.getString(key);
  static List<String>? getStringList(String key) => _prefs?.getStringList(key);
  static Object? get(String key) => _prefs?.get(key);
  static Set<String> getKeys() => _prefs?.getKeys() ?? const <String>{};

  static Future<void> setBool(String key, bool value) async {
    if (_prefs == null) return;
    await _guard(() => _prefs!.setBool(key, value), key, 'setBool');
  }

  static Future<void> setInt(String key, int value) async {
    if (_prefs == null) return;
    await _guard(() => _prefs!.setInt(key, value), key, 'setInt');
  }

  static Future<void> setDouble(String key, double value) async {
    if (_prefs == null) return;
    await _guard(() => _prefs!.setDouble(key, value), key, 'setDouble');
  }

  static Future<void> setString(String key, String value) async {
    if (_prefs == null) return;
    await _guard(() => _prefs!.setString(key, value), key, 'setString');
  }

  static Future<void> setStringList(String key, List<String> value) async {
    if (_prefs == null) return;
    await _guard(
      () => _prefs!.setStringList(key, value),
      key,
      'setStringList',
    );
  }

  static Future<void> remove(String key) async {
    if (_prefs == null) return;
    await _guard(() => _prefs!.remove(key), key, 'remove');
  }
}
