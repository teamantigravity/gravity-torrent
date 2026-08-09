import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';

class SubtitlesSelectorDialog extends StatefulWidget {
  final List<SubtitleTrack> subtitles;
  final Function(SubtitleTrack) onSubtitleSelected;
  final String currentValue;
  const SubtitlesSelectorDialog({
    super.key,
    required this.onSubtitleSelected,
    required this.currentValue,
    required this.subtitles,
  });

  @override
  State<SubtitlesSelectorDialog> createState() =>
      _SubtitlesSelectorDialogState();
}

class _SubtitlesSelectorDialogState extends State<SubtitlesSelectorDialog> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.subtitles),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ...widget.subtitles.where((s) => s.id != 'auto').toList().map((
              sub,
            ) {
              return RadioListTile<String>(
                title: Text(
                  sub.id == 'no' ? l.noSubtitle : sub.title ?? l.unknown,
                ),
                value: sub.id,
                groupValue: widget.currentValue,
                onChanged: (id) {
                  final s = widget.subtitles.firstWhere((s) => s.id == id);
                  widget.onSubtitleSelected(s);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l.cancel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
