import 'dart:async';

import 'package:collection/collection.dart';
import 'package:gravity_torrent/engine/file.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/utils/torrent_utils.dart';

const subtitleExtensions = <String>{
  '.srt',
  '.vtt',
  '.ass',
  '.ssa',
  '.sub',
  '.idx',
};

int countSlashesRegex(String text) {
  final regex = RegExp('/');
  return regex.allMatches(text).length;
}

String truncateFromLastSlash(String text) {
  int lastSlashIndex = text.lastIndexOf('/');
  if (lastSlashIndex != -1) {
    return text.substring(lastSlashIndex + 1);
  } else {
    return text;
  }
}

/// Returns the extension of [fileName] including the leading dot, or empty.
String _fileExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot == -1 ? '' : fileName.substring(dot).toLowerCase();
}

/// Whether [fileName] has one of the [subtitleExtensions].
bool isSubtitleFileName(String fileName) =>
    subtitleExtensions.contains(_fileExtension(fileName));

/// Tries to extract a BCP-47 / ISO 639-1 language tag from a subtitle file name.
///
/// Examples:
///   movie.en.srt     -> en
///   movie.eng.srt    -> eng
///   movie.English.srt -> en
///   movie_fr.srt     -> fr
///   movie[en].srt    -> en
///   movie.srt        -> null
String? detectSubtitleLanguage(String fileName) {
  final base =
      fileName.substring(0, fileName.length - _fileExtension(fileName).length);
  // Split on common subtitle delimiters: . _ - space [ ] ( )
  final parts = base.split(RegExp(r'[\]\s_\-.\[()]+'));
  // A lone, undelimited base (e.g. "movie.srt" -> "movie") has no distinct
  // language suffix to extract. Treating the whole title as a language code
  // would false-positive on short movie titles (e.g. "Up", "Room").
  if (parts.length < 2) return null;
  final tag = parts.reversed.firstWhere(
    (p) => p.isNotEmpty && RegExp(r'^[a-zA-Z]{2,7}$').hasMatch(p),
    orElse: () => '',
  );
  if (tag.isNotEmpty) {
    return _normalizeLanguageTag(tag.toLowerCase());
  }
  return null;
}

String? _normalizeLanguageTag(String tag) {
  // Handle common 3-letter English language names by mapping to ISO 639-1 codes.
  const knownNames = {
    'eng': 'en',
    'english': 'en',
    'spa': 'es',
    'spanish': 'es',
    'fra': 'fr',
    'fre': 'fr',
    'french': 'fr',
    'deu': 'de',
    'ger': 'de',
    'german': 'de',
    'ita': 'it',
    'italian': 'it',
    'por': 'pt',
    'portuguese': 'pt',
    'rus': 'ru',
    'russian': 'ru',
    'jpn': 'ja',
    'japanese': 'ja',
    'zho': 'zh',
    'chi': 'zh',
    'chinese': 'zh',
    'kor': 'ko',
    'korean': 'ko',
    'ara': 'ar',
    'arabic': 'ar',
    'hin': 'hi',
    'hindi': 'hi',
    'tur': 'tr',
    'turkish': 'tr',
    'pol': 'pl',
    'polish': 'pl',
    'nld': 'nl',
    'dut': 'nl',
    'dutch': 'nl',
    'swe': 'sv',
    'swedish': 'sv',
    'ukr': 'uk',
    'ukrainian': 'uk',
    'ces': 'cs',
    'cze': 'cs',
    'czech': 'cs',
    'ron': 'ro',
    'rum': 'ro',
    'romanian': 'ro',
    'hun': 'hu',
    'hungarian': 'hu',
    'ell': 'el',
    'gre': 'el',
    'greek': 'el',
    'dan': 'da',
    'danish': 'da',
    'fin': 'fi',
    'finnish': 'fi',
    'heb': 'he',
    'hebrew': 'he',
    'ind': 'id',
    'indonesian': 'id',
    'vie': 'vi',
    'vietnamese': 'vi',
  };
  return knownNames[tag] ?? tag;
}

List<File> getExternalSubtitles(File file, Torrent torrent) {
  final slashesCount = countSlashesRegex(file.name);
  final externalSubtitlesFiles = torrent.files
      .where((f) =>
          slashesCount == countSlashesRegex(f.name) &&
          isSubtitleFileName(f.name))
      .toList();

  return externalSubtitlesFiles;
}

downloadSubtitles(File file, Torrent torrent) async {
  final List<File> subtitles = getExternalSubtitles(file, torrent);
  for (var sub in subtitles) {
    await torrent.setSequentialDownloadFromPiece(sub.beginPiece);
    await _waitForFileComplete(torrent: torrent, fileName: sub.name);
  }
}

Future<void> _waitForFileComplete(
    {required Torrent torrent, required String fileName}) async {
  final file = torrent.files.firstWhereOrNull((f) => f.name == fileName);
  if (file == null) return;
  final pieceCount = file.endPiece - file.beginPiece;
  await waitForPieces(torrent: torrent, file: file, pieceCount: pieceCount);
}

class ExternalSubtitle {
  final String url;
  final String name;
  final String? language;

  ExternalSubtitle({required this.url, required this.name, this.language});
}
