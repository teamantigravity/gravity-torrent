import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/utils/subtitles.dart';
import 'package:path/path.dart' as p;

class SubtitlesServer {
  final Torrent torrent;
  HttpServer? _server;
  final Completer _serverReadyCompleter = Completer();
  bool _stopped = false;

  SubtitlesServer({required this.torrent});

  Future<void> start() async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      if (_stopped) {
        await server.close(force: true);
        return;
      }
      if (!_serverReadyCompleter.isCompleted) {
        _serverReadyCompleter.complete();
      }

      await for (final HttpRequest request in server) {
        await handleRequest(request);
      }
    } catch (e) {
      if (!_serverReadyCompleter.isCompleted) {
        _serverReadyCompleter.completeError(e);
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    _stopped = true;
    await _server?.close(force: true);
    _server = null;
  }

  Future<String> getAddress() async {
    await _serverReadyCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw StateError(
        'SubtitlesServer: timed out waiting for server to start',
      ),
    );
    final server = _server;
    if (server == null) {
      throw StateError('Subtitles server is not running');
    }
    return 'http://${server.address.host}:${server.port}';
  }

  Future<void> handleRequest(HttpRequest request) async {
    final path = Uri.decodeComponent(request.uri.path);

    try {
      // /subtitle.vtt
      if (isSubtitleFileName(path)) {
        await serveFile(request.response, path.substring(1));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('404: Not Found');
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('500: Internal Server Error');
      if (kDebugMode) debugPrint('Error serving file: $e');
    }

    await request.response.close();
  }

  Future<void> serveFile(HttpResponse response, String filePath) async {
    final resolved = p.normalize(p.join(torrent.location, filePath));
    final root = p.normalize(torrent.location);
    if (!p.isWithin(root, resolved) && resolved != root) {
      response.statusCode = HttpStatus.forbidden;
      response.write('403: Forbidden');
      return;
    }

    final file = File(resolved);

    if (await file.exists()) {
      final mimeType = lookupMimeType(filePath) ?? ContentType.binary.mimeType;
      final contentType = ContentType.parse(mimeType);
      response.headers.contentType = contentType;
      await response.addStream(file.openRead());
    } else {
      response.statusCode = HttpStatus.notFound;
      response.write('404: Not Found');
    }
  }
}
