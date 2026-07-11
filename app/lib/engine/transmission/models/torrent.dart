import 'dart:convert';

import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/utils/bitfield.dart';

enum TorrentField {
  id,
  name,
  status,
  percentDone,
  totalSize,
  rateDownload,
  rateUpload,
  downloadedEver,
  uploadedEver,
  eta,
  pieceCount,
  pieces,
  pieceSize,
  errorString,
  addedDate,
  downloadDir,
  isPrivate,
  creator,
  comment,
  files,
  fileStats,
  labels,
  peersConnected,
  magnetLink,
  sequentialDownload,
  speedLimitDownEnabled,
  speedLimitUpEnabled,
  speedLimitDown,
  speedLimitUp,
  doneDate,
  leftUntilDone,
  sizeWhenDone
}

class TransmissionTorrentFile {
  final String name;
  final int length;
  final int bytesCompleted;
  final int beginPiece;
  final int endPiece;

  TransmissionTorrentFile(this.name, this.length, this.bytesCompleted,
      this.beginPiece, this.endPiece);

  TransmissionTorrentFile.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        length = json['length'],
        bytesCompleted = json['bytesCompleted'],
        beginPiece = json['begin_piece'],
        endPiece = json['end_piece'];
}

class TransmissionTorrentFileStats {
  final bool wanted;

  TransmissionTorrentFileStats(this.wanted);

  TransmissionTorrentFileStats.fromJson(Map<String, dynamic> json)
      : wanted = json['wanted'];
}

class TransmissionTorrentModel {
  final int id;
  final String name;
  final double percentDone;
  final TorrentStatus status;
  final int totalSize;
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
  final List<TransmissionTorrentFile> files;
  final List<TransmissionTorrentFileStats> fileStats;
  final List<String> labels;
  final int peersConnected;
  final String magnetLink;
  final bool sequentialDownload;
  final bool speedLimitDownEnabled;
  final bool speedLimitUpEnabled;
  final int speedLimitDown;
  final int speedLimitUp;
  final DateTime doneDate;
  final int leftUntilDone;
  final int sizeWhenDone;

  const TransmissionTorrentModel(
      this.id,
      this.name,
      this.percentDone,
      this.status,
      this.totalSize,
      this.rateDownload,
      this.rateUpload,
      this.downloadedEver,
      this.uploadedEver,
      this.eta, // in seconds
      this.errorString,
      this.pieces,
      this.pieceSize,
      this.pieceCount,
      this.addedDate,
      this.isPrivate,
      this.location,
      this.comment,
      this.creator,
      this.files,
      this.labels,
      this.peersConnected,
      this.fileStats,
      this.magnetLink,
      this.sequentialDownload,
      this.speedLimitDownEnabled,
      this.speedLimitUpEnabled,
      this.speedLimitDown,
      this.speedLimitUp,
      this.doneDate,
      this.leftUntilDone,
      this.sizeWhenDone);

  TransmissionTorrentModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String? ?? '',
        percentDone = json['percentDone'] is int
            ? (json['percentDone'] as int).toDouble()
            : (json['percentDone'] as double? ?? 0.0),
        status = TorrentStatus.values[json['status'] as int? ?? 0],
        totalSize = json['totalSize'] as int? ?? 0,
        rateDownload = json['rateDownload'] as int? ?? 0,
        rateUpload = json['rateUpload'] as int? ?? 0,
        downloadedEver = json['downloadedEver'] as int? ?? 0,
        uploadedEver = json['uploadedEver'] as int? ?? 0,
        eta = json['eta'] as int? ?? -1,
        pieces = (() {
          final raw = json['pieces'];
          final count = json['pieceCount'] as int? ?? 0;
          if (raw == null || raw.toString().isEmpty || count == 0) {
            return List<bool>.filled(count, false);
          }
          try {
            return convertBitfieldToBoolList(
                base64Decode(raw as String), count);
          } catch (_) {
            return List<bool>.filled(count, false);
          }
        })(),
        pieceCount = json['pieceCount'] as int? ?? 0,
        pieceSize = json['pieceSize'] as int? ?? 0,
        errorString = json['errorString'] as String? ?? '',
        location = json['downloadDir'] as String? ?? '',
        isPrivate = json['isPrivate'] as bool? ?? false,
        addedDate = json['addedDate'] as int? ?? 0,
        creator = json['creator'] as String? ?? '',
        comment = json['comment'] as String? ?? '',
        files = (json['files'] as List<dynamic>?)
                ?.map<TransmissionTorrentFile>((j) =>
                    TransmissionTorrentFile.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [],
        fileStats = (json['fileStats'] as List<dynamic>?)
                ?.map<TransmissionTorrentFileStats>((j) =>
                    TransmissionTorrentFileStats.fromJson(
                        j as Map<String, dynamic>))
                .toList() ??
            [],
        labels = List<String>.from(json['labels'] as List<dynamic>? ?? []),
        peersConnected = json['peersConnected'] as int? ?? 0,
        magnetLink = json['magnetLink'] as String? ?? '',
        sequentialDownload = json['sequential_download'] as bool? ?? false,
        // Per-torrent bandwidth limits are returned under `download_limit(ed)`
        // / `upload_limit(ed)` (with `downloadLimit(ed)`/`uploadLimit(ed)` as
        // the legacy alias) — NOT the `speedLimit*` names used for the
        // session-level (global) settings.
        speedLimitDownEnabled =
            (json['download_limited'] ?? json['downloadLimited']) as bool? ??
                false,
        speedLimitUpEnabled =
            (json['upload_limited'] ?? json['uploadLimited']) as bool? ?? false,
        speedLimitDown =
            (json['download_limit'] ?? json['downloadLimit']) as int? ?? 0,
        speedLimitUp =
            (json['upload_limit'] ?? json['uploadLimit']) as int? ?? 0,
        doneDate = DateTime.fromMillisecondsSinceEpoch(
            (json['doneDate'] as int? ?? 0) * 1000),
        leftUntilDone = json['leftUntilDone'] as int? ?? 0,
        sizeWhenDone = json['sizeWhenDone'] as int? ?? 0;
}
