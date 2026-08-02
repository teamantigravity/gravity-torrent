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
    rethrow;
  }
}

class SharedPrefsStorage {
  @visibleForTesting
  static void resetForTest() {
    SharedPrefs.resetForTest();
  }

  static Future<String?> getString(String key) async {
    try {
      if (SharedPrefs._prefs == null) {
        await SharedPrefs.init();
      }
      return SharedPrefs.getString(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getString failed: $e');
      rethrow;
    }
  }

  static Future<void> setString(String key, String value) async {
    try {
      await SharedPrefs.setString(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setString failed: $e');
      rethrow;
    }
  }

  static Future<bool?> getBool(String key) async {
    try {
      if (SharedPrefs._prefs == null) {
        await SharedPrefs.init();
      }
      return SharedPrefs.getBool(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getBool failed: $e');
      rethrow;
    }
  }

  static Future<void> setBool(String key, bool value) async {
    try {
      await SharedPrefs.setBool(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setBool failed: $e');
      rethrow;
    }
  }

  static Future<double?> getDouble(String key) async {
    try {
      if (SharedPrefs._prefs == null) {
        await SharedPrefs.init();
      }
      return SharedPrefs.getDouble(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getDouble failed: $e');
      rethrow;
    }
  }

  static Future<void> setDouble(String key, double value) async {
    try {
      await SharedPrefs.setDouble(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setDouble failed: $e');
      rethrow;
    }
  }

  static Future<void> remove(String key) async {
    try {
      await SharedPrefs.remove(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.remove failed: $e');
      rethrow;
    }
  }

  static Future<int?> getInt(String key) async {
    try {
      if (SharedPrefs._prefs == null) {
        await SharedPrefs.init();
      }
      return SharedPrefs.getInt(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getInt failed: $e');
      rethrow;
    }
  }

  static Future<void> setInt(String key, int value) async {
    try {
      await SharedPrefs.setInt(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setInt failed: $e');
      rethrow;
    }
  }

  static Future<List<String>?> getStringList(String key) async {
    try {
      if (SharedPrefs._prefs == null) {
        await SharedPrefs.init();
      }
      return SharedPrefs.getStringList(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getStringList failed: $e');
      rethrow;
    }
  }

  static Future<void> setStringList(String key, List<String> value) async {
    try {
      await SharedPrefs.setStringList(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.setStringList failed: $e');
      rethrow;
    }
  }

  static Future<Set<String>> getKeys() async {
    try {
      if (SharedPrefs._prefs == null) {
        await SharedPrefs.init();
      }
      return SharedPrefs.getKeys();
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.getKeys failed: $e');
      rethrow;
    }
  }

  static Future<Object?> get(String key) async {
    try {
      if (SharedPrefs._prefs == null) {
        await SharedPrefs.init();
      }
      return SharedPrefs.get(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefsStorage.get failed: $e');
      rethrow;
    }
  }
}

/// Synchronous wrapper around [SharedPreferences].
///
/// Call [SharedPrefs.init] once during app startup before any service reads
/// shared preferences synchronously.
class SharedPrefs {
  @visibleForTesting
  static void resetForTest() {
    _prefs = null;
  }

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPrefs.init failed: $e');
      rethrow;
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
    if (_prefs == null) {
      await init();
    }
    if (_prefs == null) return;
    await _guard(() => _prefs!.setBool(key, value), key, 'setBool');
  }

  static Future<void> setInt(String key, int value) async {
    if (_prefs == null) {
      await init();
    }
    if (_prefs == null) return;
    await _guard(() => _prefs!.setInt(key, value), key, 'setInt');
  }

  static Future<void> setDouble(String key, double value) async {
    if (_prefs == null) {
      await init();
    }
    if (_prefs == null) return;
    await _guard(() => _prefs!.setDouble(key, value), key, 'setDouble');
  }

  static Future<void> setString(String key, String value) async {
    if (_prefs == null) {
      await init();
    }
    if (_prefs == null) return;
    await _guard(() => _prefs!.setString(key, value), key, 'setString');
  }

  static Future<void> setStringList(String key, List<String> value) async {
    if (_prefs == null) {
      await init();
    }
    if (_prefs == null) return;
    await _guard(() => _prefs!.setStringList(key, value), key, 'setStringList');
  }

  static Future<void> remove(String key) async {
    if (_prefs == null) {
      await init();
    }
    if (_prefs == null) return;
    await _guard(() => _prefs!.remove(key), key, 'remove');
  }
}
