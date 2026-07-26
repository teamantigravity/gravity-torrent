import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/utils/secure_token.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

export 'package:gravity_torrent/utils/secure_token.dart'
    show generateSecureRandomToken;

class RemoteControlService {
  RemoteControlService._();
  static final RemoteControlService instance = RemoteControlService._();

  HttpServer? _server;
  bool _starting = false;
  bool _disposed = false;
  String _token = '';
  String _localAddress = '';
  String _qrPayload = '';
  int _port = 0;

  bool get isRunning => _server != null;
  String get token => _token;
  String get localAddress => _localAddress;
  String get qrPayload => _qrPayload;
  int get port => _port;

  Future<void> start({int port = 0}) async {
    if (kIsWeb || _server != null || _starting) return;
    _starting = true;
    try {
      _token = _generateToken();
      final ip = await _localIp();
      if (_disposed) return;
      // Bind to the private/local address. If no private address is available,
      // fall back to loopback so we never bind to a public interface.
      final bindAddress =
          InternetAddress.tryParse(ip) ?? InternetAddress.loopbackIPv4;
      _server = await shelf_io.serve(_handler, bindAddress, port, shared: true);
      _port = _server!.port;
      _localAddress = 'http://${formatHostForUrl(ip)}:$_port';
      _qrPayload = jsonEncode({'url': _localAddress, 'token': _token});
    } finally {
      _starting = false;
    }
  }

  /// Wraps an IPv6 address in square brackets so the `:port` suffix is
  /// unambiguous. IPv4 addresses are returned unchanged.
  @visibleForTesting
  String formatHostForUrl(String address) {
    if (address.contains(':')) return '[$address]';
    return address;
  }

  Future<void> stop() async {
    if (_disposed) return;
    await _server?.close();
    _server = null;
    _port = 0;
  }

  void dispose() {
    _disposed = true;
    unawaited(stop());
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

  /// Returns true for private IPv4 ranges (10/8, 172.16/12, 192.168/16),
  /// IPv6 unique-local (fc00::/7), link-local (fe80::/10), and loopback.
  @visibleForTesting
  bool isPrivateIp(InternetAddress address) {
    if (address.isLoopback) return true;

    if (address.type == InternetAddressType.IPv4) {
      final parts = address.address.split('.');
      if (parts.length != 4) return false;
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      if (first == null || second == null) return false;
      if (first == 10) return true;
      if (first == 172 && second >= 16 && second <= 31) return true;
      if (first == 192 && second == 168) return true;
      return false;
    }

    if (address.type == InternetAddressType.IPv6) {
      final bytes = address.rawAddress;
      if (bytes.isEmpty) return false;
      // fe80::/10
      if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) return true;
      // fc00::/7
      if ((bytes[0] & 0xfe) == 0xfc) return true;
      return false;
    }

    return false;
  }

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
      );

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
      if (chosen != null) return chosen.address;
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
      final body = await request.readAsString();
      String? magnet;
      try {
        final json = jsonDecode(body);
        if (json is Map) magnet = json['magnet']?.toString();
      } catch (_) {
        final params = Uri.splitQueryString(body);
        magnet = params['magnet'];
      }
      if (magnet == null || magnet.isEmpty) {
        return _jsonResponse({'ok': false, 'error': 'missing magnet'});
      }
      if (!_isValidTorrentLink(magnet)) {
        return _jsonResponse({
          'ok': false,
          'error': 'invalid torrent link',
        });
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
        // Every method, including OPTIONS, must authenticate. An unauthenticated
        // preflight escape hatch would be an auth bypass for a service reachable
        // from the whole local network.
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
  /// Iterates over the maximum length so that an attacker cannot learn the
  /// secret token's length from a short-circuiting comparison.
  bool _constantTimeCompare(String a, String b) {
    final maxLength = max(a.length, b.length);
    var result = a.length ^ b.length;
    for (var i = 0; i < maxLength; i++) {
      final ac = i < a.length ? a.codeUnitAt(i) : 0;
      final bc = i < b.length ? b.codeUnitAt(i) : 0;
      result |= ac ^ bc;
    }
    return result == 0;
  }

  /// Rejects anything other than a magnet URI or a public .torrent URL.
  ///
  /// The path component is checked so that private-tracker query parameters
  /// such as `?passkey=...` are preserved and accepted.
  bool _isValidTorrentLink(String link) {
    final trimmed = link.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('magnet:')) return true;
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        return uri.path.toLowerCase().endsWith('.torrent');
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Response _jsonResponse(Map<String, dynamic> body) {
    return Response.ok(
      jsonEncode(body),
      headers: {
        'content-type': 'application/json',
      },
    );
  }
}
