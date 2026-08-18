import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/engine/transmission/models/torrent_set_location.dart';

enum TorrentAddedResponse { added, duplicated }

class TorrentAddError implements Exception {
  TorrentAddError([this.message]);
  final String? message;

  @override
  String toString() => message ?? 'TorrentAddError';
}

class TransmissionRpcError implements Exception {
  TransmissionRpcError([this.message]);
  final String? message;

  @override
  String toString() => message ?? 'TransmissionRpcError';
}

/// BitTorrent engine abstraction.
abstract class Engine {
  // Initialise the engine
  Future<void> init();

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
  Future<void> resetSettings();

  Future<void> setTorrentsLocation(
    TorrentSetLocationArguments torrentSetLocationArguments,
  );

  // Remove multiple torrents
  Future<void> removeTorrents(List<int> torrentIds, bool withData);

  // Pause a torrent
  Future<void> pauseTorrent(int id);

  // Pause multiple torrents
  Future<void> pauseTorrents(List<int> ids);

  // Resume a torrent
  Future<void> resumeTorrent(int id);

  // Resume multiple torrents
  Future<void> resumeTorrents(List<int> ids);

  // Set per-torrent download/upload speed limits (kbps). 0 means unlimited.
  Future<void> setTorrentSpeedLimit(
    int id, {
    int? downloadLimit,
    int? uploadLimit,
  });

  // Set torrent sequential download mode
  Future<void> setTorrentSequentialDownload(int id, bool sequential);

  // Set torrent seed ratio mode (0=global, 1=single, 2=unlimited)
  Future<void> setTorrentSeedRatioMode(int id, int mode);

  // Set torrent seed ratio limit
  Future<void> setTorrentSeedRatioLimit(int id, double limit);

  // Set torrent idle seeding mode (0=global, 1=single, 2=unlimited)
  Future<void> setTorrentSeedIdleMode(int id, int mode);

  // Set torrent idle seeding limit (minutes)
  Future<void> setTorrentSeedIdleLimit(int id, int limit);

  // Set whether torrent honors session upload limits
  Future<void> setTorrentHonorsSessionLimits(int id, bool honors);

  // Set torrent queue position
  Future<void> setTorrentQueuePosition(int id, int position);

  // Set priority for specific pieces (for preview mode)
  Future<void> setTorrentPriorityPieces(
    int id,
    List<int> pieceIndices,
    int priority,
  );

  // Update peer blocklist from session URL
  Future<int> updateBlocklist();
}
