import 'package:gravity_torrent/engine/transmission/models/torrent.dart';

class TorrentGetRequest {
  final method = 'torrent-get';
  final TorrentGetRequestArguments arguments;

  TorrentGetRequest({required this.arguments});

  Map<String, dynamic> toJson() => {
        'method': method,
        'arguments': arguments.toJson(),
      };
}

class TorrentGetRequestArguments {
  final List<int>? ids;
  final List<TorrentField> fields;

  TorrentGetRequestArguments({this.ids, required this.fields});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'fields': fields.map((field) {
        return switch (field) {
          // The engine only recognizes these under their RPC-native spelling.
          // `sequential_download` has no camelCase alias at all, and the
          // per-torrent bandwidth limit fields are NOT named like their
          // session-level `speed-limit-*` counterparts: the torrent-level
          // RPC fields are `download(ed)Limit`/`downloadLimited`/
          // `uploadLimit`/`uploadLimited` (here in their snake_case form).
          // Requesting the camelCase `field.name` (the default case below)
          // means the server never recognizes the field and silently omits
          // it from the response, which made these values always read back
          // as false/0 regardless of their actual state.
          TorrentField.sequentialDownload => "sequential_download",
          TorrentField.leftUntilDone => "leftUntilDone",
          TorrentField.sizeWhenDone => "sizeWhenDone",
          TorrentField.speedLimitDownEnabled => "download_limited",
          TorrentField.speedLimitUpEnabled => "upload_limited",
          TorrentField.speedLimitDown => "download_limit",
          TorrentField.speedLimitUp => "upload_limit",
          _ => field.name,
        };
      }).toList(),
    };

    if (ids != null) {
      json['ids'] = ids;
    }

    return json;
  }
}
