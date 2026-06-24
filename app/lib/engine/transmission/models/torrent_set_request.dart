class TorrentSetRequest {
  final method = 'torrent-set';
  final TorrentSetRequestArguments arguments;

  TorrentSetRequest({required this.arguments});

  Map<String, dynamic> toJson() =>
      {'method': method, 'arguments': arguments.toJson()};
}

class TorrentSetRequestArguments {
  final List<int> ids;
  final List<String>? labels;
  final List<int>? filesWanted;
  final List<int>? filesUnwanted;
  final bool? sequentialDownload;
  final int? sequentialDownloadFromPiece;
  final List<int>? priorityHigh;
  final List<int>? priorityLow;
  final List<int>? priorityNormal;
  final bool? speedLimitDownEnabled;
  final bool? speedLimitUpEnabled;
  final int? speedLimitDown;
  final int? speedLimitUp;

  TorrentSetRequestArguments(
      {required this.ids,
      this.labels,
      this.filesWanted,
      this.filesUnwanted,
      this.sequentialDownload,
      this.sequentialDownloadFromPiece,
      this.priorityHigh,
      this.priorityLow,
      this.priorityNormal,
      this.speedLimitDownEnabled,
      this.speedLimitUpEnabled,
      this.speedLimitDown,
      this.speedLimitUp});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    json['ids'] = ids;

    if (labels != null) {
      json['labels'] = labels;
    }

    if (filesWanted != null) {
      json['files-wanted'] = filesWanted;
    }

    if (filesUnwanted != null) {
      json['files-unwanted'] = filesUnwanted;
    }

    if (sequentialDownload != null) {
      json['sequential_download'] = sequentialDownload;
    }

    if (sequentialDownloadFromPiece != null) {
      json['sequential_download_from_piece'] = sequentialDownloadFromPiece;
    }

    if (priorityHigh != null) {
      json['priority-high'] = priorityHigh;
    }

    if (priorityLow != null) {
      json['priority-low'] = priorityLow;
    }

    if (priorityNormal != null) {
      json['priority-normal'] = priorityNormal;
    }

    if (speedLimitDownEnabled != null) {
      json['speed-limit-down-enabled'] = speedLimitDownEnabled;
    }

    if (speedLimitUpEnabled != null) {
      json['speed-limit-up-enabled'] = speedLimitUpEnabled;
    }

    if (speedLimitDown != null) {
      json['speed-limit-down'] = speedLimitDown;
    }

    if (speedLimitUp != null) {
      json['speed-limit-up'] = speedLimitUp;
    }

    return json;
  }
}
