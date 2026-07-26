import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/engine/file.dart' as torrent_file;
import 'package:gravity_torrent/utils/media_queue.dart';

torrent_file.File _file(String name) => torrent_file.File(
      name: name,
      length: 1000,
      bytesCompleted: 0,
      wanted: true,
      beginPiece: 0,
      endPiece: 1,
    );

void main() {
  group('isPlayableMedia', () {
    test('accepts common video and audio containers', () {
      expect(isPlayableMedia('movie.mkv'), isTrue);
      expect(isPlayableMedia('MOVIE.MP4'), isTrue);
      expect(isPlayableMedia('track.flac'), isTrue);
    });

    test('rejects non-media files', () {
      expect(isPlayableMedia('readme.txt'), isFalse);
      expect(isPlayableMedia('archive.zip'), isFalse);
      expect(isPlayableMedia('subs.srt'), isFalse);
      expect(isPlayableMedia('noextension'), isFalse);
    });
  });

  group('isSampleFile', () {
    test('detects delimited sample markers', () {
      expect(isSampleFile('Show.S01E01-sample.mkv'), isTrue);
      expect(isSampleFile('sample.mkv'), isTrue);
      expect(isSampleFile('Movie.2020.SAMPLE.mp4'), isTrue);
    });

    test('does not treat words containing "sample" as samples', () {
      expect(isSampleFile('Sampler.Session.mkv'), isFalse);
      expect(isSampleFile('Resample.mkv'), isFalse);
    });
  });

  group('naturalCompare', () {
    test('orders numbers by value rather than lexicographically', () {
      final names = [
        'Show E10.mkv',
        'Show E2.mkv',
        'Show E1.mkv',
      ]..sort(naturalCompare);
      expect(names, [
        'Show E1.mkv',
        'Show E2.mkv',
        'Show E10.mkv',
      ]);
    });

    test('ignores leading zeros when comparing values', () {
      // Zero-padding must not change where an episode lands.
      expect(naturalCompare('E007.mkv', 'E8.mkv'), lessThan(0));
      expect(naturalCompare('E007.mkv', 'E6.mkv'), greaterThan(0));

      final names = ['E8.mkv', 'E007.mkv', 'E06.mkv']..sort(naturalCompare);
      expect(names, ['E06.mkv', 'E007.mkv', 'E8.mkv']);
    });

    test('compares case-insensitively before falling back to raw bytes', () {
      // A byte-wise sort would place every uppercase name before every
      // lowercase one; natural order must interleave them.
      final names = ['beta.mkv', 'Alpha.mkv', 'Gamma.mkv', 'delta.mkv']
        ..sort(naturalCompare);
      expect(names, ['Alpha.mkv', 'beta.mkv', 'delta.mkv', 'Gamma.mkv']);
    });

    test('breaks case-only ties deterministically', () {
      final forward = naturalCompare('episode1.mkv', 'EPISODE1.mkv');
      final backward = naturalCompare('EPISODE1.mkv', 'episode1.mkv');
      expect(forward, isNot(0));
      expect(forward.sign, -backward.sign);
    });

    test('sorts seasons before episodes', () {
      final names = [
        'S02E01.mkv',
        'S01E10.mkv',
        'S01E02.mkv',
      ]..sort(naturalCompare);
      expect(names, ['S01E02.mkv', 'S01E10.mkv', 'S02E01.mkv']);
    });

    test('is a total order for equal-ignoring-case names', () {
      expect(naturalCompare('a.mkv', 'a.mkv'), 0);
      expect(naturalCompare('a.mkv', 'b.mkv'), lessThan(0));
      expect(naturalCompare('b.mkv', 'a.mkv'), greaterThan(0));
    });
  });

  group('orderedPlayableFiles', () {
    test('keeps only playable media, in natural order, without samples', () {
      final files = [
        _file('Show/Show.S01E10.mkv'),
        _file('Show/readme.txt'),
        _file('Show/Show.S01E02.mkv'),
        _file('Show/Show.S01E01-sample.mkv'),
        _file('Show/Show.S01E01.mkv'),
      ];

      expect(
        orderedPlayableFiles(files).map((f) => f.name),
        [
          'Show/Show.S01E01.mkv',
          'Show/Show.S01E02.mkv',
          'Show/Show.S01E10.mkv',
        ],
      );
    });

    test('falls back to samples when they are the only playable files', () {
      final files = [
        _file('Show/notes.txt'),
        _file('Show/sample.mkv'),
      ];
      expect(
        orderedPlayableFiles(files).map((f) => f.name),
        ['Show/sample.mkv'],
      );
    });

    test('returns an empty list when nothing is playable', () {
      expect(orderedPlayableFiles([_file('a.txt')]), isEmpty);
    });

    test('does not mutate the caller list', () {
      final files = [_file('b.mkv'), _file('a.mkv')];
      orderedPlayableFiles(files);
      expect(files.map((f) => f.name), ['b.mkv', 'a.mkv']);
    });
  });
}
