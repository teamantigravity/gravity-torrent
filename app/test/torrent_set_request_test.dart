import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_set_request.dart';

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
    expect(json['speed-limit-down-enabled'], isTrue);
    expect(json['speed-limit-up-enabled'], isFalse);
    expect(json['speed-limit-down'], 512);
    expect(json.containsKey('speed-limit-up'), isFalse);
  });
}
