import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_get_request.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_set_request.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent.dart';

void main() {
  test('torrent-set encodes per-torrent speed limits', () {
    final request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [42],
        speedLimitDownEnabled: true,
        speedLimitUpEnabled: false,
        speedLimitDown: 512,
      ),
    );

    final json = request.toJson()['arguments'] as Map<String, dynamic>;
    expect(json['ids'], [42]);
    // Per-torrent limits use `download_limit(ed)` / `upload_limit(ed)` — the
    // session-level `speed-limit-*` keys are NOT recognized by torrent-set
    // and would silently be ignored by the engine.
    expect(json['download_limited'], isTrue);
    expect(json['upload_limited'], isFalse);
    expect(json['download_limit'], 512);
    expect(json.containsKey('upload_limit'), isFalse);
    expect(json.containsKey('speed-limit-down-enabled'), isFalse);
    expect(json.containsKey('speed-limit-down'), isFalse);
  });

  test(
      'torrent-set encodes sequential download under the underscore key '
      'only', () {
    final request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(ids: [7], sequentialDownload: true),
    );

    final json = request.toJson()['arguments'] as Map<String, dynamic>;
    expect(json['sequential_download'], isTrue);
    expect(json.containsKey('sequentialDownload'), isFalse);
  });

  test(
      'torrent-get requests sequential download and per-torrent speed '
      'limit fields under their RPC-native names', () {
    final request = TorrentGetRequest(
      arguments: TorrentGetRequestArguments(fields: const [
        TorrentField.sequentialDownload,
        TorrentField.speedLimitDownEnabled,
        TorrentField.speedLimitUpEnabled,
        TorrentField.speedLimitDown,
        TorrentField.speedLimitUp,
      ]),
    );

    final fields = (request.toJson()['arguments']
        as Map<String, dynamic>)['fields'] as List<dynamic>;
    expect(fields, [
      'sequential_download',
      'download_limited',
      'upload_limited',
      'download_limit',
      'upload_limit',
    ]);
  });

  test(
      'torrent-get response correctly parses sequential download and '
      'per-torrent speed limits', () {
    final model = TransmissionTorrentModel.fromJson({
      'id': 1,
      'sequential_download': true,
      'download_limited': true,
      'upload_limited': false,
      'download_limit': 256,
      'upload_limit': 0,
    });

    expect(model.sequentialDownload, isTrue);
    expect(model.speedLimitDownEnabled, isTrue);
    expect(model.speedLimitUpEnabled, isFalse);
    expect(model.speedLimitDown, 256);
  });
}
