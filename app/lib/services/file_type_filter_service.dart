import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/engine/file.dart' as torrent_file;
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

enum FileTypeCategory {
  all,
  video,
  audio,
  image,
  document,
  archive,
  executable,
  other,
}

class FileTypeFilterService {
  FileTypeFilterService._();

  static const Map<FileTypeCategory, Set<String>> _extensionMap = {
    FileTypeCategory.video: {
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
      '.vob',
      '.ogv',
    },
    FileTypeCategory.audio: {
      '.mp3',
      '.flac',
      '.aac',
      '.ogg',
      '.wma',
      '.wav',
      '.m4a',
      '.opus',
      '.alac',
      '.aiff',
      '.ape',
      '.wv',
    },
    FileTypeCategory.image: {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.svg',
      '.tiff',
      '.ico',
      '.heic',
      '.heif',
      '.avif',
      '.raw',
    },
    FileTypeCategory.document: {
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
      '.rtf',
      '.odt',
      '.ods',
      '.odp',
      '.epub',
      '.mobi',
      '.csv',
    },
    FileTypeCategory.archive: {
      '.zip',
      '.rar',
      '.7z',
      '.tar',
      '.gz',
      '.bz2',
      '.xz',
      '.iso',
      '.dmg',
      '.cab',
      '.lzma',
      '.zst',
    },
    FileTypeCategory.executable: {
      '.exe',
      '.msi',
      '.app',
      '.apk',
      '.deb',
      '.rpm',
      '.sh',
      '.bat',
      '.cmd',
      '.ps1',
    },
  };

  /// Determine the category for a file by extension.
  static FileTypeCategory categorize(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    if (ext.isEmpty) return FileTypeCategory.other;

    for (final entry in _extensionMap.entries) {
      if (entry.value.contains(ext)) return entry.key;
    }
    return FileTypeCategory.other;
  }

  /// Filter a list of torrents by the dominant file type category.
  static List<Torrent> filterTorrents(
    List<Torrent> torrents,
    FileTypeCategory category, {
    required List<torrent_file.File> Function(Torrent) getFiles,
  }) {
    if (category == FileTypeCategory.all) return torrents;

    return torrents.where((t) {
      final files = getFiles(t);
      if (files.isEmpty) return false;

      // Find the largest file's category
      torrent_file.File? largest;
      for (final f in files) {
        if (largest == null || f.length > largest.length) {
          largest = f;
        }
      }

      return largest != null && categorize(largest.name) == category;
    }).toList();
  }

  /// Filter files within a torrent by category.
  static List<torrent_file.File> filterFiles(
    List<torrent_file.File> files,
    FileTypeCategory category,
  ) {
    if (category == FileTypeCategory.all) return files;
    return files.where((f) => categorize(f.name) == category).toList();
  }

  /// Get category breakdown for a list of torrents.
  static Map<FileTypeCategory, int> getCategoryCounts(
    List<Torrent> torrents, {
    required List<torrent_file.File> Function(Torrent) getFiles,
  }) {
    final counts = <FileTypeCategory, int>{};
    for (final category in FileTypeCategory.values) {
      if (category == FileTypeCategory.all) continue;
      counts[category] = filterTorrents(
        torrents,
        category,
        getFiles: getFiles,
      ).length;
    }
    return counts;
  }

  static IconData iconFor(FileTypeCategory category) {
    return switch (category) {
      FileTypeCategory.all => Icons.apps,
      FileTypeCategory.video => Icons.movie,
      FileTypeCategory.audio => Icons.music_note,
      FileTypeCategory.image => Icons.image,
      FileTypeCategory.document => Icons.description,
      FileTypeCategory.archive => Icons.archive,
      FileTypeCategory.executable => Icons.terminal,
      FileTypeCategory.other => Icons.insert_drive_file,
    };
  }

  static String nameFor(FileTypeCategory category, AppLocalizations l) {
    return switch (category) {
      FileTypeCategory.all => l.fileTypeAll,
      FileTypeCategory.video => l.fileTypeVideo,
      FileTypeCategory.audio => l.fileTypeAudio,
      FileTypeCategory.image => l.fileTypeImage,
      FileTypeCategory.document => l.fileTypeDocument,
      FileTypeCategory.archive => l.fileTypeArchive,
      FileTypeCategory.executable => l.fileTypeExecutable,
      FileTypeCategory.other => l.fileTypeOther,
    };
  }
}
