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
            final messenger = ScaffoldMessenger.of(context);
            final errorTextBuilder = l.removeTorrentsError;
            Navigator.of(context).pop();
            try {
              await _removeTorrents(torrentsModel, true);
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(errorTextBuilder(e.toString())),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
        TextButton(
          child: Text(l.removeTorrentsOnly),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final errorTextBuilder = l.removeTorrentsError;
            Navigator.of(context).pop();
            try {
              await _removeTorrents(torrentsModel, false);
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(errorTextBuilder(e.toString())),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
