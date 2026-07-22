import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_set_location.dart';

enum TorrentAddedResponse { added, duplicated }

class TorrentAddError extends Error {
  TorrentAddError([this.message]);
  final String? message;

  @override
  String toString() => message ?? 'TorrentAddError';
}

/// BitTorrent engine abstraction.
abstract class Engine {
  // Initialise the engine
  Future init();

  // Shutdown the engine gracefully (flushing data and terminating)
  Future<void> shutdown();

  // Save the engine session settings
  Future<void> saveSession();

  // Request a debounced checkpoint of the session
  void requestCheckpoint();

  // Add a torrent
  Future<TorrentAddedResponse> addTorrent(
    String? filename,
    String? metainfo,
    String? downloadDir,
  );

  // Fetch all torrents
  Future<List<Torrent>> fetchTorrents();

  Future<Torrent> fetchTorrent(int id);

  // Fetch session information (e.g. default download directory)
  Future<Session> fetchSession();

  // Reset torrents engine settings
  Future resetSettings();

  Future setTorrentsLocation(
    TorrentSetLocationArguments torrentSetLocationArguments,
  );

  // Remove multiple torrents
  Future removeTorrents(List<int> torrentIds, bool withData);

  // Pause a torrent
  Future pauseTorrent(int id);

  // Pause multiple torrents
  Future pauseTorrents(List<int> ids);

  // Resume a torrent
  Future resumeTorrent(int id);

  // Resume multiple torrents
  Future resumeTorrents(List<int> ids);

  // Set per-torrent download/upload speed limits (kbps). 0 means unlimited.
  Future setTorrentSpeedLimit(int id, {int? downloadLimit, int? uploadLimit});

  // Set torrent sequential download mode
  Future setTorrentSequentialDownload(int id, bool sequential);

  // Update peer blocklist from session URL
  Future<int> updateBlocklist();
}
