import 'package:gravity_torrent/engine/file.dart' as torrent_file;
import 'package:path/path.dart' as p;

/// Extensions the built-in player can stream.
const Set<String> playableVideoExtensions = {
  '.mp4',
  '.mkv',
  '.avi',
  '.mov',
  '.wmv',
  '.flv',
  '.webm',
  '.m4v',
  '.mpg',
  '.mpeg',
  '.3gp',
  '.ts',
  '.m2ts',
  '.ogv',
};

const Set<String> playableAudioExtensions = {
  '.mp3',
  '.flac',
  '.aac',
  '.ogg',
  '.wma',
  '.wav',
  '.m4a',
  '.opus',
  '.aiff',
};

/// True when [name] looks like a media file the player can open.
bool isPlayableMedia(String name) {
  final extension = p.extension(name).toLowerCase();
  return playableVideoExtensions.contains(extension) ||
      playableAudioExtensions.contains(extension);
}

/// True when [name] is very likely a sample/trailer rather than the feature.
///
/// Release groups ship a short `sample` clip alongside the real file; auto-play
/// should never jump to it.
bool isSampleFile(String name) {
  final base = p.basenameWithoutExtension(name).toLowerCase();
  return RegExp(r'(^|[^a-z0-9])sample([^a-z0-9]|$)').hasMatch(base);
}

/// Compares two file names the way a human would order them.
///
/// Digit runs are compared numerically so `Episode 2` sorts before
/// `Episode 10`, which a plain lexicographic sort gets wrong. Comparison is
/// case-insensitive and falls back to the raw string for exact ties so the
/// ordering is total and stable.
int naturalCompare(String a, String b) {
  final left = a.toLowerCase();
  final right = b.toLowerCase();

  var i = 0;
  var j = 0;
  while (i < left.length && j < right.length) {
    final leftChar = left.codeUnitAt(i);
    final rightChar = right.codeUnitAt(j);
    final leftIsDigit = _isDigit(leftChar);
    final rightIsDigit = _isDigit(rightChar);

    if (leftIsDigit && rightIsDigit) {
      final leftEnd = _endOfDigitRun(left, i);
      final rightEnd = _endOfDigitRun(right, j);

      // Compare by numeric value; leading zeros must not change the order.
      final leftDigits = _stripLeadingZeros(left.substring(i, leftEnd));
      final rightDigits = _stripLeadingZeros(right.substring(j, rightEnd));

      if (leftDigits.length != rightDigits.length) {
        return leftDigits.length - rightDigits.length;
      }
      final digitComparison = leftDigits.compareTo(rightDigits);
      if (digitComparison != 0) return digitComparison;

      i = leftEnd;
      j = rightEnd;
      continue;
    }

    if (leftChar != rightChar) return leftChar - rightChar;
    i++;
    j++;
  }

  final remaining = (left.length - i) - (right.length - j);
  if (remaining != 0) return remaining;
  return a.compareTo(b);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

int _endOfDigitRun(String value, int start) {
  var end = start;
  while (end < value.length && _isDigit(value.codeUnitAt(end))) {
    end++;
  }
  return end;
}

String _stripLeadingZeros(String digits) {
  final stripped = digits.replaceFirst(RegExp(r'^0+'), '');
  return stripped.isEmpty ? '0' : stripped;
}

/// Selects the playable media files of a torrent in natural playback order.
///
/// Samples are excluded unless they are the only playable files, so a
/// sample-only torrent still plays instead of yielding an empty queue.
List<torrent_file.File> orderedPlayableFiles(
  List<torrent_file.File> files,
) {
  final playable = files.where((f) => isPlayableMedia(f.name)).toList();
  final withoutSamples = playable.where((f) => !isSampleFile(f.name)).toList();
  final selected = withoutSamples.isEmpty ? playable : withoutSamples;
  selected.sort((a, b) => naturalCompare(a.name, b.name));
  return selected;
}
