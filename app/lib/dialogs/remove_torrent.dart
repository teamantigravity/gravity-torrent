import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:provider/provider.dart';

class RemoveTorrentDialog extends StatelessWidget {
  final Torrent torrent;

  const RemoveTorrentDialog({super.key, required this.torrent});

  Future<void> _removeTorrent(
    TorrentsModel torrentsModel,
    bool withData,
  ) async {
    await torrent.remove(withData);
    // Use TorrentsModel so the UI list is updated immediately. The model is
    // captured before popping the dialog so the refresh still runs even though
    // this widget's context is no longer mounted.
    await torrentsModel.fetchTorrents();
    AdServiceProvider.instance.showInterstitialIfReady();
  }

  @override
  Widget build(BuildContext context) {
    final torrentsModel = context.read<TorrentsModel>();
    return AlertDialog(
      title: const Text('Remove Torrent'),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: const Text('Delete files & torrent'),
          onPressed: () async {
            try {
              await _removeTorrent(torrentsModel, true);
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not remove torrent: $e'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
        ),
        TextButton(
          child: const Text('Remove torrent only'),
          onPressed: () async {
            try {
              await _removeTorrent(torrentsModel, false);
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not remove torrent: $e'),
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
