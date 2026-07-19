import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_libtransmission/flutter_libtransmission.dart'
    as flutter_libtransmission;
import 'package:path_provider/path_provider.dart';
import 'package:gravity_torrent/engine/file.dart' as torrent_file;
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/main.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/engine/transmission/models/session_get_request.dart';
import 'package:gravity_torrent/engine/transmission/models/session_get_response.dart';
import 'package:gravity_torrent/engine/transmission/models/session_set_request.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_action_request.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_add_request.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_add_response.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_get_request.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_get_response.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_remove_request.dart';
import 'package:path/path.dart' as path;
import 'package:gravity_torrent/engine/transmission/models/torrent_set_location.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_set_request.dart';
import 'package:gravity_torrent/platforms/android/default_session.dart'
    as android;
import 'package:gravity_torrent/platforms/ios/default_session.dart' as ios;

Future<Directory> getConfigDir() async {
  final configDir = path.join(
    (await getApplicationSupportDirectory()).path,
    'transmission',
  );
  return Directory(configDir);
}

const torrentGetFields = [
  TorrentField.id,
  TorrentField.name,
  TorrentField.percentDone,
  TorrentField.status,
  TorrentField.totalSize,
  TorrentField.rateDownload,
  TorrentField.rateUpload,
  TorrentField.labels,
  TorrentField.addedDate,
  TorrentField.errorString,
  TorrentField.isPrivate,
  TorrentField.downloadDir,
  TorrentField.files,
  TorrentField.fileStats,
  TorrentField.downloadedEver,
  TorrentField.uploadedEver,
  TorrentField.eta,
  TorrentField.pieces,
  TorrentField.pieceSize,
  TorrentField.pieceCount,
  TorrentField.comment,
  TorrentField.creator,
  TorrentField.peersConnected,
  TorrentField.magnetLink,
  TorrentField.sequentialDownload,
  TorrentField.speedLimitDownEnabled,
  TorrentField.speedLimitUpEnabled,
  TorrentField.speedLimitDown,
  TorrentField.speedLimitUp,
  TorrentField.doneDate,
  TorrentField.leftUntilDone,
  TorrentField.sizeWhenDone,
];

TransmissionTorrent createTransmissionTorrentFromJson(
  TransmissionTorrentModel torrent,
) {
  return TransmissionTorrent(
    id: torrent.id,
    name: torrent.name,
    progress: torrent.sizeWhenDone > 0
        ? (torrent.sizeWhenDone - torrent.leftUntilDone) / torrent.sizeWhenDone
        : 0.0,
    status: torrent.status,
    size: torrent.totalSize,
    rateDownload: torrent.rateDownload,
    rateUpload: torrent.rateUpload,
    labels: torrent.labels,
    addedDate: torrent.addedDate,
    errorString: torrent.errorString,
    magnetLink: torrent.magnetLink,
    isPrivate: torrent.isPrivate,
    location: torrent.location,
    files: torrent.files
        .asMap()
        .entries
        .map(
          (entry) => torrent_file.File(
            name: entry.value.name,
            length: entry.value.length,
            bytesCompleted: entry.value.bytesCompleted,
            // fileStats and files are parallel arrays; guard against a
            // transient length mismatch to avoid a RangeError.
            wanted: entry.key < torrent.fileStats.length
                ? torrent.fileStats[entry.key].wanted
                : true,
            beginPiece: entry.value.beginPiece,
            endPiece: entry.value.endPiece,
          ),
        )
        .toList(),
    downloadedEver: torrent.downloadedEver,
    uploadedEver: torrent.uploadedEver,
    eta: torrent.eta,
    pieces: torrent.pieces,
    pieceCount: torrent.pieceCount,
    pieceSize: torrent.pieceSize,
    comment: torrent.comment,
    creator: torrent.creator,
    peersConnected: torrent.peersConnected,
    sequentialDownload: torrent.sequentialDownload,
    speedLimitDownEnabled: torrent.speedLimitDownEnabled,
    speedLimitUpEnabled: torrent.speedLimitUpEnabled,
    speedLimitDown: torrent.speedLimitDown,
    speedLimitUp: torrent.speedLimitUp,
    doneDate: torrent.doneDate,
  );
}

final TorrentGetRequest torrentGetRequest = TorrentGetRequest(
  arguments: TorrentGetRequestArguments(
    fields: [
      TorrentField.id,
      TorrentField.name,
      TorrentField.percentDone,
      TorrentField.status,
      TorrentField.totalSize,
      TorrentField.rateDownload,
      TorrentField.rateUpload,
      TorrentField.labels,
      TorrentField.addedDate,
      TorrentField.errorString,
      TorrentField.isPrivate,
      TorrentField.downloadDir,
      TorrentField.files,
      TorrentField.fileStats,
      TorrentField.downloadedEver,
      TorrentField.uploadedEver,
      TorrentField.eta,
      TorrentField.pieces,
      TorrentField.pieceSize,
      TorrentField.pieceCount,
      TorrentField.comment,
      TorrentField.creator,
      TorrentField.peersConnected,
      TorrentField.magnetLink,
      TorrentField.sequentialDownload,
      TorrentField.speedLimitDownEnabled,
      TorrentField.speedLimitUpEnabled,
      TorrentField.speedLimitDown,
      TorrentField.speedLimitUp,
      TorrentField.doneDate,
    ],
  ),
);

class TransmissionTorrent extends Torrent {
  TransmissionTorrent({
    required super.id,
    required super.name,
    required super.progress,
    required super.status,
    required super.size,
    required super.rateDownload,
    required super.rateUpload,
    required super.downloadedEver,
    required super.uploadedEver,
    required super.eta,
    required super.pieces,
    required super.pieceCount,
    required super.pieceSize,
    required super.errorString,
    required super.addedDate,
    required super.isPrivate,
    required super.location,
    required super.creator,
    required super.comment,
    required super.files,
    required super.labels,
    required super.peersConnected,
    required super.magnetLink,
    required super.sequentialDownload,
    required super.speedLimitDownEnabled,
    required super.speedLimitUpEnabled,
    required super.speedLimitDown,
    required super.speedLimitUp,
    required super.doneDate,
  });

  @override
  Future<void> start() async {
    var request = TorrentActionRequest(
      action: TorrentAction.start,
      arguments: TorrentActionRequestArguments(ids: [id]),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future<void> stop() async {
    var request = TorrentActionRequest(
      action: TorrentAction.stop,
      arguments: TorrentActionRequestArguments(ids: [id]),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future<void> remove(bool withData) async {
    var request = TorrentRemoveRequest(
      arguments: TorrentRemoveRequestArguments(
        ids: [id],
        deleteLocalData: withData,
      ),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future update(TorrentBase torrent) async {
    var request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(ids: [id], labels: torrent.labels),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future toggleFileWanted(int fileIndex, bool wanted) async {
    var request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [id],
        filesWanted: wanted ? [fileIndex] : null,
        filesUnwanted: !wanted ? [fileIndex] : null,
      ),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future toggleAllFilesWanted(bool wanted) async {
    final filesIndexesNotCompleted = files.indexed
        .where(
          (indexedElement) =>
              indexedElement.$2.bytesCompleted != indexedElement.$2.length,
        )
        .map((indexedElement) => indexedElement.$1)
        .toList();

    final request = TorrentSetRequest(
      arguments: wanted
          ? TorrentSetRequestArguments(
              ids: [id],
              filesWanted: filesIndexesNotCompleted,
            )
          : TorrentSetRequestArguments(
              ids: [id],
              filesUnwanted: filesIndexesNotCompleted,
            ),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future setSequentialDownload(bool sequential) async {
    var request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [id],
        sequentialDownload: sequential,
      ),
    );

    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future setSequentialDownloadFromPiece(int piece) async {
    debugPrint('setSequentialDownloadFromPiece $piece');
    var request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [id],
        sequentialDownloadFromPiece: piece,
      ),
    );

    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future setSpeedLimits({
    required bool downloadEnabled,
    required bool uploadEnabled,
    int? downloadLimitKbps,
    int? uploadLimitKbps,
  }) async {
    final request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [id],
        speedLimitDownEnabled: downloadEnabled,
        speedLimitUpEnabled: uploadEnabled,
        speedLimitDown: downloadEnabled ? downloadLimitKbps : null,
        speedLimitUp: uploadEnabled ? uploadLimitKbps : null,
      ),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }

  @override
  Future setFilesPriority({
    List<int>? priorityHigh,
    List<int>? priorityLow,
    List<int>? priorityNormal,
  }) async {
    var request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [id],
        priorityHigh: priorityHigh,
        priorityLow: priorityLow,
        priorityNormal: priorityNormal,
      ),
    );

    await flutter_libtransmission.requestAsync(jsonEncode(request));
    engine.requestCheckpoint();
  }
}

class TransmissionSession extends Session {
  TransmissionSession({
    super.downloadDir,
    super.downloadQueueEnabled,
    super.downloadQueueSize,
    super.peerPort,
    super.speedLimitDownEnabled,
    super.speedLimitUpEnabled,
    super.speedLimitDown,
    super.speedLimitUp,
    super.seedRatioLimit,
    super.seedRatioLimited,
    super.encryption,
    super.blocklistEnabled,
    super.blocklistUrl,
    super.blocklistSize,
    super.dhtEnabled,
    super.pexEnabled,
    super.lpdEnabled,
    super.utpEnabled,
    super.altSpeedEnabled,
    super.altSpeedDown,
    super.altSpeedUp,
    super.altSpeedTimeEnabled,
    super.altSpeedTimeBegin,
    super.altSpeedTimeEnd,
    super.altSpeedTimeDay,
    super.idleSeedingLimitEnabled,
    super.idleSeedingLimit,
  });

  @override
  Future<void> update(SessionBase session) async {
    SessionSetRequest request = SessionSetRequest(
      arguments: SessionSetRequestArguments(
        downloadDir: session.downloadDir,
        downloadQueueSize: session.downloadQueueSize,
        peerPort: session.peerPort,
        speedLimitDownEnabled: session.speedLimitDownEnabled,
        speedLimitUpEnabled: session.speedLimitUpEnabled,
        speedLimitDown: session.speedLimitDown,
        speedLimitUp: session.speedLimitUp,
        seedRatioLimit: session.seedRatioLimit,
        seedRatioLimited: session.seedRatioLimited,
        encryption: session.encryption?.rpcValue,
        blocklistEnabled: session.blocklistEnabled,
        blocklistUrl: session.blocklistUrl,
        dhtEnabled: session.dhtEnabled,
        pexEnabled: session.pexEnabled,
        lpdEnabled: session.lpdEnabled,
        utpEnabled: session.utpEnabled,
        altSpeedEnabled: session.altSpeedEnabled,
        altSpeedDown: session.altSpeedDown,
        altSpeedUp: session.altSpeedUp,
        altSpeedTimeEnabled: session.altSpeedTimeEnabled,
        altSpeedTimeBegin: session.altSpeedTimeBegin,
        altSpeedTimeEnd: session.altSpeedTimeEnd,
        altSpeedTimeDay: session.altSpeedTimeDay,
        idleSeedingLimitEnabled: session.idleSeedingLimitEnabled,
        idleSeedingLimit: session.idleSeedingLimit,
      ),
    );

    await flutter_libtransmission.requestAsync(jsonEncode(request));
    flutter_libtransmission.saveSettings();
  }
}

List<Torrent> _parseTorrentsResponse(String res) {
  final TorrentGetResponse decodedRes = TorrentGetResponse.fromJson(
    jsonDecode(res),
  );
  return decodedRes.arguments.torrents
      .map((torrent) {
        try {
          return createTransmissionTorrentFromJson(torrent);
        } catch (e, stack) {
          debugPrint('Failed to parse torrent: $e\n$stack');
          return null;
        }
      })
      .whereType<Torrent>()
      .toList();
}

class TransmissionEngine extends Engine {
  Timer? _checkpointTimer;
  Timer? _saveDebounce;

  void startCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await saveSession();
    });
  }

  @override
  void requestCheckpoint() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 3), () async {
      await saveSession();
    });
  }

  @override
  init() async {
    final configDir = await getConfigDir();
    flutter_libtransmission.initSession(configDir.path);
    if (Platform.isAndroid) {
      await android.initDefaultDownloadDir(this);
    }

    if (Platform.isIOS) {
      await ios.initDefaultDownloadDir(this);
      // Once done, restart session to reload torrents in error state
      await shutdown();
      flutter_libtransmission.initSession(configDir.path);
    }

    startCheckpointTimer();
  }

  @override
  Future<void> saveSession() async {
    // Saves transmission session settings to disk
    flutter_libtransmission.saveSettings();
  }

  @override
  Future<void> shutdown() async {
    _checkpointTimer?.cancel();
    _saveDebounce?.cancel();
    await saveSession();
    await Isolate.run(() => flutter_libtransmission.closeSession());
  }

  @override
  Future<TorrentAddedResponse> addTorrent(
    String? filename,
    String? metainfo,
    String? downloadDir,
  ) async {
    var torrentAddRequest = TorrentAddRequest(
      arguments: TorrentAddRequestArguments(
        filename: filename,
        metainfo: metainfo,
        downloadDir: downloadDir,
      ),
    );
    var jsonResponse = await flutter_libtransmission.requestAsync(
      jsonEncode(torrentAddRequest),
    );
    TorrentAddResponse response = TorrentAddResponse.fromJson(
      jsonDecode(jsonResponse),
    );

    if (response.result != 'success') {
      throw TorrentAddError();
    }

    if (!response.arguments.torrentAdded &&
        !response.arguments.torrentDuplicate) {
      throw TorrentAddError();
    }

    if (response.arguments.torrentDuplicate) {
      return TorrentAddedResponse.duplicated;
    }

    requestCheckpoint();
    return TorrentAddedResponse.added;
  }

  @override
  Future<List<Torrent>> fetchTorrents() async {
    String res = await flutter_libtransmission.requestAsync(
      jsonEncode(
        TorrentGetRequest(
          arguments: TorrentGetRequestArguments(fields: torrentGetFields),
        ),
      ),
    );

    return compute(_parseTorrentsResponse, res);
  }

  @override
  Future<Torrent> fetchTorrent(int id) async {
    String res = await flutter_libtransmission.requestAsync(
      jsonEncode(
        TorrentGetRequest(
          arguments: TorrentGetRequestArguments(
            ids: [id],
            fields: torrentGetFields,
          ),
        ),
      ),
    );

    final TorrentGetResponse decodedRes = TorrentGetResponse.fromJson(
      jsonDecode(res),
    );

    final torrents = decodedRes.arguments.torrents;
    if (torrents.isEmpty) {
      throw StateError('Torrent $id not found');
    }
    return createTransmissionTorrentFromJson(torrents.first);
  }

  @override
  Future<Session> fetchSession() async {
    SessionGetRequest sessionGetRequest = SessionGetRequest(
      arguments: SessionGetRequestArguments(
        fields: [
          SessionField.downloadDir,
          SessionField.downloadQueueEnabled,
          SessionField.downloadQueueSize,
          SessionField.peerPort,
          SessionField.speedLimitDownEnabled,
          SessionField.speedLimitUpEnabled,
          SessionField.speedLimitDown,
          SessionField.speedLimitUp,
          SessionField.encryption,
          SessionField.blocklistEnabled,
          SessionField.blocklistUrl,
          SessionField.blocklistSize,
          SessionField.dhtEnabled,
          SessionField.pexEnabled,
          SessionField.lpdEnabled,
          SessionField.utpEnabled,
          SessionField.seedRatioLimit,
          SessionField.seedRatioLimited,
          SessionField.altSpeedEnabled,
          SessionField.altSpeedDown,
          SessionField.altSpeedUp,
          SessionField.altSpeedTimeEnabled,
          SessionField.altSpeedTimeBegin,
          SessionField.altSpeedTimeEnd,
          SessionField.altSpeedTimeDay,
          SessionField.idleSeedingLimitEnabled,
          SessionField.idleSeedingLimit,
        ],
      ),
    );
    String res = await flutter_libtransmission.requestAsync(
      jsonEncode(sessionGetRequest),
    );

    final SessionGetResponse decodedRes = SessionGetResponse.fromJson(
      jsonDecode(res),
    );

    return TransmissionSession(
      downloadDir: decodedRes.arguments.downloadDir,
      downloadQueueEnabled: decodedRes.arguments.downloadQueueEnabled,
      downloadQueueSize: decodedRes.arguments.downloadQueueSize,
      peerPort: decodedRes.arguments.peerPort,
      speedLimitDownEnabled: decodedRes.arguments.speedLimitDownEnabled,
      speedLimitUpEnabled: decodedRes.arguments.speedLimitUpEnabled,
      speedLimitDown: decodedRes.arguments.speedLimitDown,
      speedLimitUp: decodedRes.arguments.speedLimitUp,
      encryption: EncryptionMode.fromRpcValue(decodedRes.arguments.encryption),
      blocklistEnabled: decodedRes.arguments.blocklistEnabled,
      blocklistUrl: decodedRes.arguments.blocklistUrl,
      blocklistSize: decodedRes.arguments.blocklistSize,
      dhtEnabled: decodedRes.arguments.dhtEnabled,
      pexEnabled: decodedRes.arguments.pexEnabled,
      lpdEnabled: decodedRes.arguments.lpdEnabled,
      utpEnabled: decodedRes.arguments.utpEnabled,
      seedRatioLimit: decodedRes.arguments.seedRatioLimit,
      seedRatioLimited: decodedRes.arguments.seedRatioLimited,
      altSpeedEnabled: decodedRes.arguments.altSpeedEnabled,
      altSpeedDown: decodedRes.arguments.altSpeedDown,
      altSpeedUp: decodedRes.arguments.altSpeedUp,
      altSpeedTimeEnabled: decodedRes.arguments.altSpeedTimeEnabled,
      altSpeedTimeBegin: decodedRes.arguments.altSpeedTimeBegin,
      altSpeedTimeEnd: decodedRes.arguments.altSpeedTimeEnd,
      altSpeedTimeDay: decodedRes.arguments.altSpeedTimeDay,
      idleSeedingLimitEnabled: decodedRes.arguments.idleSeedingLimitEnabled,
      idleSeedingLimit: decodedRes.arguments.idleSeedingLimit,
    );
  }

  @override
  Future resetSettings() async {
    flutter_libtransmission.resetSettings();
    if (Platform.isAndroid) {
      await android.initDefaultDownloadDir(this);
    }
    if (Platform.isIOS) {
      await ios.initDefaultDownloadDir(this);
    }
    requestCheckpoint();
  }

  @override
  Future setTorrentsLocation(
    TorrentSetLocationArguments torrentSetLocationArguments,
  ) async {
    final request = TorrentSetLocationRequest(
      arguments: torrentSetLocationArguments,
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    requestCheckpoint();
  }

  @override
  Future removeTorrents(List<int> torrentIds, bool withData) async {
    var request = TorrentRemoveRequest(
      arguments: TorrentRemoveRequestArguments(
        ids: torrentIds,
        deleteLocalData: withData,
      ),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    requestCheckpoint();
  }

  @override
  Future pauseTorrent(int id) async {
    return pauseTorrents([id]);
  }

  @override
  Future pauseTorrents(List<int> ids) async {
    if (ids.isEmpty) return;
    var request = TorrentActionRequest(
      action: TorrentAction.stop,
      arguments: TorrentActionRequestArguments(ids: ids),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    requestCheckpoint();
  }

  @override
  Future resumeTorrent(int id) async {
    return resumeTorrents([id]);
  }

  @override
  Future resumeTorrents(List<int> ids) async {
    if (ids.isEmpty) return;
    var request = TorrentActionRequest(
      action: TorrentAction.start,
      arguments: TorrentActionRequestArguments(ids: ids),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    requestCheckpoint();
  }

  @override
  Future setTorrentSpeedLimit(
    int id, {
    int? downloadLimit,
    int? uploadLimit,
  }) async {
    final downloadEnabled = downloadLimit != null && downloadLimit > 0;
    final uploadEnabled = uploadLimit != null && uploadLimit > 0;
    final request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [id],
        speedLimitDownEnabled: downloadEnabled,
        speedLimitUpEnabled: uploadEnabled,
        speedLimitDown: downloadEnabled ? downloadLimit : null,
        speedLimitUp: uploadEnabled ? uploadLimit : null,
      ),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    requestCheckpoint();
  }

  @override
  Future setTorrentSequentialDownload(int id, bool sequential) async {
    var request = TorrentSetRequest(
      arguments: TorrentSetRequestArguments(
        ids: [id],
        sequentialDownload: sequential,
      ),
    );
    await flutter_libtransmission.requestAsync(jsonEncode(request));
    requestCheckpoint();
  }
}
