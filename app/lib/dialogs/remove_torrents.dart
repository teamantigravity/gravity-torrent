import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:provider/provider.dart';

class RemoveTorrentsDialog extends StatelessWidget {
  final List<Torrent> torrents;

  const RemoveTorrentsDialog({super.key, required this.torrents});

  Future<void> _removeTorrents(
    TorrentsModel torrentsModel,
    bool withData,
  ) async {
    final torrentIds = torrents.map((t) => t.id).toList();
    // Model captured before popping so the refresh runs regardless of context.
    await torrentsModel.removeAllTorrents(torrentIds, withData);
    AdServiceProvider.instance.showInterstitialIfReady();
  }

  @override
  Widget build(BuildContext context) {
    final torrentsModel = context.read<TorrentsModel>();
    return AlertDialog(
      title: Text('Remove ${torrents.length} Torrents'),
      content: Text(
        'Are you sure you want to remove ${torrents.length} torrents?',
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: const Text('Delete files & torrents'),
          onPressed: () async {
            try {
              await _removeTorrents(torrentsModel, true);
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not remove torrents: $e'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
        ),
        TextButton(
          child: const Text('Remove torrents only'),
          onPressed: () async {
            try {
              await _removeTorrents(torrentsModel, false);
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not remove torrents: $e'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
