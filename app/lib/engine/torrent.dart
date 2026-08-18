import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';
import 'package:gravity_torrent/engine/file.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:gravity_torrent/utils/subtitles.dart';

// Torrent statuses
enum TorrentStatus {
  stopped,
  queuedToCheck,
  checking,
  queuedToDownload,
  downloading,
  queuedToSeed,
  seeding,
}

class TorrentBase {
  final int id;
  List<String>? labels;

  TorrentBase({required this.id, required this.labels});
}

// Torrent abstraction
abstract class Torrent extends TorrentBase {
  final String name;
  final double progress;
  final TorrentStatus status;
  final int size;
  final int rateDownload;
  final int rateUpload;
  final int downloadedEver;
  final int uploadedEver;
  final int eta;
  final int pieceCount;
  final List<bool> pieces;
  final int pieceSize;
  final String errorString;
  final String location;
  final bool isPrivate;
  final int addedDate;
  final String creator;
  final String comment;
  final List<File> files;
  final int peersConnected;
  final String magnetLink;
  final bool sequentialDownload;
  final bool speedLimitDownEnabled;
  final bool speedLimitUpEnabled;
  final int speedLimitDown;
  final int speedLimitUp;
  final DateTime doneDate;

  /// Info hash extracted from the magnet link, if available.
  /// Supports both BitTorrent V1 (`urn:btih:`) and V2 (`urn:btmh:`) hashes,
  /// as well as magnet URIs with multiple `xt` parameters.
  String? get hash {
    if (magnetLink.isEmpty) return null;
    try {
      final uri = Uri.parse(magnetLink);
      final xtList = uri.queryParametersAll['xt'];
      if (xtList != null) {
        for (final xt in xtList) {
          final xtLower = xt.toLowerCase();
          if (xtLower.startsWith('urn:btih:')) {
            return xt.substring(9);
          } else if (xtLower.startsWith('urn:btmh:')) {
            return xt.substring(9);
          }
        }
      }
    } catch (_) {
      // Ignore malformed magnet links.
    }
    return null;
  }

  Torrent({
    required super.id,
    required super.labels,
    required this.name,
    required this.progress,
    required this.status,
    required this.size,
    required this.rateDownload,
    required this.rateUpload,
    required this.downloadedEver,
    required this.uploadedEver,
    required this.eta,
    required this.pieces,
    required this.pieceSize,
    required this.errorString,
    required this.pieceCount,
    required this.location,
    required this.isPrivate,
    required this.addedDate,
    required this.comment,
    required this.creator,
    required this.files,
    required this.peersConnected,
    required this.magnetLink,
    required this.sequentialDownload,
    required this.speedLimitDownEnabled,
    required this.speedLimitUpEnabled,
    required this.speedLimitDown,
    required this.speedLimitUp,
    required this.doneDate,
  });

  // Start the torrent
  Future<void> start();

  // Start the torrent immediately, bypassing the queue
  Future<void> startNow();

  // Pause the torrent
  Future<void> stop();

  // Force a re-check of the torrent data
  Future<void> verify();

  // Ask trackers for new peers
  Future<void> reannounce();

  // Remove the torrent
  @mustCallSuper
  Future<void> remove(bool withData) async {
    await SharedPrefsStorage.remove(_streamingActiveKey);
  }

  // Update torrent data
  Future<void> update(TorrentBase torrent);

  Future<void> toggleFileWanted(int fileIndex, bool wanted);

  Future<void> toggleAllFilesWanted(bool wanted);

  Future<void> setFilesWanted(List<int> fileIndices, bool wanted);

  Future<void> setSequentialDownload(bool sequential);

  Future<void> setSequentialDownloadFromPiece(int sequentialDownloadFromPiece);

  Future<void> setSpeedLimits({
    required bool downloadEnabled,
    required bool uploadEnabled,
    int? downloadLimitKbps,
    int? uploadLimitKbps,
  });

  Future<void> setFilesPriority({
    List<int>? priorityHigh,
    List<int>? priorityLow,
    List<int>? priorityNormal,
  });

  Future<void> setSeedRatioMode(int mode);

  Future<void> setSeedRatioLimit(double limit);

  Future<void> setSeedIdleMode(int mode);

  Future<void> setSeedIdleLimit(int limit);

  Future<void> setHonorsSessionLimits(bool honors);

  Future<void> setQueuePosition(int position);

  Future<void> setPriorityPieces(List<int> pieceIndices, int priority);

  String get _streamingActiveKey => 'streaming_active_$id';

  Future<void> startStreaming(File file) async {
    if (kDebugMode) debugPrint('starting streaming ${file.name}');
    final fileIndex = files.indexWhere((f) => f.name == file.name);
    if (fileIndex == -1) {
      throw StateError(
        'Streaming file ${file.name} not found in torrent $name',
      );
    }

    // Be sure torrent is active
    await start();

    await SharedPrefsStorage.setBool(_streamingActiveKey, true);

    // File indices for streaming file and detected associated subtitles
    final List<int> highPriorityFileIndices = [fileIndex];

    // Want subtitles and set them to high priority
    final externalSubtitles = getExternalSubtitles(file, this);
    for (final (index, torrentFile) in files.indexed) {
      if (externalSubtitles
              .firstWhereOrNull((f) => f.name == torrentFile.name) !=
          null) {
        highPriorityFileIndices.add(index);
      }
    }

    await setFilesWanted(highPriorityFileIndices, true);

    // Set high priority for streaming file and subtitles
    await setFilesPriority(priorityHigh: highPriorityFileIndices);

    await setSequentialDownload(true);
  }

  Future<void> stopStreaming() async {
    if (kDebugMode) debugPrint('stopping streaming');
    final wasActive =
        await SharedPrefsStorage.getBool(_streamingActiveKey) ?? false;
    if (!wasActive) return;

    await setSequentialDownload(false);

    // Reset all files to normal priority so piece scheduling is not biased
    // toward the previously-streamed file after streaming ends.
    if (files.isNotEmpty) {
      final allFileIndices = List.generate(files.length, (index) => index);
      await setFilesPriority(priorityNormal: allFileIndices);
    }

    await SharedPrefsStorage.setBool(_streamingActiveKey, false);
  }

  bool hasLoadedPieces(List<int> piecesToTest) {
    return piecesToTest.every((p) => p >= 0 && p < pieces.length && pieces[p]);
  }

  Future<void> openFolder(BuildContext context) async {
    late OpenResult result;
    String folderPath;

    // Determine the common parent directory of every file in the torrent.
    // Torrent file names always use POSIX (forward-slash) separators, so
    // split with the POSIX context regardless of the host platform.
    String? commonFolder;
    for (final file in files) {
      final normalizedFileName = file.name.replaceAll('\\', '/');
      final parts = posix.split(normalizedFileName);
      if (parts.length <= 1) {
        commonFolder = null;
        break;
      }
      final first = parts.first;
      if (first == '.' || first.isEmpty || first == '/' || first == '..') {
        commonFolder = null;
        break;
      }
      if (commonFolder == null) {
        commonFolder = first;
      } else if (commonFolder != first) {
        commonFolder = null;
        break;
      }
    }

    final isWindowsPath = Platform.isWindows || location.contains('\\');
    final pContext = isWindowsPath ? windows : posix;

    if (commonFolder != null && commonFolder.isNotEmpty) {
      folderPath = pContext.normalize(pContext.join(location, commonFolder));
    } else {
      folderPath = pContext.normalize(location);
    }

    try {
      result = await OpenFile.open(folderPath);
    } catch (e) {
      result = OpenResult(type: ResultType.error, message: e.toString());
    }

    if (result.type != ResultType.done) {
      final errorMessage = switch (result.type) {
        ResultType.noAppToOpen => 'No app to open',
        ResultType.fileNotFound => 'Not found',
        ResultType.permissionDenied => 'Permission denied',
        // It seems fileNotFound is not returned on linux
        ResultType.error => Directory(folderPath).existsSync() == false
            ? 'Folder not found'
            : result.message.isNotEmpty
                ? result.message
                : 'Unknown error',
        _ => 'Unknown error',
      };

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening torrent location: $errorMessage.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
