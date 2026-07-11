import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Remote kill-switch for ads. Fetched from the Team Antigravity website.
class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  static const _configUrl = String.fromEnvironment(
    'GRAVITY_TORRENT_REMOTE_CONFIG_URL',
    defaultValue: 'https://teamantigravity.vercel.app/gravity_config.json',
  );

  bool showAds = true;
  DateTime? _lastFetch;

  Future<void> refresh({bool force = false}) async {
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(hours: 6)) {
      return;
    }
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json.containsKey('show_ads') && json['show_ads'] is bool) {
        showAds = json['show_ads'] as bool;
      }
      _lastFetch = DateTime.now();
    } catch (e) {
      debugPrint('[RemoteConfig] fetch failed (keeping defaults): $e');
    }
  }
}
