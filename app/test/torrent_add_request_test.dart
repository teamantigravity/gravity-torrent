import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_add_request.dart';

void main() {
  group('torrent-add encoding', () {
    test('encodes filename and metainfo', () {
      final request = TorrentAddRequest(
        arguments: TorrentAddRequestArguments(
          filename: 'magnet:?xt=urn:btih:abc',
          metainfo: 'base64data',
        ),
      );
      final json = request.toJson()['arguments'] as Map<String, dynamic>;
      expect(json['filename'], 'magnet:?xt=urn:btih:abc');
      expect(json['metainfo'], 'base64data');
    });

    test('encodes download directory only when non-empty', () {
      final request = TorrentAddRequest(
        arguments: TorrentAddRequestArguments(downloadDir: '/downloads'),
      );
      var json = request.toJson()['arguments'] as Map<String, dynamic>;
      expect(json['download-dir'], '/downloads');

      final emptyRequest = TorrentAddRequest(
        arguments: TorrentAddRequestArguments(downloadDir: ''),
      );
      json = emptyRequest.toJson()['arguments'] as Map<String, dynamic>;
      expect(json.containsKey('download-dir'), isFalse);

      final nullRequest = TorrentAddRequest(
        arguments: TorrentAddRequestArguments(),
      );
      json = nullRequest.toJson()['arguments'] as Map<String, dynamic>;
      expect(json.containsKey('download-dir'), isFalse);
    });

    test('omits null fields from the payload', () {
      final request = TorrentAddRequest(
        arguments: TorrentAddRequestArguments(),
      );
      final json = request.toJson()['arguments'] as Map<String, dynamic>;
      expect(json.isEmpty, isTrue);
    });
  });
}
