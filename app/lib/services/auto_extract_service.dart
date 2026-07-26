import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

class AutoExtractService extends ChangeNotifier {
  static const _keyEnabled = 'auto_extract_enabled';
  static const _keyDestination = 'auto_extract_destination';

  static final AutoExtractService instance = AutoExtractService._();

  AutoExtractService._() {
    _autoExtractEnabled = SharedPrefs.getBool(_keyEnabled) ?? false;
    _destinationFolder = SharedPrefs.getString(_keyDestination) ?? '';
  }

  bool _autoExtractEnabled = false;
  String _destinationFolder = '';
  bool _disposed = false;
  final Set<String> _extracting = {};

  bool get autoExtractEnabled => _autoExtractEnabled;
  String get destinationFolder => _destinationFolder;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void setAutoExtractEnabled(bool value) {
    if (_disposed) return;
    _autoExtractEnabled = value;
    unawaited(SharedPrefs.setBool(_keyEnabled, value));
    _safeNotify();
  }

  void setDestinationFolder(String value) {
    if (_disposed) return;
    _destinationFolder = value;
    unawaited(SharedPrefs.setString(_keyDestination, value));
    _safeNotify();
  }

  Future<void> handleTorrentCompletion(
    String torrentName,
    String filePath,
  ) async {
    if (kIsWeb || !_autoExtractEnabled || _disposed) return;

    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.zip') ||
        lowerPath.endsWith('.tar') ||
        lowerPath.endsWith('.gz') ||
        lowerPath.endsWith('.tgz') ||
        lowerPath.endsWith('.tar.gz') ||
        lowerPath.endsWith('.bz2') ||
        lowerPath.endsWith('.rar') ||
        lowerPath.endsWith('.7z')) {
      if (!_extracting.add(filePath)) return;
      debugPrint(
        'AutoExtractService: Initiating extraction for $torrentName at $filePath',
      );

      final destDir = _destinationFolder.isEmpty
          ? File(filePath).parent.path
          : _destinationFolder;

      final targetFolder = Directory('$destDir/$torrentName');

      try {
        await targetFolder.create(recursive: true);
        if (lowerPath.endsWith('.zip') ||
            lowerPath.endsWith('.tar.gz') ||
            lowerPath.endsWith('.tgz') ||
            lowerPath.endsWith('.tar') ||
            lowerPath.endsWith('.gz') ||
            lowerPath.endsWith('.bz2') ||
            lowerPath.endsWith('.rar') ||
            lowerPath.endsWith('.7z')) {
          if (lowerPath.endsWith('.gz') && !lowerPath.endsWith('.tar.gz')) {
            // Single gzipped file - handled via streaming
            final inputStream = InputFileStream(filePath);
            final outPath =
                '${targetFolder.parent.path}/${torrentName.replaceFirst(RegExp(r'\.gz$'), '')}';
            await targetFolder.parent.create(recursive: true);
            try {
            final outputStream = OutputFileStream(outPath);
            try {
              const GZipDecoder().decodeStream(inputStream, outputStream);
            } finally {
              await outputStream.close();
              await inputStream.close();
            }
              final outFile = File(outPath);
              if (!outFile.existsSync() || outFile.lengthSync() == 0) {
                throw StateError('GZip decompression produced no output');
              }
            } catch (e) {
              try {
                final outFile = File(outPath);
                if (outFile.existsSync()) outFile.deleteSync();
              } catch (_) {}
              rethrow;
            }
          } else {
            // Archive extraction using memory-efficient and zip-slip protected extractFileToDisk
            await extractFileToDisk(filePath, targetFolder.path);
          }
        }
        debugPrint('AutoExtractService: Extraction complete for $torrentName');
      } catch (e) {
        debugPrint('AutoExtractService: Error extracting $torrentName: $e');
      } finally {
        _extracting.remove(filePath);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
