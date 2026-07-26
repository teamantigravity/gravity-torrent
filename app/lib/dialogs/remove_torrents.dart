import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final torrentsModel = context.read<TorrentsModel>();
    final count = torrents.length;
    return AlertDialog(
      title: Text(l.removeTorrents(count)),
      content: Text(l.removeTorrentsConfirmation(count)),
      actions: [
        TextButton(
          child: Text(l.cancel),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: Text(l.deleteFilesAndTorrents),
          onPressed: () async {
            try {
              await _removeTorrents(torrentsModel, true);
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.removeTorrentsError(e.toString())),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
        ),
        TextButton(
          child: Text(l.removeTorrentsOnly),
          onPressed: () async {
            try {
              await _removeTorrents(torrentsModel, false);
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.removeTorrentsError(e.toString())),
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
