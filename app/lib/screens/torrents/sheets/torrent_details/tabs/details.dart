import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:pretty_bytes/pretty_bytes.dart';
import 'package:duration/duration.dart';
import 'package:gravity_torrent/ui/torrent_speed_chart.dart';
import 'package:gravity_torrent/services/speed_history_service.dart';
import 'package:gravity_torrent/services/seed_ratio_service.dart';
import 'package:gravity_torrent/services/torrent_notes_service.dart';

class DetailsTab extends StatefulWidget {
  final Torrent torrent;

  const DetailsTab({super.key, required this.torrent});

  @override
  State<DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<DetailsTab> {
  String _note = '';
  bool _loadingNote = true;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void didUpdateWidget(covariant DetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.torrent.id != widget.torrent.id) {
      _loadNote();
    }
  }

  Future<void> _loadNote() async {
    setState(() => _loadingNote = true);
    final note = await TorrentNotesService.instance.getNote(widget.torrent.id);
    if (mounted) {
      setState(() {
        _note = note;
        _loadingNote = false;
      });
    }
  }

  Future<void> _editNote() async {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _note);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.torrentNotes),
        content: TextField(
          controller: controller,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: localizations.torrentNotesHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(localizations.save),
          ),
        ],
      ),
    );
    if (value != null) {
      await TorrentNotesService.instance.setNote(widget.torrent.id, value);
      await _loadNote();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final torrent = widget.torrent;

    double ratio = torrent.downloadedEver > 0
        ? (torrent.uploadedEver / torrent.downloadedEver)
        : 0;
    // Clamp and format to a readable two-decimal value.
    ratio = ratio.clamp(0.0, double.infinity);

    String status = switch (torrent.status) {
      TorrentStatus.stopped => localizations.stopped,
      TorrentStatus.checking => localizations.checking,
      TorrentStatus.downloading => localizations.downloading,
      TorrentStatus.queuedToCheck => localizations.queuedToCheck,
      TorrentStatus.queuedToDownload => localizations.queuedToDownload,
      TorrentStatus.queuedToSeed => localizations.queuedToSeed,
      TorrentStatus.seeding => localizations.seeding,
    };

    final eta = Duration(seconds: torrent.eta);

    final String privacy = torrent.isPrivate
        ? localizations.privateTorrent
        : localizations.publicTorrent;

    final speeds = SpeedHistoryService.instance.getHistory(torrent.id);
    final ratioGoal = SeedRatioService.instance.getGoal(torrent.id);

    return ListView(
      children: <Widget>[
        if (speeds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TorrentSpeedChart(speeds: speeds),
          ),
        ListTile(
          title: Text(localizations.error),
          subtitle: Text(
            torrent.errorString.isEmpty ? '-' : torrent.errorString,
            style: (torrent.errorString.isEmpty)
                ? const TextStyle()
                : const TextStyle(color: Colors.red),
          ),
        ),
        ListTile(
          title: Text(localizations.size),
          subtitle: Text(
              prettyBytes(torrent.size.toDouble(), locale: localizations.localeName)),
        ),
        ListTile(
          title: Text(localizations.downloaded),
          subtitle: Text(prettyBytes(
              torrent.downloadedEver.toDouble(), locale: localizations.localeName)),
        ),
        ListTile(
          title: Text(localizations.uploaded),
          subtitle: Text(prettyBytes(
              torrent.uploadedEver.toDouble(), locale: localizations.localeName)),
        ),
        ListTile(
          title: Text(localizations.ratio),
          subtitle: Text(ratio.toStringAsFixed(2)),
        ),
        ListTile(
          title: Text(localizations.setSeedRatioGoal),
          subtitle: Text(
              ratioGoal != null ? ratioGoal.toString() : localizations.notSet),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            String? newGoal = await showDialog<String>(
              context: context,
              builder: (context) {
                final controller =
                    TextEditingController(text: ratioGoal?.toString() ?? '');
                return AlertDialog(
                  title: Text(localizations.setSeedRatioGoal),
                  content: TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'e.g. 1.5'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(localizations.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: Text(localizations.save),
                    ),
                  ],
                );
              },
            );

            if (newGoal != null && mounted) {
              final val = double.tryParse(newGoal);
              if (val != null) {
                await SeedRatioService.instance.setGoal(torrent.id, val);
                setState(() {});
              } else if (newGoal.isEmpty) {
                await SeedRatioService.instance.removeGoal(torrent.id);
                setState(() {});
              }
            }
          },
        ),
        ListTile(
          title: Text(localizations.peersConnected),
          subtitle: Text(torrent.peersConnected.toString()),
        ),
        ListTile(title: Text(localizations.state), subtitle: Text(status)),
        ListTile(
          title: Text(localizations.remainingTime),
          subtitle: Text(
            torrent.eta >= 0
                ? eta.pretty(abbreviated: true, delimiter: ' ')
                : '-',
          ),
        ),
        ListTile(
          title: Text(localizations.pieces),
          subtitle: Text(torrent.pieceCount.toString()),
        ),
        ListTile(
          title: Text(localizations.pieceSize),
          subtitle: Text(prettyBytes(torrent.pieceSize.toDouble(),
                  locale: localizations.localeName)
              .toString()),
        ),
        ListTile(
          title: Text(localizations.addedDate),
          subtitle: Text(
            DateTime.fromMillisecondsSinceEpoch(
              torrent.addedDate * 1000,
            ).toString(),
          ),
        ),
        ListTile(title: Text(localizations.privacy), subtitle: Text(privacy)),
        ListTile(
          title: Text(localizations.creator),
          subtitle: Text(torrent.creator == '' ? '-' : torrent.creator),
        ),
        ListTile(
          title: Text(localizations.comment),
          subtitle: Text(torrent.comment == '' ? '-' : torrent.comment),
        ),
        ListTile(
          title: Text(localizations.downloadDirectory),
          subtitle: Text(torrent.location),
        ),
        ListTile(
          title: Text(localizations.magnetLink),
          subtitle: Text(
            torrent.magnetLink,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            tooltip: localizations.copy,
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(text: torrent.magnetLink),
              );
              if (!mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(localizations.copiedToClipboard),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
        ListTile(
          title: Text(localizations.torrentNotes),
          subtitle: Text(
            _loadingNote
                ? '...'
                : _note.isEmpty
                    ? localizations.notSet
                    : _note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: localizations.editTorrentNotes,
            onPressed: _editNote,
          ),
          onTap: _editNote,
        ),
      ],
    );
  }
}
