import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent.dart';

class TorrentGetResponse {
  final TorrentGetResponseArguments arguments;
  final String result;

  TorrentGetResponse(this.arguments, this.result);

  TorrentGetResponse.fromJson(Map<String, dynamic> json)
      : arguments = TorrentGetResponseArguments.fromJson(
          json['arguments'] is Map
              ? json['arguments'] as Map<String, dynamic>
              : const {},
        ),
        result = json['result'] as String? ?? '';
}

class TorrentGetResponseArguments {
  final List<TransmissionTorrentModel> torrents;

  TorrentGetResponseArguments(this.torrents);

  TorrentGetResponseArguments.fromJson(Map<String, dynamic> json)
      : torrents = json['torrents'] is List<dynamic>
            ? (json['torrents'] as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map((j) {
                  try {
                    return TransmissionTorrentModel.fromJson(
                      Map<String, dynamic>.from(j),
                    );
                  } catch (e, s) {
                    if (kDebugMode) {
                      debugPrint('Failed to parse torrent model: $e\n$s');
                    }
                    return null;
                  }
                })
                .whereType<TransmissionTorrentModel>()
                .toList()
            : [];
}
