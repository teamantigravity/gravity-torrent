import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/utils/subtitles.dart';

void main() {
  group('isSubtitleFileName', () {
    test('accepts all supported subtitle extensions', () {
      for (final ext in subtitleExtensions) {
        expect(isSubtitleFileName('movie$ext'), isTrue, reason: ext);
        expect(
          isSubtitleFileName('movie${ext.toUpperCase()}'),
          isTrue,
          reason: ext,
        );
      }
    });

    test('rejects unrelated extensions', () {
      expect(isSubtitleFileName('movie.mp4'), isFalse);
      expect(isSubtitleFileName('movie.txt'), isFalse);
    });
  });

  group('detectSubtitleLanguage', () {
    test('detects a 2-letter ISO 639-1 code separated by a dot', () {
      expect(detectSubtitleLanguage('movie.en.srt'), 'en');
    });

    test('detects a 3-letter language code and normalizes it', () {
      expect(detectSubtitleLanguage('movie.eng.srt'), 'en');
    });

    test('detects a full English language name and normalizes it', () {
      expect(detectSubtitleLanguage('movie.English.srt'), 'en');
    });

    test('detects a language tag separated by an underscore', () {
      expect(detectSubtitleLanguage('movie_fr.srt'), 'fr');
    });

    test('detects a language tag wrapped in brackets', () {
      expect(detectSubtitleLanguage('movie[en].srt'), 'en');
    });

    test('detects a language tag in a longer delimited file name', () {
      expect(detectSubtitleLanguage('Show.Name.S01E02.1080p.fra.srt'), 'fr');
    });

    test('returns null when no language tag is present', () {
      expect(detectSubtitleLanguage('movie.srt'), isNull);
    });

    test(
      'does not misdetect a short undelimited movie title as a language',
      () {
        expect(detectSubtitleLanguage('Up.srt'), isNull);
        expect(detectSubtitleLanguage('Room.srt'), isNull);
      },
    );
  });
}
