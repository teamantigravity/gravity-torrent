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
  final Completer<void> _serverReadyCompleter = Completer<void>();
  bool _stopped = false;

  SubtitlesServer({required this.torrent});

  Future<void> start() async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      if (_stopped) {
        if (!_serverReadyCompleter.isCompleted) {
          _serverReadyCompleter.completeError(
            StateError('SubtitlesServer was stopped before it could start'),
          );
        }
        await server.close(force: true);
        return;
      }
      if (!_serverReadyCompleter.isCompleted) {
        _serverReadyCompleter.complete();
      }

      await for (final HttpRequest request in server) {
        // Requests are handled concurrently: awaiting here would serialise the
        // accept loop, so a single stalled client would block every other
        // subtitle fetch (the player requests several tracks in parallel).
        unawaited(
          handleRequest(request).catchError((Object e) {
            if (kDebugMode) {
              debugPrint('SubtitlesServer: unhandled request error: $e');
            }
          }),
        );
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
    try {
      final path = request.uri.path;
      // /subtitle.vtt
      if (path.isNotEmpty &&
          path != '/' &&
          isSubtitleFileName(path.substring(1))) {
        await serveFile(request.response, path.substring(1));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('404: Not Found');
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('500: Internal Server Error');
      } catch (responseError) {
        if (kDebugMode) {
          debugPrint(
            'SubtitlesServer: failed to set error response: $responseError',
          );
        }
      }
      if (kDebugMode) debugPrint('Error serving file: $e');
    }

    try {
      await request.response.close();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SubtitlesServer: failed to close response: $e');
      }
    }
  }

  Future<void> serveFile(HttpResponse response, String filePath) async {
    final root = Directory(torrent.location).resolveSymbolicLinksSync();
    final resolved = File(p.normalize(p.join(root, filePath)));
    final String realPath;
    try {
      realPath = resolved.resolveSymbolicLinksSync();
    } on FileSystemException {
      response.statusCode = HttpStatus.notFound;
      response.write('404: Not Found');
      return;
    }
    final normalizedRoot = p.normalize(root);
    final normalizedResolved = p.normalize(realPath);
    if (!p.isWithin(normalizedRoot, normalizedResolved) &&
        normalizedResolved != normalizedRoot) {
      response.statusCode = HttpStatus.forbidden;
      response.write('403: Forbidden');
      return;
    }

    final file = File(realPath);

    if (file.existsSync()) {
      final mimeType = lookupMimeType(filePath) ?? ContentType.binary.mimeType;
      try {
        response.headers.contentType = ContentType.parse(mimeType);
      } on FormatException {
        response.headers.contentType = ContentType.binary;
      }
      await response.addStream(file.openRead());
    } else {
      response.statusCode = HttpStatus.notFound;
      response.write('404: Not Found');
    }
  }
}
