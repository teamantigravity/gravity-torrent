import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/blocklist_service.dart';
import 'package:gravity_torrent/services/remote_control_service.dart';
import 'package:gravity_torrent/services/rss_service.dart';
import 'package:gravity_torrent/services/scheduler_service.dart';
import 'package:gravity_torrent/utils/media_queue.dart';
import 'package:gravity_torrent/utils/secure_token.dart';
import 'package:gravity_torrent/utils/subtitles.dart';

void main() {
  group('Edge-case hunt', () {
    test('subtitle language does not misdetect release-group/quality tags', () {
      // When the last segment is not a language code, the title must not be
      // mistaken for one.
      expect(detectSubtitleLanguage('Movie.2020.1080p.srt'), isNull);
      expect(detectSubtitleLanguage('Movie.2020.BluRay.srt'), isNull);
      expect(detectSubtitleLanguage('Movie.Title.DVDRip.srt'), isNull);
    });

    test('subtitle language still recognises real tags after quality markers',
        () {
      expect(detectSubtitleLanguage('Movie.2020.1080p.eng.srt'), 'en');
      expect(detectSubtitleLanguage('Movie.2020.BluRay.fra.srt'), 'fr');
      expect(detectSubtitleLanguage('Movie.Title.DVDRip.en.srt'), 'en');
    });

    test('isPrivateIp treats IPv4-mapped loopback as private', () {
      final service = RemoteControlService.instance;
      final address = InternetAddress('::ffff:127.0.0.1');
      expect(
        service.isPrivateIp(address),
        isTrue,
        reason: 'IPv4-mapped loopback should not be bound',
      );
    });

    test('isValidBlocklistUrl rejects localhost variants and private ranges',
        () async {
      expect(
        await BlocklistService.isValidBlocklistUrl('http://127.0.0.1/list.txt'),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
            'http://localhost./list.txt'),
        isFalse,
        reason: 'localhost with trailing dot is still localhost',
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
            'http://169.254.1.1/list.txt'),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[::ffff:127.0.0.1]/list.txt',
        ),
        isFalse,
      );
    });

    test('RSS isTorrentLink accepts .torrent URLs with query or fragment', () {
      expect(
        RssService.instance.isTorrentLink(
          'https://example.com/file.torrent?passkey=secret',
        ),
        isTrue,
      );
      expect(
        RssService.instance.isTorrentLink(
          'https://example.com/file.torrent#section',
        ),
        isTrue,
      );
    });

    test('pathCarriesToken rejects token in query or fragment', () {
      const token = 'abc123';
      expect(
        pathCarriesToken('/$token?other=abc123', token),
        isTrue,
        reason: 'query string after the token is allowed',
      );
      expect(
        pathCarriesToken('/$token#abc123', token),
        isTrue,
        reason: 'fragment after the token is allowed',
      );
      expect(pathCarriesToken('/other?token=$token', token), isFalse);
      expect(pathCarriesToken('/other#token=$token', token), isFalse);
    });

    test('naturalCompare ignores leading zeros across digit runs', () {
      final names = ['E007.mkv', 'E06.mkv', 'E8.mkv']..sort(naturalCompare);
      expect(names, ['E06.mkv', 'E007.mkv', 'E8.mkv']);
    });

    test('schedule wrap-midnight boundaries', () {
      const window = ScheduleWindow(
        start: ScheduleTime(hour: 23, minute: 0),
        end: ScheduleTime(hour: 7, minute: 0),
      );
      // Monday 06:00 is inside the wrap window (Sunday night -> Monday morning).
      expect(window.isActiveAt(DateTime(2024, 1, 1, 6, 0)), isTrue);
      // Monday 08:00 is outside.
      expect(window.isActiveAt(DateTime(2024, 1, 1, 8, 0)), isFalse);
      // Monday 23:30 is inside (Monday night).
      expect(window.isActiveAt(DateTime(2024, 1, 1, 23, 30)), isTrue);
    });
  });
}
