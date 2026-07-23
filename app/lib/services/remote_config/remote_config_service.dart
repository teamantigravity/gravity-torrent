import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Remote kill-switch for ads and SOTA feature flags.
///
/// The remote config JSON is expected to contain:
/// {
///   "show_ads": bool,
///   "sota_features": {
///     "useDynamicColor": bool,
///     "useEnhancedNotifications": bool,
///     "usePipBackgroundAudio": bool,
///     "enableRemoteControl": bool,
///     "enableAnalytics": bool,
///     "enableAppLock": bool,
///     "enableShortcuts": bool,
///     "enableHaptic": bool
///   }
/// }
///
/// A feature flag omitted from the remote response is treated as enabled by
/// default, so existing users are not affected by a missing config entry.
/// Setting a flag to `false` remotely disables it regardless of the local
/// user preference.
class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  static const _configUrl = String.fromEnvironment(
    'GRAVITY_TORRENT_REMOTE_CONFIG_URL',
    defaultValue: 'https://teamantigravity.vercel.app/gravity_config.json',
  );

  bool showAds = true;
  final Map<String, bool> featureFlags = {};
  DateTime? _lastFetch;

  bool isFeatureEnabled(String key, {bool defaultValue = true}) =>
      featureFlags[key] ?? defaultValue;

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
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      if (json.containsKey('show_ads') && json['show_ads'] is bool) {
        showAds = json['show_ads'] as bool;
      }
      if (json.containsKey('sota_features') && json['sota_features'] is Map) {
        final features =
            Map<String, dynamic>.from(json['sota_features'] as Map);
        featureFlags.clear();
        for (final entry in features.entries) {
          if (entry.value is bool) {
            featureFlags[entry.key] = entry.value as bool;
          }
        }
      }
      _lastFetch = DateTime.now();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] fetch failed (keeping defaults): $e');
      }
    }
  }
}
