import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/utils/app_links.dart';

void main() {
  const magnet = 'magnet:?xt=urn:btih:1234567890abcdef&dn=example';

  group('getTorrentLink', () {
    test('round-trips a link created by createAppLink', () {
      final link = createAppLink(magnet);
      expect(isAppLink(link), isTrue);
      expect(getTorrentLink(link), magnet);
    });

    test('returns null when there is no fragment', () {
      expect(getTorrentLink('http://localhost:3000/'), isNull);
    });

    test('returns null when the fragment is not valid base64', () {
      expect(getTorrentLink('http://localhost:3000/#not-base64'), isNull);
    });

    test('returns null when the fragment has no magnet parameter', () {
      final fragment = base64Encode(utf8.encode('foo=bar'));
      expect(getTorrentLink('http://localhost:3000/#$fragment'), isNull);
    });
  });
}
