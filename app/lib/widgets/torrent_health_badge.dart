import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/torrent.dart';

/// Colour-coded health badge derived from peer count and torrent status.
class TorrentHealthBadge extends StatelessWidget {
  const TorrentHealthBadge({super.key, required this.torrent});

  final Torrent torrent;

  /// Peer counts used to decide the health badge level.
  static const _healthyPeerThreshold = 5;
  static const _fairPeerThreshold = 1;

  TorrentHealthLevel get _health {
    if (torrent.status == TorrentStatus.stopped) return TorrentHealthLevel.none;
    if (torrent.status == TorrentStatus.checking ||
        torrent.status == TorrentStatus.queuedToCheck) {
      return TorrentHealthLevel.fair;
    }
    if (torrent.errorString.isNotEmpty) return TorrentHealthLevel.poor;
    if (torrent.peersConnected >= _healthyPeerThreshold) {
      return TorrentHealthLevel.healthy;
    }
    if (torrent.peersConnected >= _fairPeerThreshold) {
      return TorrentHealthLevel.fair;
    }
    return TorrentHealthLevel.poor;
  }

  @override
  Widget build(BuildContext context) {
    final level = _health;
    if (level == TorrentHealthLevel.none) return const SizedBox.shrink();

    final Color color = switch (level) {
      TorrentHealthLevel.healthy => Colors.green,
      TorrentHealthLevel.fair => Colors.orange,
      TorrentHealthLevel.poor => Colors.red,
      TorrentHealthLevel.none => Colors.transparent,
    };

    final String label = switch (level) {
      TorrentHealthLevel.healthy => 'Healthy (${torrent.peersConnected} peers)',
      TorrentHealthLevel.fair => 'Fair (${torrent.peersConnected} peers)',
      TorrentHealthLevel.poor => torrent.errorString.isNotEmpty
          ? 'Error: ${torrent.errorString}'
          : 'Poor connectivity',
      TorrentHealthLevel.none => '',
    };

    return Tooltip(
      message: label,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Health level for a torrent based on peers and status.
enum TorrentHealthLevel { healthy, fair, poor, none }
