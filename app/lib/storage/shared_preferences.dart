import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsStorage {
  static Future<String?> getString(String key) async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> setString(String key, String value) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<bool?> getBool(String key) async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  static Future<void> setBool(String key, bool value) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<void> remove(String key) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
