import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/secure_storage.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:gravity_torrent/utils/ip_address.dart';
import 'package:gravity_torrent/utils/secure_token.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

export 'package:gravity_torrent/utils/secure_token.dart'
    show generateSecureRandomToken;

class ApiKey {
  final String id;
  final String name;
  final String key;
  final DateTime createdAt;
  final bool enabled;

  ApiKey({
    required this.id,
    required this.name,
    required this.key,
    required this.createdAt,
    this.enabled = true,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      id: json['id'] as String,
      name: json['name'] as String,
      key: json['key'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'key': key,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'enabled': enabled,
    };
  }

  ApiKey copyWith({
    String? id,
    String? name,
    String? key,
    DateTime? createdAt,
    bool? enabled,
  }) {
    return ApiKey(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      createdAt: createdAt ?? this.createdAt,
      enabled: enabled ?? this.enabled,
    );
  }
}

class RemoteControlSettings {
  final bool allowLocalNetwork;
  final bool useApiKeys;

  const RemoteControlSettings({
    this.allowLocalNetwork = true,
    this.useApiKeys = false,
  });

  factory RemoteControlSettings.fromJson(Map<String, dynamic> json) {
    return RemoteControlSettings(
      allowLocalNetwork: json['allowLocalNetwork'] as bool? ?? true,
      useApiKeys: json['useApiKeys'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'allowLocalNetwork': allowLocalNetwork, 'useApiKeys': useApiKeys};
  }

  RemoteControlSettings copyWith({bool? allowLocalNetwork, bool? useApiKeys}) {
    return RemoteControlSettings(
      allowLocalNetwork: allowLocalNetwork ?? this.allowLocalNetwork,
      useApiKeys: useApiKeys ?? this.useApiKeys,
    );
  }
}

class RemoteControlService {
  RemoteControlService._();
  static final RemoteControlService instance = RemoteControlService._();

  static const _apiKeyStorageKey = 'gravity_torrent_api_keys';
  static const _settingsKey = 'gravity_torrent_remote_settings';
  static const _maxRequestBodyBytes = 64 * 1024;

  HttpServer? _server;
  bool _starting = false;
  int _startGeneration = 0;
  bool _disposed = false;
  String _token = '';
  String _localAddress = '';
  String _qrPayload = '';
  int _port = 0;

  List<ApiKey> _apiKeys = [];
  RemoteControlSettings _settings = const RemoteControlSettings();

  bool get isRunning => _server != null;
  String get token => _token;
  String get localAddress => _localAddress;
  String get qrPayload => _qrPayload;
  int get port => _port;
  List<ApiKey> get apiKeys => List.unmodifiable(_apiKeys);
  RemoteControlSettings get settings => _settings;

  Future<void> start({int port = 0}) async {
    if (kIsWeb || _server != null || _starting || _disposed) return;
    _starting = true;
    final generation = ++_startGeneration;
    try {
      await loadSettings();
      await loadApiKeys();
      if (_disposed || generation != _startGeneration) return;

      _token = _generateToken();
      final ip = _settings.allowLocalNetwork
          ? await _localIp()
          : InternetAddress.loopbackIPv4.address;
      if (_disposed || generation != _startGeneration) return;
      final candidate = await shelf_io.serve(
        _handler,
        bindAddressFor(ip, allowLocalNetwork: _settings.allowLocalNetwork),
        port,
        shared: true,
      );
      if (_disposed || generation != _startGeneration) {
        await candidate.close(force: true);
        return;
      }
      _server = candidate;
      _port = candidate.port;
      _localAddress = 'http://${formatHostForUrl(ip)}:$_port';
      _qrPayload = jsonEncode({'url': _localAddress, 'token': _token});
    } finally {
      if (generation == _startGeneration) _starting = false;
    }
  }

  /// Wraps an IPv6 address in square brackets so the `:port` suffix is
  /// unambiguous. IPv4 addresses are returned unchanged.
  @visibleForTesting
  String formatHostForUrl(String address) {
    var sanitized = address;
    final scopeIndex = sanitized.indexOf('%');
    if (scopeIndex != -1) {
      sanitized = sanitized.substring(0, scopeIndex);
    }
    if (sanitized.contains(':')) return '[$sanitized]';
    return sanitized;
  }

  /// Restricts the listener to loopback when LAN access is disabled and
  /// rejects non-private addresses even if the interface lookup is wrong.
  @visibleForTesting
  InternetAddress bindAddressFor(
    String address, {
    required bool allowLocalNetwork,
  }) {
    if (!allowLocalNetwork) return InternetAddress.loopbackIPv4;
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null || !isPrivateIp(parsed)) {
      return InternetAddress.loopbackIPv4;
    }
    return parsed;
  }

  Future<void> stop() async {
    if (_disposed) return;
    _startGeneration++;
    _starting = false;
    await _server?.close();
    _server = null;
    _port = 0;
  }

  Future<void> dispose() async {
    await stop();
    _disposed = true;
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed) return;
    if (value && _server == null && !_starting) {
      try {
        await start();
      } catch (e) {
        if (kDebugMode) debugPrint('RemoteControlService start failed: $e');
        rethrow;
      }
    } else if (!value && (_server != null || _starting)) {
      await stop();
    }
  }

  String _generateToken() => generateSecureRandomToken();

  Future<void> loadSettings() async {
    try {
      final raw = await SharedPrefsStorage.getString(_settingsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _settings = RemoteControlSettings.fromJson(decoded);
      }
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('Failed to load remote control settings: $e\n$s');
      }
    }
  }

  Future<void> saveSettings() async {
    try {
      await SharedPrefsStorage.setString(
        _settingsKey,
        jsonEncode(_settings.toJson()),
      );
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('Failed to save remote control settings: $e\n$s');
      }
      rethrow;
    }
  }

  Future<void> updateSettings(RemoteControlSettings newSettings) async {
    if (_disposed) return;
    final previousSettings = _settings;
    final restartServer = _server != null &&
        previousSettings.allowLocalNetwork != newSettings.allowLocalNetwork;
    _settings = newSettings;
    try {
      await saveSettings();
    } catch (_) {
      _settings = previousSettings;
      rethrow;
    }
    if (restartServer) {
      await stop();
      await start();
    }
  }

  Future<void> loadApiKeys() async {
    try {
      final raw = await SecureStorage.getString(_apiKeyStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _apiKeys = list
            .whereType<Map<String, dynamic>>()
            .map((e) => ApiKey.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('Failed to load API keys: $e\n$s');
      }
      _apiKeys = [];
    }
  }

  Future<void> saveApiKeys() async {
    await SecureStorage.setString(
      _apiKeyStorageKey,
      jsonEncode(_apiKeys.map((k) => k.toJson()).toList()),
    );
  }

  Future<ApiKey> createApiKey(String name) async {
    final id = generateSecureRandomToken(length: 16);
    final key = generateSecureRandomToken();
    final apiKey = ApiKey(
      id: id,
      name: name,
      key: key,
      createdAt: DateTime.now(),
    );
    _apiKeys.add(apiKey);
    try {
      await saveApiKeys();
    } catch (_) {
      _apiKeys.remove(apiKey);
      rethrow;
    }
    return apiKey;
  }

  Future<void> deleteApiKey(String id) async {
    final previousKeys = List<ApiKey>.of(_apiKeys);
    _apiKeys.removeWhere((k) => k.id == id);
    try {
      await saveApiKeys();
    } catch (_) {
      _apiKeys = previousKeys;
      rethrow;
    }
  }

  Future<void> enableApiKey(String id, bool enabled) async {
    final index = _apiKeys.indexWhere((k) => k.id == id);
    if (index >= 0) {
      final previousKey = _apiKeys[index];
      _apiKeys[index] = _apiKeys[index].copyWith(enabled: enabled);
      try {
        await saveApiKeys();
      } catch (_) {
        _apiKeys[index] = previousKey;
        rethrow;
      }
    }
  }

  /// Returns true for private IPv4 ranges (10/8, 172.16/12, 192.168/16),
  /// IPv6 unique-local (fc00::/7), link-local (fe80::/10), CGNAT
  /// (100.64.0.0/10), and loopback.
  @visibleForTesting
  bool isPrivateIp(InternetAddress address) =>
      IpAddressScope.isPrivate(address);

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: false);

      InternetAddress? ipv4;
      InternetAddress? ipv6;

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          if (!isPrivateIp(addr)) continue;
          if (addr.type == InternetAddressType.IPv4) {
            ipv4 ??= addr;
          } else if (addr.type == InternetAddressType.IPv6) {
            ipv6 ??= addr;
          }
        }
      }

      // Prefer IPv4 for the displayed URL because it is easier for users to
      // type/scan; fall back to IPv6 if no private IPv4 is available.
      final chosen = ipv4 ?? ipv6;
      if (chosen != null) {
        var addr = chosen.address;
        final scopeIndex = addr.indexOf('%');
        if (scopeIndex != -1) {
          addr = addr.substring(0, scopeIndex);
        }
        return addr;
      }
    } catch (e) {
      // Fall through to loopback
    }
    return InternetAddress.loopbackIPv4.address;
  }

  Handler get _handler {
    final pipeline = const Pipeline().addMiddleware(_tokenAuthMiddleware);
    return pipeline.addHandler(_routeHandler);
  }

  Future<Response> _routeHandler(Request request) async {
    final path = request.url.path;
    final method = request.method;

    // No CORS headers are emitted on purpose. This API is meant for the
    // companion client, and allowing cross-origin browser access would let any
    // web page a user visits probe and drive their local torrent session.
    if (path == 'health' && method == 'GET') {
      return _jsonResponse({
        'ok': isRunning,
        'address': localAddress,
        'port': port,
      });
    }

    if (path == 'torrents' && method == 'GET') {
      if (!getIt.isRegistered<Engine>()) {
        return _jsonResponse({'ok': false, 'error': 'engine not ready'});
      }
      final engine = getIt<Engine>();
      final torrents = await engine.fetchTorrents();
      final payload = torrents
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'progress': t.progress,
              'status': t.status.name,
              'rateDownload': t.rateDownload,
              'rateUpload': t.rateUpload,
            },
          )
          .toList();
      return _jsonResponse({'torrents': payload});
    }

    if (path == 'pause' && method == 'POST') {
      if (!getIt.isRegistered<Engine>()) {
        return _jsonResponse({'ok': false, 'error': 'engine not ready'});
      }
      final engine = getIt<Engine>();
      final torrents = await engine.fetchTorrents();
      final toPause = torrents
          .where(
            (t) =>
                t.status == TorrentStatus.downloading ||
                t.status == TorrentStatus.seeding,
          )
          .map((t) => t.id)
          .toList();
      if (toPause.isNotEmpty) {
        await engine.pauseTorrents(toPause);
      }
      return _jsonResponse({'ok': true});
    }

    if (path == 'resume' && method == 'POST') {
      if (!getIt.isRegistered<Engine>()) {
        return _jsonResponse({'ok': false, 'error': 'engine not ready'});
      }
      final engine = getIt<Engine>();
      final torrents = await engine.fetchTorrents();
      final toResume = torrents
          .where((t) => t.status == TorrentStatus.stopped)
          .map((t) => t.id)
          .toList();
      if (toResume.isNotEmpty) {
        await engine.resumeTorrents(toResume);
      }
      return _jsonResponse({'ok': true});
    }

    if (path == 'add' && method == 'POST') {
      if (!getIt.isRegistered<Engine>()) {
        return _jsonResponse({'ok': false, 'error': 'engine not ready'});
      }
      if (!(await QuotaService.instance.canAddTorrent())) {
        return _jsonResponse({
          'ok': false,
          'error': 'monthly bandwidth quota exceeded',
        });
      }
      late final String body;
      try {
        body = await _readRequestBody(request);
      } on _RequestBodyTooLarge {
        return Response(
          HttpStatus.requestEntityTooLarge,
          body: jsonEncode({'ok': false, 'error': 'request body too large'}),
          headers: {'content-type': 'application/json'},
        );
      } on FormatException {
        return Response.badRequest(
          body: jsonEncode({'ok': false, 'error': 'invalid request body'}),
          headers: {'content-type': 'application/json'},
        );
      }
      String? magnet;
      try {
        final json = jsonDecode(body);
        if (json is Map) magnet = json['magnet']?.toString();
      } on FormatException {
        try {
          final params = Uri.splitQueryString(body);
          magnet = params['magnet'];
        } on FormatException {
          return Response.badRequest(
            body: jsonEncode({'ok': false, 'error': 'invalid request body'}),
            headers: {'content-type': 'application/json'},
          );
        }
      }
      if (magnet == null || magnet.isEmpty) {
        return _jsonResponse({'ok': false, 'error': 'missing magnet'});
      }
      if (!await _isValidTorrentLink(magnet)) {
        return _jsonResponse({'ok': false, 'error': 'invalid torrent link'});
      }
      final engine = getIt<Engine>();
      final response = await engine.addTorrent(magnet, null, null);
      return _jsonResponse({'ok': response == TorrentAddedResponse.added});
    }

    return Response.notFound(
      '{"ok":false,"error":"not found"}',
      headers: {'content-type': 'application/json'},
    );
  }

  Middleware get _tokenAuthMiddleware {
    return (Handler innerHandler) {
      return (Request request) async {
        // Check API key first if enabled
        if (_settings.useApiKeys) {
          final apiKey = _extractApiKey(request);
          if (apiKey != null) {
            ApiKey? keyRecord;
            for (final candidate in _apiKeys) {
              if (candidate.enabled &&
                  _constantTimeCompare(candidate.key, apiKey)) {
                keyRecord = candidate;
                break;
              }
            }
            if (keyRecord != null) {
              return innerHandler(request);
            }
          }
        }

        // Fall back to session token
        final provided = _extractToken(request);
        if (provided == null || !_constantTimeCompare(provided, _token)) {
          return Response.forbidden(
            '{"ok":false,"error":"invalid token"}',
            headers: {'content-type': 'application/json'},
          );
        }
        return innerHandler(request);
      };
    };
  }

  /// Extracts the API key from the `X-API-Key` header.
  String? _extractApiKey(Request request) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'x-api-key') {
        return entry.value.trim();
      }
    }
    return null;
  }

  /// Extracts the bearer token from the `Authorization` header only.
  /// Query-string tokens are intentionally rejected so tokens are not leaked
  /// via browser history, referrers, or server logs.
  String? _extractToken(Request request) {
    String? authHeader;
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        authHeader = entry.value;
        break;
      }
    }
    if (authHeader != null && authHeader.isNotEmpty) {
      final parts = authHeader.trim().split(RegExp(r'\s+'));
      if (parts.length == 2 && parts[0].toLowerCase() == 'bearer') {
        return parts[1];
      }
      // Also allow a raw token in the Authorization header.
      return authHeader.trim();
    }
    return null;
  }

  /// Constant-time string comparison to mitigate timing attacks.
  ///
  /// Iterates over the full length so that an attacker cannot learn the
  /// secret token's length from a short-circuiting comparison.
  bool _constantTimeCompare(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    const comparisonLength = 256;
    if (left.length > comparisonLength || right.length > comparisonLength) {
      return false;
    }
    var result = left.length ^ right.length;
    for (var i = 0; i < comparisonLength; i++) {
      final leftByte = i < left.length ? left[i] : 0;
      final rightByte = i < right.length ? right[i] : 0;
      result |= leftByte ^ rightByte;
    }
    return result == 0;
  }

  Future<String> _readRequestBody(Request request) async {
    final contentLength = request.contentLength;
    if (contentLength != null && contentLength > _maxRequestBodyBytes) {
      throw _RequestBodyTooLarge();
    }

    final body = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      if (body.length + chunk.length > _maxRequestBodyBytes) {
        throw _RequestBodyTooLarge();
      }
      body.add(chunk);
    }
    return utf8.decode(body.takeBytes());
  }

  /// Rejects anything other than a magnet URI or a public .torrent URL.
  ///
  /// The path component is checked so that private-tracker query parameters
  /// such as `?passkey=...` are preserved and accepted. Hosts are validated
  /// against the same public-address rules used for blocklists and RSS feeds.
  Future<bool> _isValidTorrentLink(String link) =>
      IpAddressScope.isPubliclyRoutableLink(link);

  Response _jsonResponse(Map<String, dynamic> body) {
    return Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );
  }
}

class _RequestBodyTooLarge implements Exception {}
