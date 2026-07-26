import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gravity_torrent/storage/shared_preferences.dart';

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

  static const _lastFetchKey = 'gravity_torrent_remote_config_last_fetch';

  bool _showAds = true;
  bool get showAds => _showAds;

  final Map<String, bool> _featureFlags = {};
  Map<String, bool> get featureFlags => Map.unmodifiable(_featureFlags);

  DateTime? _lastFetch;

  bool isFeatureEnabled(String key, {bool defaultValue = true}) =>
      _featureFlags[key] ?? defaultValue;

  Future<void> _loadLastFetch() async {
    try {
      final ms = await SharedPrefsStorage.getInt(_lastFetchKey);
      if (ms != null) {
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] failed to load last fetch time: $e');
      }
    }
  }

  Future<void> _saveLastFetch() async {
    final last = _lastFetch;
    if (last == null) return;
    try {
      await SharedPrefsStorage.setInt(
        _lastFetchKey,
        last.millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] failed to save last fetch time: $e');
      }
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_lastFetch == null) await _loadLastFetch();

    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(hours: 6)) {
      return;
    }
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 8));

      // Throttle future requests whether the response is valid or not.
      _lastFetch = DateTime.now();
      await _saveLastFetch();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            '[RemoteConfig] non-success status ${response.statusCode}',
          );
        }
        return;
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      if (json.containsKey('show_ads') && json['show_ads'] is bool) {
        _showAds = json['show_ads'] as bool;
      }
      if (json.containsKey('sota_features') && json['sota_features'] is Map) {
        final features =
            Map<String, dynamic>.from(json['sota_features'] as Map);
        _featureFlags.clear();
        for (final entry in features.entries) {
          if (entry.value is bool) {
            _featureFlags[entry.key] = entry.value as bool;
          }
        }
      }
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] fetch timed out (keeping defaults)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] fetch failed (keeping defaults): $e');
      }
    }
  }
}
